import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/style_span.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';

/// Индексы в отсортированном snapshot LSP для сужения поиска к viewport.
final class SpanSearchBounds {
  const SpanSearchBounds(this.lo, this.hi);

  final int lo;
  final int hi;
}

/// Возвращает копию [spans], отсортированную по [StyleSpan.range.start].
List<StyleSpan> sortedStyleSpans(List<StyleSpan> spans) {
  if (spans.length <= 1) return List<StyleSpan>.of(spans);
  return List<StyleSpan>.of(spans)
    ..sort((a, b) => a.range.start.compareTo(b.range.start));
}

/// Индекс первого span в [sorted], у которого `range.end > offset`.
///
/// Стандартный lower_bound по концам span'ов — первый кандидат, пересекающий [offset].
int lowerBoundSpanIndex(List<StyleSpan> sorted, int offset) {
  if (sorted.isEmpty) return 0;
  var lo = 0;
  var hi = sorted.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (sorted[mid].range.end <= offset) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Индексы `sorted[lo..hi)` для viewport [r.start, r.end).
///
/// При пустом пересечении с [r] берёт соседний span (граница EOF), не весь файл.
SpanSearchBounds spanSearchBoundsForRange(List<StyleSpan> sorted, Range r) {
  if (sorted.isEmpty) return const SpanSearchBounds(0, 0);
  var lo = lowerBoundSpanIndex(sorted, r.start);
  var hi = upperBoundSpanIndex(sorted, r.end);
  if (hi <= lo) {
    if (lo > 0) return SpanSearchBounds(lo - 1, lo);
    if (lo < sorted.length) return SpanSearchBounds(lo, lo + 1);
    return SpanSearchBounds(lo, lo);
  }
  return SpanSearchBounds(lo, hi);
}

/// Объединяет hint'ы scroll и off-screen caret без «моста» в document offsets.
SpanSearchBounds mergeSpanSearchBounds(
  SpanSearchBounds primary,
  SpanSearchBounds? secondary,
) {
  if (secondary == null) return primary;
  if (secondary.hi <= secondary.lo) return primary;
  if (primary.hi <= primary.lo) return secondary;
  final lo = primary.lo < secondary.lo ? primary.lo : secondary.lo;
  final hi = primary.hi > secondary.hi ? primary.hi : secondary.hi;
  return SpanSearchBounds(lo, hi);
}

/// Bounds для [ViewportStyleScope]: scroll + опциональная полоса каретки вне экрана.
SpanSearchBounds spanSearchBoundsForViewport(
  List<StyleSpan> sorted,
  ViewportStyleScope viewport,
) {
  final scroll = spanSearchBoundsForRange(sorted, viewport.documentRange);
  final caret = viewport.caretSearchRange;
  if (caret == null) return scroll;
  return mergeSpanSearchBounds(scroll, spanSearchBoundsForRange(sorted, caret));
}

/// Exclusive-индекс первого span с `range.start >= offset`.
///
/// Пара к [lowerBoundSpanIndex]: вместе задают полуоткрытый `[lo, hi)` для viewport.
int upperBoundSpanIndex(List<StyleSpan> sorted, int offset) {
  if (sorted.isEmpty) return 0;
  var lo = 0;
  var hi = sorted.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (sorted[mid].range.start < offset) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Обрезает отсортированные [spans] по [range] (бинарный поиск по началу).
///
/// [searchLo] / [searchHi] — optional viewport hint: искать только в
/// `sorted[searchLo .. searchHi)`.
Iterable<StyleSpan> spansForSortedRange(
  List<StyleSpan> sorted,
  Range range,
  int layerPriority, {
  int searchLo = 0,
  int? searchHi,
}) sync* {
  if (sorted.isEmpty) return;
  final endIndex = searchHi ?? sorted.length;
  if (searchLo >= endIndex) return;

  var lo = lowerBoundSpanIndex(sorted, range.start);
  if (lo < searchLo) lo = searchLo;

  for (var i = lo; i < endIndex; i++) {
    final span = sorted[i];
    if (span.range.start >= range.end) break;
    if (span.range.end <= range.start) continue;
    final start = span.range.start < range.start
        ? range.start
        : span.range.start;
    final end = span.range.end > range.end ? range.end : span.range.end;
    if (start < end) {
      yield StyleSpan(
        range: Range(start, end),
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
