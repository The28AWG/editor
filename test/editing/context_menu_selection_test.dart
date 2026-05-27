import 'package:editor/src/editing/clipboard_text.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:test/test.dart';

void main() {
  group('shouldMoveCaretForPointerMenu', () {
    test('collapsed selection always moves', () {
      expect(shouldMoveCaretForPointerMenu(5, const Selection(2, 2)), isTrue);
    });

    test('click inside range keeps selection', () {
      expect(shouldMoveCaretForPointerMenu(5, const Selection(0, 10)), isFalse);
    });

    test('click outside range moves', () {
      expect(shouldMoveCaretForPointerMenu(15, const Selection(0, 10)), isTrue);
    });
  });
}
