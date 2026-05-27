import 'package:editor/src/highlight/word_bounds.dart';
import 'package:editor/src/model/position.dart';
import 'package:test/test.dart';

void main() {
  group('wordRangeAt', () {
    test('returns identifier range', () {
      const text = 'void main()';
      expect(wordRangeAt(text, 5), Range(5, 9));
    });

    test('returns null on whitespace between words', () {
      const text = 'a   b';
      expect(wordRangeAt(text, 2), isNull);
    });

    test('supports dollar identifiers', () {
      const text = r'final $x = 1;';
      expect(wordRangeAt(text, 7), Range(6, 8));
    });
  });
}
