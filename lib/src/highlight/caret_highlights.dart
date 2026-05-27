import 'package:editor/src/highlight/bracket_matcher.dart';
import 'package:editor/src/highlight/highlight_kind.dart';
import 'package:editor/src/highlight/highlight_span.dart';
import 'package:editor/src/highlight/highlight_viewport.dart';
import 'package:editor/src/highlight/word_bounds.dart';
import 'package:editor/src/model/position.dart';

/// Формирует эфемерные подсветки для схлопнутой каретки на [offset].
///
/// Объединяет подсветку скобок, [languageSpans] хоста (например, вхождения LSP) и
/// при необходимости запасной диапазон слова, если span вхождения отсутствует.
///
/// [text] — срез документа; [textBaseOffset] — смещение начала [text] в документе.
/// [offset] — позиция каретки в координатах документа.
/// [searchRange] — видимый диапазон документа: поиск пар скобок и LSP-spans
/// ограничен им; совпадения полностью вне экрана не включаются.
///
/// **Граничные случаи:** Когда [fallbackWordOccurrence] равен `true` и ни один span не имеет
/// [HighlightKind.occurrence], [wordRangeAt] может добавить один span вхождения.
List<HighlightSpan> caretHighlightsFor({
  required String text,
  required TextOffset offset,
  int textBaseOffset = 0,
  Range? searchRange,
  List<HighlightSpan> languageSpans = const [],
  bool fallbackWordOccurrence = true,
}) {
  final merged = <HighlightSpan>[...languageSpans];

  final local = offset - textBaseOffset;
  if (local >= 0 && local <= text.length) {
    final localSearchStart = searchRange == null
        ? 0
        : (searchRange.start - textBaseOffset).clamp(0, text.length);
    final localSearchEnd = searchRange == null
        ? text.length
        : (searchRange.end - textBaseOffset).clamp(0, text.length);

    for (final span in bracketHighlightSpans(
      text,
      local,
      searchStart: localSearchStart,
      searchEnd: localSearchEnd,
      boundedSearch: searchRange != null,
    )) {
      merged.add(
        HighlightSpan(
          range: Range(
            span.range.start + textBaseOffset,
            span.range.end + textBaseOffset,
          ),
          kind: span.kind,
        ),
      );
    }

    if (fallbackWordOccurrence &&
        !merged.any((s) => s.kind == HighlightKind.occurrence)) {
      final word = wordRangeAt(text, local);
      if (word != null) {
        merged.add(
          HighlightSpan(
            range: Range(
              word.start + textBaseOffset,
              word.end + textBaseOffset,
            ),
            kind: HighlightKind.occurrence,
          ),
        );
      }
    }
  }

  return searchRange == null
      ? merged
      : highlightSpansInViewport(merged, searchRange);
}
