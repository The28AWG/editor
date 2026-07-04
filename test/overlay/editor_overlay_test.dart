import 'package:editor/src/overlay/editor_overlay_anchor.dart';
import 'package:editor/src/overlay/editor_overlay_coordinator.dart';
import 'package:editor/src/overlay/editor_overlay_descriptor.dart';
import 'package:editor/src/overlay/editor_overlay_dismiss.dart';
import 'package:editor/src/overlay/editor_overlay_keyboard.dart';
import 'package:editor/src/overlay/editor_overlay_layout.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

void main() {
  group('computeOverlayLayout', () {
    const viewport = Rect.fromLTWH(0, 0, 400, 300);
    const anchor = Rect.fromLTWH(40, 100, 8, 20);

    test('places below anchor by default', () {
      final result = computeOverlayLayout(
        anchorRect: anchor,
        viewportRect: viewport,
        policy: const EditorOverlayLayoutPolicy(gap: 4),
      );
      expect(result.effectivePlacement, EditorOverlayPlacement.below);
      expect(result.offset.dy, anchor.bottom + 4);
      expect(result.offset.dx, anchor.left);
    });

    test('flips above when below overflows', () {
      final lowAnchor = const Rect.fromLTWH(10, 280, 8, 20);
      final result = computeOverlayLayout(
        anchorRect: lowAnchor,
        viewportRect: viewport,
        policy: const EditorOverlayLayoutPolicy(gap: 4, preferredHeight: 120),
      );
      expect(result.effectivePlacement, EditorOverlayPlacement.above);
      expect(result.offset.dy, lessThan(lowAnchor.top));
    });

    test('besideEnd places panel to the right', () {
      final result = computeOverlayLayout(
        anchorRect: anchor,
        viewportRect: viewport,
        policy: const EditorOverlayLayoutPolicy(
          placement: EditorOverlayPlacement.besideEnd,
          preferredWidth: 200,
          preferredHeight: 100,
        ),
      );
      expect(result.offset.dx, anchor.right + 4);
    });

    test('besideEnd aligns child to parent top by default', () {
      const parentPanel = Rect.fromLTWH(40, 80, 180, 120);
      final result = computeOverlayLayout(
        anchorRect: parentPanel,
        viewportRect: viewport,
        policy: const EditorOverlayLayoutPolicy(
          placement: EditorOverlayPlacement.besideEnd,
          preferredHeight: 100,
        ),
        relativeToRect: parentPanel,
      );
      expect(result.offset.dx, parentPanel.right + 4);
      expect(result.offset.dy, parentPanel.top);
    });

    test('besideEnd centers child vertically on parent panel', () {
      const parentPanel = Rect.fromLTWH(40, 80, 180, 120);
      final result = computeOverlayLayout(
        anchorRect: parentPanel,
        viewportRect: viewport,
        policy: const EditorOverlayLayoutPolicy(
          placement: EditorOverlayPlacement.besideEnd,
          childAlign: EditorOverlayChildAlign.center,
          preferredHeight: 60,
        ),
        relativeToRect: parentPanel,
      );
      expect(result.offset.dy, parentPanel.top + (parentPanel.height - 60) / 2);
    });
  });

  group('EditorOverlayCoordinator', () {
    late EditorOverlayCoordinator coordinator;

    EditorOverlayDescriptor descriptor({
      required String id,
      int priority = 0,
      EditorOverlayKind kind = EditorOverlayKind.custom,
      bool documentChange = true,
      List<EditorOverlayDescriptor> children = const [],
    }) => EditorOverlayDescriptor(
      id: id,
      priority: priority,
      kind: kind,
      dismissPolicy: EditorOverlayDismissPolicy(
        documentChange: documentChange,
        scroll: false,
      ),
      anchor: const EditorViewportOverlayAnchor(),
      builder: (_, _) => const SizedBox(width: 100, height: 50),
      children: children,
    );

    setUp(() {
      coordinator = EditorOverlayCoordinator();
    });

    test('show replaces same id', () {
      coordinator
        ..show(descriptor(id: 'a'))
        ..show(descriptor(id: 'a'));
      expect(coordinator.sessions.length, 1);
    });

    test('higher priority supersedes lower', () {
      coordinator
        ..show(descriptor(id: 'low', priority: 1))
        ..show(descriptor(id: 'high', priority: 10));
      expect(coordinator.sessions.length, 1);
      expect(coordinator.sessions.single.id, 'high');
    });

    test('exclusive within kind', () {
      coordinator
        ..show(descriptor(id: 'c1', kind: EditorOverlayKind.completion))
        ..show(descriptor(id: 'c2', kind: EditorOverlayKind.completion));
      expect(coordinator.sessions.length, 1);
      expect(coordinator.sessions.single.id, 'c2');
    });

    test('onDocumentChanged dismisses matching overlays', () {
      coordinator
        ..show(descriptor(id: 'a', documentChange: true))
        ..onDocumentChanged(2);
      expect(coordinator.isEmpty, isTrue);
    });

    test('registers nested children', () {
      coordinator.show(
        descriptor(
          id: 'parent',
          children: [descriptor(id: 'child', documentChange: false)],
        ),
      );
      expect(coordinator.sessions.length, 2);
      expect(
        coordinator.sessions.map((s) => s.id).toList(),
        containsAll(['parent', 'child']),
      );
    });

    test('hide removes children', () {
      coordinator
        ..show(
          descriptor(
            id: 'parent',
            children: [descriptor(id: 'child')],
          ),
        )
        ..hide('parent');
      expect(coordinator.isEmpty, isTrue);
    });

    test('dismissOnEscape hides top overlay', () {
      coordinator.show(descriptor(id: 'a'));
      expect(coordinator.dismissOnEscape(), isTrue);
      expect(coordinator.isEmpty, isTrue);
    });

    test('dismissOnEscape hides parent when top is nested child', () {
      coordinator.show(
        EditorOverlayDescriptor(
          id: 'parent',
          priority: 100,
          capturesKeyboard: true,
          anchor: const EditorViewportOverlayAnchor(),
          builder: (_, _) => const SizedBox(width: 100, height: 50),
          children: [
            EditorOverlayDescriptor(
              id: 'child',
              priority: 101,
              anchor: const EditorViewportOverlayAnchor(),
              builder: (_, _) => const SizedBox(width: 100, height: 50),
            ),
          ],
        ),
      );
      expect(coordinator.topSession?.id, 'child');
      expect(
        coordinator.sessions.map((s) => s.id),
        containsAll(['parent', 'child']),
      );
      expect(coordinator.capturesKeyboard, isTrue);
      expect(coordinator.dismissOnEscape(), isTrue);
      expect(coordinator.isEmpty, isTrue);
    });

    test('dismissOnEscape respects escape policy', () {
      coordinator.show(
        EditorOverlayDescriptor(
          id: 'sticky',
          anchor: const EditorViewportOverlayAnchor(),
          dismissPolicy: const EditorOverlayDismissPolicy(escape: false),
          builder: (_, _) => const SizedBox(width: 100, height: 50),
        ),
      );
      expect(coordinator.dismissOnEscape(), isFalse);
      expect(coordinator.isNotEmpty, isTrue);
    });

    test('move stores user offset on session', () {
      coordinator
        ..show(descriptor(id: 'panel'))
        ..move('panel', const Offset(12, 8));
      expect(coordinator.sessions.single.userOffset, const Offset(12, 8));
    });

    test('dispatchCooperativeKeyEvent handles configured keys only', () {
      var moved = false;
      coordinator.show(
        EditorOverlayDescriptor(
          id: 'completion',
          anchor: const EditorViewportOverlayAnchor(),
          keyboardPolicy: EditorOverlayKeyboardPolicy.cooperative,
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              moved = true;
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          builder: (_, _) => const SizedBox.shrink(),
        ),
      );
      expect(
        coordinator.dispatchCooperativeKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey(0),
            logicalKey: LogicalKeyboardKey.arrowDown,
            timeStamp: Duration.zero,
          ),
        ),
        KeyEventResult.handled,
      );
      expect(moved, isTrue);
      expect(
        coordinator.dispatchCooperativeKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey(0),
            logicalKey: LogicalKeyboardKey.keyA,
            timeStamp: Duration.zero,
          ),
        ),
        KeyEventResult.ignored,
      );
    });

    test('show preserves geometry when replacing same id', () {
      coordinator
        ..show(
          descriptor(
            id: 'parent',
            children: [descriptor(id: 'child')],
          ),
        )
        ..updateMeasuredSize('parent', const Size(220, 140))
        ..resize('child', const Size(360, 240))
        ..move('child', const Offset(8, 4))
        ..show(
          descriptor(
            id: 'parent',
            children: [descriptor(id: 'child')],
          ),
        );
      final parent = coordinator.sessions.firstWhere((s) => s.id == 'parent');
      final child = coordinator.sessions.firstWhere((s) => s.id == 'child');
      expect(parent.measuredSize, const Size(220, 140));
      expect(child.userSize, const Size(360, 240));
      expect(child.userOffset, const Offset(8, 4));
    });
  });

  group('clampOverlayUserOffset', () {
    test('keeps panel inside viewport', () {
      const base = Offset(100, 80);
      const panel = Size(200, 120);
      const viewport = Size(400, 300);
      final clamped = clampOverlayUserOffset(
        baseOffset: base,
        userOffset: const Offset(500, 500),
        panelSize: panel,
        viewportSize: viewport,
      );
      expect(base + clamped, const Offset(200, 180));
    });
  });
}
