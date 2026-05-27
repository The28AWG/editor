import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:test/test.dart';

void main() {
  group('Document', () {
    test('positionAt offsetAt roundtrip', () {
      final doc = Document.fromText('ab\ncde\n');
      expect(doc.positionAt(0), const Position(0, 0));
      expect(doc.positionAt(3), const Position(1, 0));
      expect(doc.offsetAt(const Position(1, 2)), 5);
    });

    test('emoji surrogate pair column', () {
      final doc = Document.fromText('a😀b');
      expect(doc.positionAt(3), const Position(0, 3));
      expect(doc.length, 4);
    });

    test('crlf line break', () {
      final doc = Document.fromText('a\r\nb');
      expect(doc.lineCount, 2);
      expect(doc.positionAt(3), const Position(1, 0));
    });

    test('lineContentEnd is absolute offset after line start', () {
      final doc = Document.fromText('hello\nworld');
      expect(doc.lineStart(1), 6);
      expect(doc.lineContentEnd(1), 11);
      expect(doc.lineContentEnd(1), greaterThan(doc.lineStart(1)));
    });
  });
}
