import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:editor/src/view/input/editor_text_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('editingValueFor maps document text and primary selection', () {
    final controller = EditorController(initialText: 'ab\nc')
      ..setPrimarySelection(const Selection(1, 4));

    final value = EditorTextInputClient.editingValueFor(controller);

    expect(value.text, 'ab\nc');
    expect(value.selection.baseOffset, 1);
    expect(value.selection.extentOffset, 4);
  });
}
