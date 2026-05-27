import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/editing/command_registry.dart';
import 'package:editor/src/highlight/word_bounds.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  test('word select fff at EOF then backspace removes all', () {
    const prefix = 'void main() {\n  print(1);\n';
    const suffix = 'fff';
    final text = '$prefix$suffix';
    final start = text.length - 3;

    final range = wordRangeAt(text, start + 2)!;
    expect(range.start, start);
    expect(range.end, text.length);

    final c = EditorController(initialText: text)
      ..setPrimarySelection(Selection(range.start, range.end));
    expect(c.document.getText(c.selection.primary.range), 'fff');
    expect(c.selection.selections.length, 1);

    c.executeCommand('backspace');
    expect(c.document.text, prefix);
    expect(c.document.text.endsWith('f'), isFalse);
    expect(c.selection.primary, Selection(start, start));
  });

  test('backspace after double-click-like cursor then word select', () {
    const text = 'void main() {\n  print(1);\nfff';
    final start = text.length - 3;
    final c = EditorController(initialText: text)
      // First click of double: caret on last f
      ..setSingleCursor(start + 2);
    expect(c.selection.primary.head, start + 2);

    // Second click: word select
    final range = wordRangeAt(text, start + 2)!;
    c.setPrimarySelection(Selection(range.start, range.end));
    expect(c.document.getText(c.selection.primary.range), 'fff');

    c.executeCommand('backspace');
    expect(c.document.text, text.characters.getRange(0, start).toString());
  });

  test('typeCharacter fff at document end then backspace selection', () {
    const prefix = 'void main() {\n  print(1);\n';
    final c = EditorController(initialText: prefix);
    final registry = CommandRegistry();
    final engine = c.engine
      ..selection = SelectionState([
        Selection(c.document.length, c.document.length),
      ]);
    for (final ch in ['f', 'f', 'f']) {
      registry.execute(engine, 'typeCharacter', character: ch);
    }
    expect(c.document.text, '${prefix}fff');
    final start = prefix.length;
    expect(engine.selection.primary.head, start + 3);

    c
      ..setPrimarySelection(Selection(start, start + 3))
      ..executeCommand('backspace');
    expect(c.document.text, prefix);
  });
}
