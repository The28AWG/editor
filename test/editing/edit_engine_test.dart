import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/model/transaction.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:test/test.dart';

void main() {
  group('Transaction', () {
    test('apply and undo redo', () {
      final doc = Document.fromText('hello');
      final engine = Transaction(
        document: doc,
        selection: SelectionState([const Selection(5, 5)]),
      )..apply([TextEdit.insert(5, '!')]);
      expect(doc.text, 'hello!');

      engine.undo();
      expect(doc.text, 'hello', reason: 'after undo');

      engine.redo();
      expect(doc.text, 'hello!', reason: 'after redo');
    });

    test('version increments', () {
      final doc = Document.fromText('');
      final engine = Transaction(document: doc);
      expect(doc.version, 0);
      engine.apply([TextEdit.insert(0, 'x')]);
      expect(doc.version, 1);
    });

    test('merge typing undo key', () {
      final doc = Document.fromText('');
      final engine = Transaction(document: doc)
        ..apply([
          TextEdit.insert(0, 'a'),
        ], metadata: const TransactionMetadata(mergeKey: 'typing'))
        ..apply([
          TextEdit.insert(1, 'b'),
        ], metadata: const TransactionMetadata(mergeKey: 'typing'));
      expect(doc.text, 'ab');
      engine.undo();
      expect(doc.text, '');
      engine.redo();
      // ignore: avoid-duplicate-test-assertions, - duplicate assertion is intentional
      expect(doc.text, 'ab');
    });

    test('merge typing redo at document end', () {
      final doc = Document.fromText('x' * 163);
      final engine =
          Transaction(
              document: doc,
              selection: SelectionState([Selection(163, 163)]),
            )
            ..apply([
              TextEdit.insert(163, 'a'),
            ], metadata: const TransactionMetadata(mergeKey: 'typing'))
            ..apply([
              TextEdit.insert(164, 'b'),
            ], metadata: const TransactionMetadata(mergeKey: 'typing'))
            ..apply([
              TextEdit.insert(165, 'c'),
            ], metadata: const TransactionMetadata(mergeKey: 'typing'));
      expect(doc.length, 166);
      engine.undo();
      expect(doc.length, 163);
      engine.redo();
      expect(doc.text, '${'x' * 163}abc');
    });
  });
}
