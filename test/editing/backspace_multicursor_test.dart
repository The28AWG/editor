import 'package:editor/src/editing/command_registry.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:test/test.dart';

void main() {
  test(
    'backspace deletes full selection when secondary caret is at range end',
    () {
      const text = 'prefix\nавпыва';
      final lineStart = text.indexOf('авпыва');
      final lineEnd = text.length;
      final doc = Document.fromText(text);
      final engine = Transaction(
        document: doc,
        selection: SelectionState([
          Selection(lineStart, lineEnd),
          Selection(lineEnd, lineEnd),
        ]),
      );
      CommandRegistry().execute(engine, 'backspace');
      // Bug: one char of "авпыва" may remain
      expect(doc.text, 'prefix\n');
    },
  );
}
