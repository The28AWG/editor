import 'package:editor/src/overlay/editor_overlay_coordinator.dart';
import 'package:editor/src/overlay/editor_overlay_descriptor.dart';
import 'package:editor/src/overlay/editor_overlay_draggable.dart';
import 'package:editor/src/overlay/editor_overlay_keyboard.dart';
import 'package:editor/src/overlay/editor_overlay_layout.dart';
import 'package:editor/src/overlay/editor_overlay_resizable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Отрисовывает стек overlay поверх viewport редактора.
final class EditorOverlayStack extends StatelessWidget {
  const EditorOverlayStack({
    required this.coordinator,
    required this.viewportSize,
    this.onDismissTop,
    super.key,
  });

  final EditorOverlayCoordinator coordinator;
  final Size viewportSize;
  final VoidCallback? onDismissTop;

  void _onScrimPointerDown(EditorOverlaySession? top) {
    if (top != null) coordinator.hide(top.id);
    onDismissTop?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = coordinator.sessions;
    if (sessions.isEmpty) return const SizedBox.shrink();

    final top = coordinator.topSession;
    final scrimDismiss =
        top?.descriptor.dismissPolicy.outsidePointerDown ?? false;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (scrimDismiss)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _onScrimPointerDown(top),
            ),
          ),
        for (final session in sessions)
          _OverlayPanel(
            key: ValueKey(session.id),
            coordinator: coordinator,
            session: session,
            viewportSize: viewportSize,
          ),
      ],
    );
  }
}

final class _OverlayPanel extends StatefulWidget {
  const _OverlayPanel({
    required this.coordinator,
    required this.session,
    required this.viewportSize,
    super.key,
  });

  final EditorOverlayCoordinator coordinator;
  final EditorOverlaySession session;
  final Size viewportSize;

  @override
  State<_OverlayPanel> createState() => _OverlayPanelState();
}

final class _OverlayPanelState extends State<_OverlayPanel> {
  final GlobalKey _measureKey = GlobalKey();
  EditorOverlayLayoutResult? _layout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportSize());
  }

  @override
  void didUpdateWidget(_OverlayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportSize());
  }

  void _reportSize() {
    final ctx = _measureKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    widget.coordinator.updateMeasuredSize(widget.session.id, box.size);
  }

  void _handleDragDelta(Offset delta) {
    final layout = _layout;
    if (layout == null) return;
    final session = widget.session;
    final policy = session.descriptor.layout;
    final panelSize =
        session.effectiveSize ??
        Size(
          policy.preferredWidth ?? policy.minWidth,
          policy.preferredHeight ?? policy.minHeight,
        );
    final next = clampOverlayUserOffset(
      baseOffset: layout.offset,
      userOffset: session.userOffset + delta,
      panelSize: panelSize,
      viewportSize: widget.viewportSize,
      margin: policy.margin,
    );
    session.move(next);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final descriptor = session.descriptor;
    final anchor = session.anchorRect;
    if (anchor == null) return const SizedBox.shrink();

    final viewportRect = Offset.zero & widget.viewportSize;
    final layout = computeOverlayLayout(
      anchorRect: anchor,
      viewportRect: viewportRect,
      policy: descriptor.layout,
      contentSize: session.effectiveSize,
      relativeToRect: descriptor.parentId != null ? anchor : null,
    );
    _layout = layout;

    var content = descriptor.builder(context, session);

    if (descriptor.layout.resizable) {
      final initial = Size(
        descriptor.layout.preferredWidth ?? layout.maxWidth,
        descriptor.layout.preferredHeight ?? 200,
      );
      content = EditorResizablePanel(
        key: _measureKey,
        initialSize: session.userSize ?? initial,
        minSize: Size(descriptor.layout.minWidth, descriptor.layout.minHeight),
        maxSize: Size(layout.maxWidth, layout.maxHeight),
        handle: descriptor.layout.resizeHandle,
        onResize: session.resize,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(4),
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      );
    } else {
      content = Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: KeyedSubtree(key: _measureKey, child: content),
      );
    }

    final panel = _usesExclusiveKeyboard(descriptor)
        ? _OverlayFocusScope(
            onEscape: descriptor.dismissPolicy.escape
                ? () => widget.coordinator.dismissSessionOnEscape(session)
                : null,
            child: content,
          )
        : content;

    var positionedChild = panel;
    if (descriptor.layout.draggable) {
      positionedChild = EditorOverlayDragScope(
        onDragDelta: _handleDragDelta,
        child: descriptor.layout.dragHandle == EditorOverlayDragHandle.header
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const EditorOverlayDragHeader(), panel],
              )
            : panel,
      );
    }

    return Positioned(
      left: layout.offset.dx + session.userOffset.dx,
      top: layout.offset.dy + session.userOffset.dy,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: layout.maxWidth,
          maxHeight: layout.maxHeight,
          minWidth: descriptor.layout.minWidth,
          minHeight: descriptor.layout.minHeight,
        ),
        child: positionedChild,
      ),
    );
  }
}

bool _usesExclusiveKeyboard(EditorOverlayDescriptor descriptor) =>
    descriptor.capturesKeyboard ||
    descriptor.keyboardPolicy == EditorOverlayKeyboardPolicy.exclusive;

/// Focus scope для overlay с клавиатурной навигацией и Escape.
final class _OverlayFocusScope extends StatelessWidget {
  const _OverlayFocusScope({required this.child, this.onEscape});

  final Widget child;
  final VoidCallback? onEscape;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (onEscape == null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      onEscape!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    onKeyEvent: _onKeyEvent,
    child: _OverlayFocusBootstrap(child: child),
  );
}

/// Запрашивает фокус после mount overlay.
final class _OverlayFocusBootstrap extends StatefulWidget {
  const _OverlayFocusBootstrap({required this.child});

  final Widget child;

  @override
  State<_OverlayFocusBootstrap> createState() => _OverlayFocusBootstrapState();
}

final class _OverlayFocusBootstrapState extends State<_OverlayFocusBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final scope = FocusScope.of(context);
        if (!scope.hasFocus) scope.requestFocus();
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
