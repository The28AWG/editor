/// Эфемерные категории подсветки, связанные с кареткой (рисуются в [TransientStyleLayer]).
///
/// Эти виды сопоставляются с цветами фона [EditorTheme] при преобразовании в
/// [StyleSpan]. Они не сохраняются в модели документа.
///
/// Все категории: поиск совпадений ограничен видимым viewport, но spans,
/// попадающие на экран, подсвечиваются (см. [caretHighlightsFor]).
enum HighlightKind {
  /// Вхождения символов (`textDocument/documentHighlight` или слово у каретки).
  occurrence,

  /// Совпадающая скобка (не под кареткой).
  bracket,

  /// Скобка под кареткой.
  bracketActive,

  /// Связанные диапазоны редактирования (`textDocument/linkedEditingRange`).
  linkedEditing,
}
