import 'package:editor/src/editing/command_registry.dart';
import 'package:editor/src/editing/commands/backspace_command.dart';
import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/buffer/piece_tree.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:test/test.dart';

void main() {
  test('PieceTree delete last three chars', () {
    const prefix = 'void main() {\n  print(1);\n';
    final text = '${prefix}fff';
    final tree = PieceTree(text);
    final start = prefix.length;
    tree.delete(start, text.length);
    expect(tree.text, prefix);
  });

  test('Document apply delete fff suffix', () {
    const prefix = 'void main() {\n  print(1);\n';
    final doc = Document.fromText('${prefix}fff');
    final start = prefix.length;
    doc.apply([TextEdit.delete(Range(start, doc.length))]);
    expect(doc.text, prefix);
  });

  test('Document apply three inserts at end then delete range', () {
    const prefix = 'void main() {\n  print(1);\n';
    final doc = Document.fromText(prefix);
    var o = prefix.length;
    doc.apply([TextEdit.replace(Range(o, o), 'f')]);
    o++;
    doc.apply([TextEdit.replace(Range(o, o), 'f')]);
    o++;
    doc.apply([TextEdit.replace(Range(o, o), 'f')]);
    expect(doc.text, '${prefix}fff');
    doc.apply([TextEdit.delete(Range(prefix.length, doc.length))]);
    expect(doc.text, prefix);
  });

  test('backspace after typeCharacter via engine selections dump', () {
    const prefix = 'void main() {\n  print(1);\n';
    final doc = Document.fromText(prefix);
    final engine = Transaction(document: doc);
    final reg = CommandRegistry();

    engine.selection = SelectionState([Selection(doc.length, doc.length)]);
    for (final ch in ['f', 'f', 'f']) {
      reg.execute(engine, 'typeCharacter', character: ch);
    }
    expect(doc.text, '${prefix}fff');
    expect(engine.selection.selections.length, 1);

    engine.selection = SelectionState([
      Selection(prefix.length, prefix.length + 3),
    ]);
    // ignore: avoid-duplicate-test-assertions - duplicate assertion is intentional, avoid-duplicate-test-assertions
    expect(engine.selection.selections.length, 1);

    BackspaceCommand().execute(engine, const EditorConfig());
    expect(doc.text, prefix, reason: 'got: ${doc.text}');
  });
}
