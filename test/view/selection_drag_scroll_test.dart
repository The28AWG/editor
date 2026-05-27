import 'package:editor/editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hit-test stays correct after vertical scroll', (tester) async {
    final lines = List<String>.generate(40, (i) => 'line $i').join('\n');
    final controller = EditorController(initialText: lines);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 200,
          width: 400,
          child: EditorView(controller: controller, showGutter: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -120));
    await tester.pumpAndSettle();

    final scrollOffset = controller.viewport.scrollOffset;
    expect(scrollOffset, greaterThan(0));

    final editor = find.byType(EditorView);
    final center = tester.getCenter(editor);
    await tester.startGesture(center);
    await tester.pump();

    final pos = controller.selection.primary.head;
    final line = controller.document.positionAt(pos).line;
    expect(line, greaterThan(0));
    expect(line, lessThan(39));

    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('drag at bottom edge increases scroll and selection', (
    tester,
  ) async {
    final lines = List<String>.generate(60, (i) => 'row $i').join('\n');
    final controller = EditorController(initialText: lines);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 180,
          width: 400,
          child: EditorView(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editorBox = tester.getRect(find.byType(EditorView));
    final start = Offset(editorBox.left + 20, editorBox.top + 30);
    final bottomEdge = Offset(editorBox.left + 20, editorBox.bottom - 4);

    final gesture = await tester.startGesture(start);
    await tester.pump();
    final anchor = controller.selection.primary.anchor;

    await gesture.moveTo(bottomEdge);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }

    final scrollAfter = controller.viewport.scrollOffset;
    final head = controller.selection.primary.head;
    expect(scrollAfter, greaterThan(0));
    expect(head, greaterThan(anchor));

    await gesture.up();
  });
}
