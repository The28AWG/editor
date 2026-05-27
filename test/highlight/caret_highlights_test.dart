import 'package:editor/src/highlight/caret_highlights.dart';
import 'package:editor/src/highlight/highlight_kind.dart';
import 'package:editor/src/highlight/highlight_span.dart';
import 'package:editor/src/model/position.dart';
import 'package:test/test.dart';

void main() {
  test('includes brackets and fallback word', () {
    const text = 'void main()';
    final spans = caretHighlightsFor(text: text, offset: 5);
    expect(
      spans.any((s) => s.kind == HighlightKind.bracket),
      isFalse,
      reason: 'no bracket at m',
    );
    expect(spans.any((s) => s.kind == HighlightKind.occurrence), isTrue);
  });

  test('merges language spans without duplicate fallback', () {
    const text = 'void main()';
    final spans = caretHighlightsFor(
      text: text,
      offset: 5,
      languageSpans: const [],
      fallbackWordOccurrence: false,
    );
    expect(spans.any((s) => s.kind == HighlightKind.occurrence), isFalse);
  });

  test('drops language spans outside searchRange', () {
    const text = 'void main()';
    final spans = caretHighlightsFor(
      text: text,
      offset: 5,
      searchRange: const Range(0, 4),
      languageSpans: const [
        HighlightSpan(range: Range(0, 4), kind: HighlightKind.occurrence),
        HighlightSpan(range: Range(5, 9), kind: HighlightKind.occurrence),
        HighlightSpan(range: Range(10, 11), kind: HighlightKind.linkedEditing),
      ],
      fallbackWordOccurrence: false,
    );
    expect(spans, hasLength(1));
    expect(spans.single.range, const Range(0, 4));
  });

  test('highlights active bracket in viewport slice when pair is far', () {
    const slice = 'void f() { foo'; // '{' без закрывающей '}' в срезе
    const base = 1000;
    const searchRange = Range(base, base + slice.length);
    final spans = caretHighlightsFor(
      text: slice,
      textBaseOffset: base,
      offset: base + 9, // на '{'
      searchRange: searchRange,
      fallbackWordOccurrence: false,
    );
    expect(spans.any((s) => s.kind == HighlightKind.bracketActive), isTrue);
  });
}
