import 'package:editor/src/editing/command_registry.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:test/test.dart';

void main() {
  group('Commands', () {
    late Document doc;
    late Transaction engine;
    late CommandRegistry registry;

    setUp(() {
      doc = Document.fromText('line one\nline two');
      engine = Transaction(
        document: doc,
        selection: SelectionState([const Selection(0, 0)]),
      );
      registry = CommandRegistry();
    });

    test('typeCharacter', () {
      registry.execute(engine, 'typeCharacter', character: 'x');
      expect(doc.text, 'xline one\nline two');
    });

    test('backspace at line boundary', () {
      engine.selection = SelectionState([const Selection(9, 9)]);
      registry.execute(engine, 'backspace');
      expect(doc.text, 'line oneline two');
    });

    test('insertNewline mid line', () {
      engine.selection = SelectionState([const Selection(4, 4)]);
      registry.execute(engine, 'insertNewline');
      expect(doc.text, 'line\n one\nline two');
    });

    test('insertTab uses spaces', () {
      registry.execute(engine, 'insertTab');
      expect(doc.text, '  line one\nline two');
    });

    test('paste replaces selection', () {
      engine.selection = SelectionState([const Selection(0, 4)]);
      registry.execute(engine, 'paste', pasteText: 'X');
      expect(doc.text, 'X one\nline two');
    });

    test('cut removes selection after copy semantics', () {
      engine.selection = SelectionState([const Selection(0, 4)]);
      registry.execute(engine, 'cut');
      expect(doc.text, ' one\nline two');
    });
  });
}
