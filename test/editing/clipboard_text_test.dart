import 'package:editor/src/editing/clipboard_text.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:test/test.dart';

void main() {
  group('clipboard_text', () {
    test('copyText joins non-collapsed selections', () {
      final doc = Document.fromText('abcdefghij');
      final text = copyTextForSelections(doc, [
        const Selection(0, 3),
        const Selection(7, 10),
      ]);
      expect(text, 'abc\nhij');
    });

    test('pasteTexts distributes lines per cursor', () {
      expect(pasteTextsForSelections('a\nb\nc', 3), ['a', 'b', 'c']);
      expect(pasteTextsForSelections('hello', 2), ['hello', 'hello']);
    });

    test('splitPasteLines normalizes CRLF', () {
      expect(splitPasteLines('a\r\nb'), ['a', 'b']);
    });
  });
}
