import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/sorted_style_spans.dart';
import 'package:editor/src/styling/style_layer.dart';
import 'package:editor/src/styling/style_span.dart';
import 'package:editor/src/styling/style_span_mask.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';

/// Ленивый синтаксический слой для случая «LSP отстаёт от документа на N правок».
///
/// Вместо материализации полного `_displaySpans` (≈O(spans) аллокаций на каждый
/// keystroke в большом файле — до 30 КБ объектов на нажатие на 60 КБ-файле),
/// слой держит **исходные** `sortedBase` (снимок LSP-токенов) плюс журнал
/// [pending] и проектирует диапазон при каждом запросе [spansForRange]:
///
/// 1. Запрошенный [range] (текущие координаты) проецируется **назад** через
///    [pending] в координаты `sortedBase`.
/// 2. По обратному диапазону делается бинарный поиск в `sortedBase` (O(log n)).
/// 3. Каждый найденный span проецируется **вперёд** через [pending] и пересекается
///    с исходным [range]; результат отдаётся с приоритетом [layerPriority].
///
/// Если задан [clipBefore], spans за этим смещением **в текущих координатах**
/// отсекаются (стратегия «структурная правка → не показывать сдвинутый хвост»;
/// см. [shouldClipStaleTail]).
///
/// На обычной клавишной правке pending короткий (≤10–20), spans в одной строке
/// ≤3 — стоимость запроса на видимую строку остаётся O(log spans + pending).
final class PendingShiftedSyntaxLayer implements StyleLayer {
  /// Создаёт ленивый слой из снимка [sortedBase] и журнала [pending].
  ///
  /// [pending] — та же ссылка, что у владельца (highlighter); обновляется in-place.
  /// Владелец вызывает [syncFrom] вместо пересоздания слоя на каждый keystroke.
  PendingShiftedSyntaxLayer({
    required this.sortedBase,
    required this.pending,
    this.documentVersion,
    this.layerPriority = 50,
    this.clipBefore,
  });

  /// Snapshot LSP-токенов; отсортирован по `range.start`.
  List<StyleSpan> sortedBase;

  /// Журнал применённых правок после [sortedBase], в порядке применения.
  List<DocumentChange> pending;

  /// Версия документа, для которой действителен этот слой.
  int? documentVersion;

  /// Приоритет, присваиваемый каждому возвращаемому span'у.
  final int layerPriority;

  /// Если задан, spans с `range.start >= clipBefore` (в текущих координатах)
  /// не выдаются, а пересекающие [clipBefore] усекаются.
  int? clipBefore;

  /// Hint для бинарного поиска в [sortedBase] (viewport).
  SpanSearchBounds? spanSearchBounds;

  /// Обновляет поля без нового экземпляра [StyleLayer].
  void syncFrom({
    required List<StyleSpan> sortedBase,
    required List<DocumentChange> pending,
    required int? documentVersion,
    required int? clipBefore,
    ViewportStyleScope? viewport,
  }) {
    this.sortedBase = sortedBase;
    this.pending = pending;
    this.documentVersion = documentVersion;
    this.clipBefore = clipBefore;
    _updateSpanSearchBounds(viewport);
  }

  void _updateSpanSearchBounds(ViewportStyleScope? viewport) {
    if (viewport == null) {
      spanSearchBounds = null;
      return;
    }
    final invStart = projectOffsetBackwardChain(
      viewport.documentRange.start,
      pending,
    );
    final invEnd = projectOffsetBackwardChain(
      viewport.documentRange.end,
      pending,
    );
    final scroll = Range(invStart, invEnd);
    final caret = viewport.caretSearchRange;
    if (caret == null) {
      spanSearchBounds = spanSearchBoundsForRange(sortedBase, scroll);
      return;
    }
    final invCaretStart = projectOffsetBackwardChain(caret.start, pending);
    final invCaretEnd = projectOffsetBackwardChain(caret.end, pending);
    spanSearchBounds = mergeSpanSearchBounds(
      spanSearchBoundsForRange(sortedBase, scroll),
      spanSearchBoundsForRange(sortedBase, Range(invCaretStart, invCaretEnd)),
    );
  }

  /// Только обновляет viewport hint (прокрутка без пересборки слоя).
  void updateViewport(ViewportStyleScope? viewport) =>
      _updateSpanSearchBounds(viewport);

  @override
  String get id => 'syntax';

  @override
  int? get validForDocumentVersion => documentVersion;

  @override
  Iterable<StyleSpan> spansForRange(Range range) sync* {
    if (sortedBase.isEmpty) return;
    if (range.start >= range.end) return;

    final effectiveEnd = clipBefore == null
        ? range.end
        : (range.end < clipBefore! ? range.end : clipBefore!);
    if (range.start >= effectiveEnd) return;

    // Проекция запрошенного диапазона в координаты sortedBase.
    final inverseStart = projectOffsetBackwardChain(range.start, pending);
    final inverseEnd = projectOffsetBackwardChain(effectiveEnd, pending);
    if (inverseEnd <= inverseStart) {
      // Внутри вставленной области — токенов из снимка тут не было.
      return;
    }

    final bounds = spanSearchBounds;
    final searchEnd = bounds?.hi ?? sortedBase.length;
    var lo = lowerBoundSpanIndex(sortedBase, inverseStart);
    if (bounds != null && lo < bounds.lo) lo = bounds.lo;

    for (var i = lo; i < searchEnd; i++) {
      final span = sortedBase[i];
      if (span.range.start >= inverseEnd) break;

      // Проекция диапазона span'а через цепочку pending с учётом семантики
      // границ (см. shiftRangeForward).
      final shifted = shiftRangeForwardChain(span.range, pending);
      if (shifted == null) continue;

      // Пересечение с запросом и обязательное усечение по clipBefore.
      final outStart = shifted.start < range.start
          ? range.start
          : shifted.start;
      final outEnd = shifted.end > effectiveEnd ? effectiveEnd : shifted.end;
      if (outStart >= outEnd) continue;

      yield StyleSpan(
        range: Range(outStart, outEnd),
        color: span.color,
        backgroundColor: span.backgroundColor,
        fontWeight: span.fontWeight,
        fontStyle: span.fontStyle,
        underline: span.underline,
        wavyUnderline: span.wavyUnderline,
        underlineColor: span.underlineColor,
        priority: layerPriority,
      );
    }
  }
}
