/// Категория overlay для разрешения конфликтов и группового скрытия.
enum EditorOverlayKind {
  menu,
  completion,
  hover,
  signature,
  codeAction,
  sticky,
  custom,
}

/// Правила автоматического скрытия и поведения при событиях редактора.
final class EditorOverlayDismissPolicy {
  const EditorOverlayDismissPolicy({
    this.outsidePointerDown = true,
    this.escape = true,
    this.documentChange = true,
    this.selectionChange = false,
    this.scroll = true,
    this.trackAnchorOnScroll = false,
    this.supersedesLowerPriority = true,
    this.exclusiveWithinKind = true,
  });

  /// Закрывать по клику/тапу вне панели (через прозрачный scrim).
  final bool outsidePointerDown;

  /// Закрывать по Escape (работает и без [EditorOverlayDescriptor.capturesKeyboard]).
  final bool escape;

  /// Закрывать при изменении текста документа.
  final bool documentChange;

  /// Закрывать при смене выделения/каретки.
  final bool selectionChange;

  /// Закрывать при прокрутке viewport.
  final bool scroll;

  /// Пересчитывать якорь при прокрутке вместо закрытия ([scroll] должно быть `false`).
  final bool trackAnchorOnScroll;

  /// Скрывать overlay с меньшим [EditorOverlayDescriptor.priority] при показе нового.
  final bool supersedesLowerPriority;

  /// Скрывать другие overlay того же [EditorOverlayDescriptor.kind].
  final bool exclusiveWithinKind;
}
