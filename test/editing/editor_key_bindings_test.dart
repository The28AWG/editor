import 'package:editor/src/api/editor_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Shift+Arrow resolves caret move with extendSelection', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);

    final inv = EditorKeyBindings.resolve(
      KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.arrowRight,
        logicalKey: LogicalKeyboardKey.arrowRight,
        timeStamp: Duration.zero,
      ),
      EditorActionDefaults.bindings,
    );

    expect(inv?.id, EditorActionId.moveCaretRight);
    expect(inv?.extendSelection, isTrue);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  });
}
