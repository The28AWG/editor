import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/sorted_style_spans.dart';
import 'package:editor/src/styling/style_layer.dart';
import 'package:editor/src/styling/style_span.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';

/// Токены подсветки синтаксиса хоста.
///
/// Обрезает предвычисленные [spans] по каждому запрошенному [Range] и назначает
/// [layerPriority] (по умолчанию `50`), чтобы синтаксис перекрывал [BaseStyleLayer], но
/// уступал [DecorationStyleLayer] и [TransientStyleLayer].
///
/// ```dart
/// SyntaxStyleLayer(
///   spans: tokenizer.spansForDocument(document),
///   documentVersion: document.version,
/// )
/// ```
final class SyntaxStyleLayer implements StyleLayer {
  /// Создаёт синтаксический слой из token span'ов хоста.
  SyntaxStyleLayer({
    required List<StyleSpan> spans,
    this.documentVersion,
    this.layerPriority = 50,
    bool alreadySorted = false,
  }) : _sortedSpans = alreadySorted
           ? List<StyleSpan>.of(spans)
           : sortedStyleSpans(spans);

  /// Span'ы синтаксиса всего документа от токенизатора хоста или семантических токенов LSP.
  List<StyleSpan> get spans => _sortedSpans;

  List<StyleSpan> _sortedSpans;

  /// Подменяет токены без пересоздания слоя (стабильная ссылка для [StyleResolver]).
  void replaceSortedSpans(List<StyleSpan> spans, {bool alreadySorted = false}) {
    _sortedSpans = alreadySorted
        ? List<StyleSpan>.of(spans)
        : sortedStyleSpans(spans);
  }

  /// Версия документа, для которой вычислены эти span'ы.
  final int? documentVersion;

  /// Приоритет, присваиваемый каждому возвращаемому span'у.
  final int layerPriority;

  /// Optional hint: искать токены только в `sorted[lo .. hi)`.
  SpanSearchBounds? spanSearchBounds;

  /// Сужает бинарный поиск по snapshot LSP к видимому viewport.
  void setSpanSearchBoundsFromViewport(ViewportStyleScope? viewport) {
    if (viewport == null) {
      spanSearchBounds = null;
      return;
    }
    spanSearchBounds = spanSearchBoundsForViewport(_sortedSpans, viewport);
  }

  /// Только обновляет viewport hint без пересоздания слоя.
  void updateViewport(ViewportStyleScope? viewport) =>
      setSpanSearchBoundsFromViewport(viewport);

  @override
  String get id => 'syntax';

  @override
  int? get validForDocumentVersion => documentVersion;

  @override
  Iterable<StyleSpan> spansForRange(Range range) {
    final bounds = spanSearchBounds;
    return spansForSortedRange(
      _sortedSpans,
      range,
      layerPriority,
      searchLo: bounds?.lo ?? 0,
      searchHi: bounds?.hi,
    );
  }
}
