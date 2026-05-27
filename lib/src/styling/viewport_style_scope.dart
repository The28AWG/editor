import 'package:editor/src/layout/viewport.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';

/// Видимый (плюс overscan) диапазон документа для стилевых слоёв хоста.
///
/// Редактор передаёт scope в [EditorHost.styleLayersFor], чтобы LSP/токенизатор
/// не обрабатывали весь snapshot (~3000+ spans) при каждом запросе строки.
/// Paint по-прежнему запрашивает [StyleLayer.spansForRange] только для строк
/// viewport'а; scope сужает бинарный поиск в отсортированном массиве токенов.
///
/// Максимум строк в [documentRange] — чтобы union scroll+caret не тянул
/// «хвост» от строки 0 до 1500 при прыжке каретки без прокрутки.
const int kMaxStyleViewportLines = 120;

final class ViewportStyleScope {
  const ViewportStyleScope({
    required this.firstLine,
    required this.lastLineExclusive,
    required this.documentRange,
    this.caretSearchRange,
  });

  /// Строит scope из [ViewportState] и [document].
  ///
  /// Scroll-окно задаёт [documentRange] и [firstLine]/[lastLineExclusive].
  /// Если каретка вне scroll — [caretSearchRange] для поиска токенов у каретки
  /// без подмены видимой области (иначе paint теряет стили на экране).
  factory ViewportStyleScope.fromViewport({
    required Document document,
    required ViewportState viewport,
    required double lineHeightPx,
    int? caretLine,
  }) {
    final lineCount = document.lineCount;
    if (lineCount == 0) {
      return const ViewportStyleScope(
        firstLine: 0,
        lastLineExclusive: 0,
        documentRange: Range(0, 0),
      );
    }
    final overscan = viewport.overscanLines;
    final scrollFirst = viewport.firstVisibleLine - overscan;
    final scrollLast = viewport.lastVisibleLine(lineCount, lineHeightPx);

    var first = scrollFirst < 0 ? 0 : scrollFirst;
    var last = scrollLast > lineCount ? lineCount : scrollLast;

    Range? caretSearchRange;
    if (caretLine != null) {
      final c = caretLine.clamp(0, lineCount - 1);
      final cf = c - overscan;
      final cl = c + overscan + 1;
      final caretFirst = cf < 0 ? 0 : cf;
      final caretLast = cl > lineCount ? lineCount : cl;
      if (c < first || c >= last) {
        final caretStart = document.lineStart(caretFirst);
        final caretEnd = caretLast >= lineCount
            ? document.length
            : document.lineStart(caretLast);
        caretSearchRange = Range(caretStart, caretEnd);
      } else {
        if (caretFirst < first) first = caretFirst;
        if (caretLast > last) last = caretLast;
      }
    }

    final span = last - first;
    if (span > kMaxStyleViewportLines) {
      // Cap по scroll-центру, если каретка вне экрана — не уезжать к EOF.
      final c = caretLine?.clamp(0, lineCount - 1);
      final caretOnScreen = c != null && c >= first && c < last;
      final center = caretOnScreen ? c : (first + last) ~/ 2;
      final half = kMaxStyleViewportLines ~/ 2;
      first = center - half;
      if (first < 0) first = 0;
      last = first + kMaxStyleViewportLines;
      if (last > lineCount) {
        last = lineCount;
        first = last - kMaxStyleViewportLines;
        if (first < 0) first = 0;
      }
    }

    if (first >= last) {
      first = 0;
      last = lineCount > 0 ? 1 : 0;
    }
    final start = document.lineStart(first);
    final end = last >= lineCount ? document.length : document.lineStart(last);
    return ViewportStyleScope(
      firstLine: first,
      lastLineExclusive: last,
      documentRange: Range(start, end),
      caretSearchRange: caretSearchRange,
    );
  }

  /// Первая строка документа (включительно), с учётом overscan.
  final int firstLine;

  /// Строка после последней видимой (exclusive).
  final int lastLineExclusive;

  /// Полуоткрытый диапазон code units `[start, end)` для scroll-окна.
  final Range documentRange;

  /// Доп. диапазон для бинарного поиска, когда каретка вне [documentRange].
  final Range? caretSearchRange;

  @override
  bool operator ==(Object other) =>
      other is ViewportStyleScope &&
      firstLine == other.firstLine &&
      lastLineExclusive == other.lastLineExclusive &&
      documentRange == other.documentRange &&
      caretSearchRange == other.caretSearchRange;

  @override
  int get hashCode => Object.hash(
    firstLine,
    lastLineExclusive,
    documentRange.start,
    documentRange.end,
    caretSearchRange?.start,
    caretSearchRange?.end,
  );
}
