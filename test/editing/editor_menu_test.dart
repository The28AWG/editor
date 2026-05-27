import 'package:editor/src/api/editor_action.dart';
import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/api/editor_menu.dart';
import 'package:flutter/material.dart' show ClipboardStatus;
import 'package:test/test.dart';

void main() {
  group('EditorMenuDefaults', () {
    late EditorController controller;

    setUp(() {
      controller = EditorController(initialText: 'hello');
    });

    test('standardItems includes paste when clipboard pasteable', () {
      final ctx = EditorMenuBuildContext(
        controller: controller,
        capabilities: EditorActionCapabilities.of(
          controller,
          clipboardStatus: ClipboardStatus.pasteable,
        ),
        anchor: EditorMenuAnchor.pointer,
        clipboardStatus: ClipboardStatus.pasteable,
        labels: const EditorActionLabels(),
        presentAsMobileToolbar: false,
      );
      final items = EditorMenuDefaults.standardItems(ctx);
      expect(
        items.any(
          (i) =>
              i is EditorStandardMenuItem && i.action == EditorActionId.paste,
        ),
        isTrue,
      );
    });

    test('mobile toolbar omits undo', () {
      controller.undo(); // need undo stack - actually empty doc, canUndo false
      final ctx = EditorMenuBuildContext(
        controller: controller,
        capabilities: EditorActionCapabilities.of(controller),
        anchor: EditorMenuAnchor.selection,
        clipboardStatus: ClipboardStatus.unknown,
        labels: const EditorActionLabels(),
        presentAsMobileToolbar: true,
      );
      final items = EditorMenuDefaults.standardItems(ctx);
      expect(
        items.any(
          (i) => i is EditorStandardMenuItem && i.action == EditorActionId.undo,
        ),
        isFalse,
      );
    });
  });

  group('EditorActionCapabilities', () {
    test('enabledFor reflects readOnly', () {
      final ro = EditorController(initialText: 'x', readOnly: true);
      final caps = EditorActionCapabilities.of(ro);
      expect(caps.canPaste, isFalse);
      expect(caps.canCut, isFalse);
      expect(caps.enabledFor(EditorActionId.copy), isFalse);
    });
  });
}
