import 'package:editor/src/overlay/editor_overlay_anchor.dart';
import 'package:editor/src/overlay/editor_overlay_coordinator.dart';
import 'package:editor/src/overlay/editor_overlay_dismiss.dart';
import 'package:editor/src/overlay/editor_overlay_keyboard.dart';
import 'package:editor/src/overlay/editor_overlay_layout.dart';
import 'package:flutter/widgets.dart';

/// Описание одного overlay для [EditorOverlayCoordinator.show].
final class EditorOverlayDescriptor {
  const EditorOverlayDescriptor({
    required this.id,
    required this.builder,
    required this.anchor,
    this.kind = EditorOverlayKind.custom,
    this.layout = const EditorOverlayLayoutPolicy(),
    this.priority = 0,
    this.capturesKeyboard = false,
    this.keyboardPolicy = EditorOverlayKeyboardPolicy.passive,
    this.onKeyEvent,
    this.dismissPolicy = const EditorOverlayDismissPolicy(),
    this.children = const [],
    this.parentId,
  });

  /// Уникальный идентификатор сессии; повторный [show] с тем же id заменяет overlay.
  final String id;

  /// Строит содержимое панели; [session] — для hide/resize и доступа к якорю.
  final Widget Function(BuildContext context, EditorOverlaySession session)
  builder;

  final EditorOverlayAnchor anchor;
  final EditorOverlayKind kind;
  final EditorOverlayLayoutPolicy layout;
  final int priority;

  /// Устаревший флаг: эквивалент [EditorOverlayKeyboardPolicy.exclusive].
  final bool capturesKeyboard;

  /// Как overlay делит клавиатуру с редактором.
  final EditorOverlayKeyboardPolicy keyboardPolicy;

  /// Перехват отдельных клавиш при [EditorOverlayKeyboardPolicy.cooperative].
  final EditorOverlayKeyEventCallback? onKeyEvent;

  final EditorOverlayDismissPolicy dismissPolicy;

  /// Вложенные панели (например, documentation справа от completion list).
  final List<EditorOverlayDescriptor> children;

  /// Если задан, панель позиционируется относительно родителя с этим [id].
  final String? parentId;
}

/// Живое состояние одной сессии overlay.
final class EditorOverlaySession {
  EditorOverlaySession({
    required this.id,
    required this.descriptor,
    required this._coordinator,
  });

  final String id;
  final EditorOverlayDescriptor descriptor;
  final EditorOverlayCoordinator _coordinator;

  /// Якорь в локальных координатах viewport (обновляется при track-on-scroll).
  Rect? anchorRect;

  /// Измеренный размер содержимого.
  Size? measuredSize;

  /// Пользовательский размер после resize.
  Size? userSize;

  /// Пользовательское смещение после drag (добавляется к рассчитанной позиции).
  Offset userOffset = Offset.zero;

  /// Эффективный размер для layout дочерних панелей.
  Size? get effectiveSize => userSize ?? measuredSize;

  void hide() => _coordinator.hide(id);

  void resize(Size size) => _coordinator.resize(id, size);

  /// Задаёт смещение панели относительно автоматически рассчитанной позиции.
  void move(Offset offset) => _coordinator.move(id, offset);
}
