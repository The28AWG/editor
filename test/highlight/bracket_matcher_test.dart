import 'package:editor/src/highlight/bracket_matcher.dart';
import 'package:editor/src/highlight/highlight_kind.dart';
import 'package:test/test.dart';

void main() {
  group('matchBrackets', () {
    test('matches parentheses', () {
      const text = 'void f() {}';
      final match = matchBrackets(text, 7);
      expect(match, isNotNull);
      expect(match!.openOffset, 6);
      expect(match.closeOffset, 7);
    });

    test('ignores brackets in strings', () {
      const text = 'final s = "(not a bracket)";';
      expect(matchBrackets(text, 14), isNull);
    });

    test('ignores brackets in line comments', () {
      const text = 'x = 1; // ) (';
      expect(matchBrackets(text, 12), isNull);
    });

    test('nested braces', () {
      const text = 'a { b { c } }';
      final inner = matchBrackets(text, 10);
      expect(inner?.openOffset, 6);
      expect(inner?.closeOffset, 10);

      final outer = matchBrackets(text, 2);
      expect(outer?.openOffset, 2);
      expect(outer?.closeOffset, 12);
    });

    test('respects search bounds', () {
      const text = '0123456789(abc)xyz';
      // пара ( ) на 10..15; ищем только в [0, 12) — закрывающая за пределами
      expect(matchBrackets(text, 10, searchEnd: 12), isNull);
      // закрывающая внутри диапазона
      final match = matchBrackets(text, 10, searchEnd: 16);
      expect(match?.closeOffset, 14);

      const back = 'aa(bb)cc';
      // закрывающая на 5; диапазон [5, 8) — открывающая за пределами
      expect(matchBrackets(back, 5, searchStart: 5), isNull);
    });
  });

  group('bracketHighlightSpans', () {
    test('highlights active bracket when partner is outside search bounds', () {
      const text = '0123456789(abc)xyz';
      final spans = bracketHighlightSpans(text, 10, searchEnd: 12);
      expect(spans, hasLength(1));
      expect(spans.single.kind, HighlightKind.bracketActive);
      expect(spans.single.range.start, 10);
    });

    test('highlights active when partner beyond viewport text slice', () {
      const slice = '0123456789(ab'; // закрывающая ) за пределами среза
      final spans = bracketHighlightSpans(slice, 10, boundedSearch: true);
      expect(spans, hasLength(1));
      expect(spans.single.kind, HighlightKind.bracketActive);
    });
  });
}
