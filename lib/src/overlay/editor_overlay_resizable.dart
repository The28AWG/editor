import 'package:editor/src/overlay/editor_overlay_layout.dart';
import 'package:flutter/material.dart';

/// Оболочка с изменяемым размером для documentation pane и подобных панелей.
final class EditorResizablePanel extends StatefulWidget {
  const EditorResizablePanel({
    required this.child,
    required this.initialSize,
    required this.onResize,
    this.minSize = const Size(160, 120),
    this.maxSize,
    this.handle = EditorOverlayResizeHandle.bottomRight,
    super.key,
  });

  final Widget child;
  final Size initialSize;
  final ValueChanged<Size> onResize;
  final Size minSize;
  final Size? maxSize;
  final EditorOverlayResizeHandle handle;

  @override
  State<EditorResizablePanel> createState() => _EditorResizablePanelState();
}

final class _EditorResizablePanelState extends State<EditorResizablePanel> {
  late Size _size = widget.initialSize;
  Offset? _dragStart;
  Size? _sizeAtDragStart;

  Size _clamp(Size value) {
    var w = value.width.clamp(widget.minSize.width, double.infinity);
    var h = value.height.clamp(widget.minSize.height, double.infinity);
    final max = widget.maxSize;
    if (max != null) {
      w = w.clamp(0, max.width);
      h = h.clamp(0, max.height);
    }
    return Size(w, h);
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.globalPosition;
    _sizeAtDragStart = _size;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final start = _dragStart;
    final base = _sizeAtDragStart;
    if (start == null || base == null) return;
    final delta = details.globalPosition - start;
    final next = switch (widget.handle) {
      EditorOverlayResizeHandle.bottomRight => Size(
        base.width + delta.dx,
        base.height + delta.dy,
      ),
      EditorOverlayResizeHandle.bottom => Size(
        base.width,
        base.height + delta.dy,
      ),
      EditorOverlayResizeHandle.right => Size(
        base.width + delta.dx,
        base.height,
      ),
    };
    final clamped = _clamp(next);
    if (clamped == _size) return;
    setState(() => _size = clamped);
    widget.onResize(clamped);
  }

  void _onPanEnd(DragEndDetails details) {
    _dragStart = null;
    _sizeAtDragStart = null;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _size.width,
    height: _size.height,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          right: 0,
          bottom: 0,
          child: _ResizeHandle(
            handle: widget.handle,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
          ),
        ),
      ],
    ),
  );
}

final class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.handle,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final EditorOverlayResizeHandle handle;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    final cursor = switch (handle) {
      EditorOverlayResizeHandle.bottomRight =>
        SystemMouseCursors.resizeDownRight,
      EditorOverlayResizeHandle.bottom => SystemMouseCursors.resizeUpDown,
      EditorOverlayResizeHandle.right => SystemMouseCursors.resizeLeftRight,
    };
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        child: const SizedBox(width: 16, height: 16),
      ),
    );
  }
}
