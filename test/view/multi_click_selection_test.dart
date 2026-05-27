import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/highlight/word_bounds.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wordRangeAt selects full identifier for mid-word offset', () {
    const text = 'void greet(String name, {int count = 1}) {';
    final nameStart = text.indexOf('name');
    final range = wordRangeAt(text, nameStart + 2);
    expect(range, isNotNull);
    expect(range!.start, nameStart);
    expect(range.end, nameStart + 4);
  });

  test(
    'double-click word selection keeps full range not truncated to offset',
    () {
      const text = 'void greet(String name) {';
      final nameStart = text.indexOf('name');
      final midName = nameStart + 2;

      final range = wordRangeAt(text, midName);
      expect(range!.start, nameStart);
      expect(range.end, nameStart + 4);

      final controller = EditorController(initialText: text)
        ..setPrimarySelection(Selection(range.start, range.end));

      final sel = controller.selection.primary;
      expect(sel.anchor, nameStart);
      expect(sel.head, nameStart + 4);
      expect(sel.isCollapsed, isFalse);
    },
  );
}
