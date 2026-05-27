import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:flutter/material.dart';
import 'package:test/test.dart';

void main() {
  test(
    'backspace deletes full selection on last line without trailing newline',
    () {
      final text = 'void main() {\n  print("hi");\nавпыва';
      final start = text.length - 6;
      final c = EditorController(initialText: text)
        ..setPrimarySelection(Selection(start, text.length));
      expect(c.document.getText(c.selection.primary.range), 'авпыва');
      c.executeCommand('backspace');
      expect(c.document.text, text.characters.getRange(0, start).toString());
      expect(c.document.text.length, start);
      expect(c.selection.primary, Selection(start, start));
    },
  );

  test(
    'backspace deletes selection when head is lineContentEnd not last char',
    () {
      final text = 'prefix\nавпыва';
      final lineStart = text.indexOf('авпыва');
      final contentEnd = lineStart + 'авпыва'.length;
      final c = EditorController(initialText: text)
        ..setPrimarySelection(Selection(lineStart, contentEnd))
        ..executeCommand('backspace');
      expect(c.document.text, 'prefix\n');
      expect(c.selection.primary.head, lineStart);
    },
  );

  test('document length vs lineContentEnd on last line', () {
    final text = 'line\nавпыва';
    final doc = EditorController(initialText: text).document;
    expect(doc.lineContentEnd(1), doc.length);
    expect(doc.length, text.length);
  });
}
