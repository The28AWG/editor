import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/selection/cursor.dart';
import 'package:test/test.dart';

void main() {
  group('cursorLineStart', () {
    late Document doc;

    test('from middle of line goes to first non-whitespace', () {
      doc = Document.fromText('    hello');
      expect(cursorLineStart(doc, 9), 4);
    });

    test('from indent goes to first non-whitespace', () {
      doc = Document.fromText('    hello');
      expect(cursorLineStart(doc, 2), 4);
    });

    test('from first non-whitespace toggles to column 0', () {
      doc = Document.fromText('    hello');
      expect(cursorLineStart(doc, 4), 0);
    });

    test('at column 0 stays', () {
      doc = Document.fromText('    hello');
      expect(cursorLineStart(doc, 0), 0);
    });

    test('line without indent uses column 0', () {
      doc = Document.fromText('hello');
      expect(cursorLineStart(doc, 3), 0);
      expect(cursorLineStart(doc, 0), 0);
    });

    test('tabs count as indent', () {
      doc = Document.fromText('\thello');
      expect(cursorLineStart(doc, 6), 1);
      expect(cursorLineStart(doc, 1), 0);
    });

    test('whitespace-only line stays at 0', () {
      doc = Document.fromText('   \nnext');
      expect(cursorLineStart(doc, 2), 0);
    });

    test('empty line', () {
      doc = Document.fromText('a\n\nb');
      expect(cursorLineStart(doc, 2), 2);
    });
  });

  group('cursorMoveDown with desiredColumn', () {
    test('remembers column across short then long line', () {
      final doc = Document.fromText('1234567890\nabc\n123456789012345');
      // line 0 col 10, line 1 max col 3, line 2 max col 15
      var offset = doc.offsetAt(const Position(0, 10));
      offset = cursorMoveDown(doc, offset, 10);
      expect(doc.positionAt(offset).column, 3);
      offset = cursorMoveDown(doc, offset, 10);
      expect(doc.positionAt(offset).column, 10);
    });

    test('moveUp uses desiredColumn', () {
      final doc = Document.fromText('short\n1234567890');
      var offset = doc.offsetAt(const Position(1, 8));
      offset = cursorMoveUp(doc, offset, 8);
      expect(doc.positionAt(offset).column, 5);
    });
  });
}
