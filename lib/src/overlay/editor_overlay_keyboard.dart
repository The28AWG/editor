import 'package:flutter/widgets.dart';

/// Политика клавиатуры overlay относительно [EditorInputHandler].
enum EditorOverlayKeyboardPolicy {
  /// Редактор получает все клавиши (Escape обрабатывается глобально в [EditorScrollable]).
  passive,

  /// Редактор сохраняет фокус; [EditorOverlayDescriptor.onKeyEvent] перехватывает отдельные клавиши.
  cooperative,

  /// Overlay забирает фокус; ввод редактора блокируется.
  exclusive,
}

/// Обработчик клавиш для [EditorOverlayKeyboardPolicy.cooperative].
typedef EditorOverlayKeyEventCallback = KeyEventResult Function(KeyEvent event);
