import 'package:editor/src/api/editor_action.dart';
import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/api/editor_menu.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:flutter/material.dart' show ClipboardStatus;
import 'package:test/test.dart';

void main() {
  group('EditorActions', () {
    late EditorController controller;

    setUp(() {
      controller = EditorController(initialText: 'hello');
    });

    test('perform undo after edit', () async {
      controller.executeCommand('typeCharacter', character: '!');
      expect(controller.canUndo, isTrue);
      expect(await controller.perform(EditorActionId.undo), isTrue);
      expect(controller.document.text, 'hello');
    });

    test('canPerform paste respects readOnly', () {
      final ro = EditorController(initialText: 'x', readOnly: true);
      expect(
        ro.canPerform(
          EditorActionId.paste,
          clipboardStatus: ClipboardStatus.pasteable,
        ),
        isFalse,
      );
    });

    test('moveCaret with extendSelection', () {
      controller.setPrimarySelection(const Selection(1, 3));
      final ctx = EditorActionContext(controller: controller);
      EditorActions.perform(
        ctx,
        const EditorActionInvocation(
          EditorActionId.moveCaretRight,
          extendSelection: true,
        ),
      );
      expect(controller.selection.primary.head, 4);
      expect(controller.selection.primary.anchor, 1);
    });

    test('moveCaret moves all multi cursors', () {
      controller = EditorController(initialText: 'hello world')
        ..setSelection(
          SelectionState([
            const Selection(1, 1),
            const Selection(3, 3),
            const Selection(5, 5),
          ]),
        );
      final ctx = EditorActionContext(controller: controller);
      EditorActions.perform(
        ctx,
        const EditorActionInvocation(EditorActionId.moveCaretRight),
      );
      expect(controller.selection.selections, [
        const Selection(2, 2),
        const Selection(4, 4),
        const Selection(6, 6),
      ]);
    });

    test('moveCaret merges when shift selections touch', () {
      controller = EditorController(initialText: '0123456789')
        ..setSelection(
          SelectionState([const Selection(3, 3), const Selection(8, 8)]),
        );
      final ctx = EditorActionContext(controller: controller);
      for (var i = 0; i < 5; i++) {
        EditorActions.perform(
          ctx,
          const EditorActionInvocation(
            EditorActionId.moveCaretLeft,
            extendSelection: true,
          ),
        );
      }
      expect(controller.selection.selections.length, 1);
      expect(controller.selection.primary.start, 0);
      expect(controller.selection.primary.end, 8);
    });

    test('moveCaretDown preserves desired column across lines', () {
      controller = EditorController(
        initialText: '1234567890\nabc\n123456789012345',
      );
      final start = controller.document.offsetAt(const Position(0, 10));
      controller.setPrimarySelection(Selection(start, start));
      final ctx = EditorActionContext(controller: controller);
      EditorActions.perform(
        ctx,
        const EditorActionInvocation(EditorActionId.moveCaretDown),
      );
      expect(
        controller.selection.primary.head,
        controller.document.offsetAt(const Position(1, 3)),
      );
      EditorActions.perform(
        ctx,
        const EditorActionInvocation(EditorActionId.moveCaretDown),
      );
      expect(
        controller.selection.primary.head,
        controller.document.offsetAt(const Position(2, 10)),
      );
      expect(controller.selection.desiredColumns, [10]);
    });

    test('moveCaretRight updates desired column', () {
      controller.setPrimarySelection(const Selection(0, 0));
      final ctx = EditorActionContext(controller: controller);
      for (var i = 0; i < 4; i++) {
        EditorActions.perform(
          ctx,
          const EditorActionInvocation(EditorActionId.moveCaretRight),
        );
      }
      expect(controller.selection.desiredColumns, [4]);
    });

    test('moveCaretLineStart and moveCaretLineEnd', () {
      controller = EditorController(initialText: 'ab\ncde\nfg')
        ..setPrimarySelection(const Selection(5, 5));
      final ctx = EditorActionContext(controller: controller);
      EditorActions.perform(
        ctx,
        const EditorActionInvocation(EditorActionId.moveCaretLineStart),
      );
      expect(controller.selection.primary.head, 3);
      EditorActions.perform(
        ctx,
        const EditorActionInvocation(EditorActionId.moveCaretLineEnd),
      );
      expect(controller.selection.primary.head, 6);
    });

    test('moveCaretLineEnd with extendSelection', () {
      controller.setPrimarySelection(const Selection(1, 3));
      final ctx = EditorActionContext(controller: controller);
      EditorActions.perform(
        ctx,
        const EditorActionInvocation(
          EditorActionId.moveCaretLineEnd,
          extendSelection: true,
        ),
      );
      expect(controller.selection.primary.head, 5);
      expect(controller.selection.primary.anchor, 1);
    });

    test('moveCaret deduplicates carets at document edge', () {
      controller = EditorController(initialText: 'abc')
        ..setSelection(
          SelectionState([
            const Selection(3, 3),
            const Selection(3, 3),
            const Selection(3, 3),
          ]),
        );
      final ctx = EditorActionContext(controller: controller);
      EditorActions.perform(
        ctx,
        const EditorActionInvocation(EditorActionId.moveCaretRight),
      );
      expect(controller.selection.selections, [const Selection(3, 3)]);
    });
  });

  group('EditorKeyBindings', () {
    test('default bindings include undo', () {
      expect(
        EditorActionDefaults.bindings.any(
          (b) => b.action == EditorActionId.undo,
        ),
        isTrue,
      );
    });
  });

  group('EditorMenuDefaults', () {
    test('respects disabledActions', () {
      final controller = EditorController(initialText: 'hi');
      final ctx = EditorMenuBuildContext(
        controller: controller,
        capabilities: EditorActionCapabilities.of(controller),
        anchor: EditorMenuAnchor.pointer,
        clipboardStatus: ClipboardStatus.pasteable,
        labels: const EditorActionLabels(),
        presentAsMobileToolbar: false,
        actionConfiguration: const EditorActionConfiguration(
          disabledActions: {EditorActionId.cut},
        ),
      );
      final items = EditorMenuDefaults.standardItems(ctx);
      expect(
        items.any(
          (i) => i is EditorStandardMenuItem && i.action == EditorActionId.cut,
        ),
        isFalse,
      );
    });
  });

  group('EditorController selection', () {
    test('setSingleCursor removes secondary carets', () {
      final controller = EditorController(initialText: 'hello')
        ..setSelection(
          SelectionState([
            const Selection(1, 1),
            const Selection(3, 3),
            const Selection(5, 5),
          ]),
        )
        ..setSingleCursor(2);
      expect(controller.selection.selections, [const Selection(2, 2)]);
    });
  });

  group('EditorActionRegistry', () {
    test('custom action', () async {
      var called = false;
      final controller = EditorController(initialText: '');
      controller.actionRegistry.registerCustom(
        'fmt',
        perform: (_) async {
          called = true;
          return true;
        },
      );
      await controller.performCustom('fmt');
      expect(called, isTrue);
    });
  });
}
