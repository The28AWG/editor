/// Поведение редактора, доступное пользователю; передаётся командам и слою представления.
///
/// ## Поля
///
/// - [tabSize] + [insertSpaces]: [tabText] — либо пробелы, либо литеральная табуляция
/// - [wordWrap]: если true, [LineLayout] переносит визуальные строки по ширине viewport
///
/// Подключается из [EditorController.config] к [CommandRegistry] и layout.
final class EditorConfig {
  const EditorConfig({
    this.tabSize = 2,
    this.insertSpaces = true,
    this.wordWrap = false,
  });

  /// Число пробелов при [insertSpaces] == true.
  final int tabSize;

  /// `true` — табуляция как пробелы; `false` — символ U+0009.
  final bool insertSpaces;

  /// Если false, длинные строки расширяются горизонтально (с горизонтальной прокруткой).
  final bool wordWrap;

  /// Строка, вставляемая [InsertTabCommand] (пробелы или `\t`).
  String get tabText => insertSpaces ? ' ' * tabSize : '\t';
}
