import 'package:flutter/material.dart';

/// Предоставляет [onDragDelta] потомкам draggable overlay (см. [EditorOverlayPanelDragHandle]).
final class EditorOverlayDragScope extends InheritedWidget {
  const EditorOverlayDragScope({
    required this.onDragDelta,
    required super.child,
    super.key,
  });

  final ValueChanged<Offset> onDragDelta;

  static ValueChanged<Offset>? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<EditorOverlayDragScope>();
    return scope?.onDragDelta;
  }

  @override
  bool updateShouldNotify(EditorOverlayDragScope oldWidget) =>
      onDragDelta != oldWidget.onDragDelta;
}

/// Drag-зона в [builder] при [EditorOverlayDragHandle.custom].
final class EditorOverlayPanelDragHandle extends StatelessWidget {
  const EditorOverlayPanelDragHandle({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onDragDelta = EditorOverlayDragScope.maybeOf(context);
    if (onDragDelta == null) return child;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDragDelta(details.delta),
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
    final onDragDelta = EditorOverlayDragScope.maybeOf(context);
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onDragDelta == null
          ? null
          : (details) => onDragDelta(details.delta),
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
