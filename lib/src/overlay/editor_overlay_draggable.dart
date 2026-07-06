import 'package:flutter/material.dart';

/// Колбэки перетаскивания overlay по глобальной позиции указателя.
final class EditorOverlayDragHandlers {
  const EditorOverlayDragHandlers({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;
}

/// Предоставляет [EditorOverlayDragHandlers] потомкам draggable overlay.
final class EditorOverlayDragScope extends InheritedWidget {
  const EditorOverlayDragScope({
    required this.handlers,
    required super.child,
    super.key,
  });

  final EditorOverlayDragHandlers handlers;

  static EditorOverlayDragHandlers? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<EditorOverlayDragScope>();
    return scope?.handlers;
  }

  @override
  bool updateShouldNotify(EditorOverlayDragScope oldWidget) =>
      handlers != oldWidget.handlers;
}

/// Drag-зона в [builder] при [EditorOverlayDragHandle.custom].
final class EditorOverlayPanelDragHandle extends StatelessWidget {
  const EditorOverlayPanelDragHandle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final handlers = EditorOverlayDragScope.maybeOf(context);
    if (handlers == null) return child;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => handlers.onStart(details.globalPosition),
        onPanUpdate: (details) => handlers.onUpdate(details.globalPosition),
        onPanEnd: (_) => handlers.onEnd(),
        onPanCancel: handlers.onEnd,
        child: child,
      ),
    );
  }
}

/// Стандартная полоска перетаскивания над содержимым панели.
final class EditorOverlayDragHeader extends StatelessWidget {
  const EditorOverlayDragHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final handlers = EditorOverlayDragScope.maybeOf(context);
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: handlers == null
          ? null
          : (details) => handlers.onStart(details.globalPosition),
      onPanUpdate: handlers == null
          ? null
          : (details) => handlers.onUpdate(details.globalPosition),
      onPanEnd: handlers == null ? null : (_) => handlers.onEnd(),
      onPanCancel: handlers?.onEnd,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: SizedBox(
            height: 28,
            child: Center(
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
