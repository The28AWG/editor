import 'dart:ui';

import 'package:editor/src/styling/editor_caret_theme.dart';

/// Вертикальное размещение текста внутри ячейки строки документа.
///
/// Используется [LineTextMetrics.contentTop] для позиционирования глифов в строке,
/// выше естественной высоты блока шрифта.
enum EditorLineVerticalAlign {
  /// Выровнять текстовый блок по верху ячейки строки.
  top,

  /// Центрировать текстовый блок по вертикали в ячейке строки.
  center,

  /// Выровнять текстовый блок по низу ячейки строки.
  bottom,
}

/// Оформление редактора и базовый стиль текста.
///
/// Центральная палитра для фона, gutter, выделения, каретки, диагностики,
/// inlay и временных подсветок. [lineHeightPx] объединяет [fontSize] и
/// [lineHeight] для макета.
///
/// Готовые пресеты: [EditorTheme.dark] и [EditorTheme.light].
///
/// ```dart
/// const theme = EditorTheme.dark();
/// ```
final class EditorTheme {
  /// Создаёт тему с явно заданными значениями всех полей.
  const EditorTheme({
    required this.backgroundColor,
    required this.currentLineColor,
    required this.defaultColor,
    required this.fontFamily,
    required this.fontSize,
    required this.fontStyle,
    required this.fontWeight,
    required this.lineHeight,
    required this.lineVerticalAlign,
    required this.selectionColor,
    required this.caretColor,
    required this.occurrenceHighlightColor,
    required this.bracketMatchColor,
    required this.bracketMatchActiveColor,
    required this.linkedEditingHighlightColor,
    required this.navigationLinkColor,
    required this.preeditBackgroundColor,
    required this.gutterBackgroundColor,
    required this.gutterTextColor,
    required this.diagnosticErrorColor,
    required this.diagnosticWarningColor,
    required this.diagnosticInfoColor,
    required this.diagnosticHintColor,
    required this.diagnosticErrorInlineColor,
    required this.diagnosticWarningInlineColor,
    required this.diagnosticInfoInlineColor,
    required this.diagnosticHintInlineColor,
    required this.diagnosticErrorLineColor,
    required this.inlayHintTypeColor,
    required this.inlayHintParameterColor,
    required this.inlayHintOtherColor,
    this.regionBlockPaddingX = 1.0,
    this.regionBlockPaddingY = 1.0,
    this.regionBlockBorderWidth = 1.0,
    this.regionBlockCornerRadius = 4.0,
    this.regionBlockBorderColor = const Color(0xFFB0B0B0),
    this.caretBlinkOverride,
  });

  /// Тёмная тема в стиле VS Code Dark+.
  const EditorTheme.dark()
    : backgroundColor = const Color(0xFF1E1E1E),
      currentLineColor = const Color(0xFF2A2A2A),
      defaultColor = const Color(0xFFD4D4D4),
      fontFamily = 'monospace',
      fontSize = 16,
      fontStyle = FontStyle.normal,
      fontWeight = FontWeight.normal,
      lineHeight = 1.2,
      lineVerticalAlign = EditorLineVerticalAlign.center,
      selectionColor = const Color(0x4033B3FF),
      caretColor = const Color(0xFFD4D4D4),
      caretBlinkOverride = null,
      occurrenceHighlightColor = const Color(0x3434B3FF),
      bracketMatchColor = const Color(0xFF3A3A3A),
      bracketMatchActiveColor = const Color(0xFF555555),
      linkedEditingHighlightColor = const Color(0x4034D399),
      navigationLinkColor = const Color(0xFF4EC9B0),
      preeditBackgroundColor = const Color(0x80FFFFFF),
      gutterBackgroundColor = const Color(0xFF252526),
      gutterTextColor = const Color(0xFF858585),
      diagnosticErrorColor = const Color(0xFFF48771),
      diagnosticWarningColor = const Color(0xFFCCA700),
      diagnosticInfoColor = const Color(0xFF75BEFF),
      diagnosticHintColor = const Color(0xFF858585),
      diagnosticErrorInlineColor = const Color(0x99F48771),
      diagnosticWarningInlineColor = const Color(0x99CCA700),
      diagnosticInfoInlineColor = const Color(0x9975BEFF),
      diagnosticHintInlineColor = const Color(0x99858585),
      diagnosticErrorLineColor = const Color(0x22F48771),
      inlayHintTypeColor = const Color(0x99808080),
      inlayHintParameterColor = const Color(0x99808080),
      inlayHintOtherColor = const Color(0x99808080),
      regionBlockPaddingX = 1.0,
      regionBlockPaddingY = 1.0,
      regionBlockBorderWidth = 1.0,
      regionBlockCornerRadius = 4.0,
      regionBlockBorderColor = const Color(0xFFB0B0B0);

  /// Светлая тема в стиле VS Code Light+.
  const EditorTheme.light()
    : backgroundColor = const Color(0xFFFFFFFF),
      currentLineColor = const Color(0xFFF3F3F3),
      defaultColor = const Color(0xFF000000),
      fontFamily = 'monospace',
      fontSize = 16,
      fontStyle = FontStyle.normal,
      fontWeight = FontWeight.normal,
      lineHeight = 1.2,
      lineVerticalAlign = EditorLineVerticalAlign.center,
      selectionColor = const Color(0x400099FF),
      caretColor = const Color(0xFF000000),
      caretBlinkOverride = null,
      occurrenceHighlightColor = const Color(0x340099FF),
      bracketMatchColor = const Color(0xFFE0E0E0),
      bracketMatchActiveColor = const Color(0xFFC8C8C8),
      linkedEditingHighlightColor = const Color(0x40009900),
      navigationLinkColor = const Color(0xFF098658),
      preeditBackgroundColor = const Color(0x80000000),
      gutterBackgroundColor = const Color(0xFFF3F3F3),
      gutterTextColor = const Color(0xFF237893),
      diagnosticErrorColor = const Color(0xFFE51400),
      diagnosticWarningColor = const Color(0xFFBF8803),
      diagnosticInfoColor = const Color(0xFF1A85FF),
      diagnosticHintColor = const Color(0xFF6C6C6C),
      diagnosticErrorInlineColor = const Color(0x99E51400),
      diagnosticWarningInlineColor = const Color(0x99BF8803),
      diagnosticInfoInlineColor = const Color(0x991A85FF),
      diagnosticHintInlineColor = const Color(0x996C6C6C),
      diagnosticErrorLineColor = const Color(0x22E51400),
      inlayHintTypeColor = const Color(0x99757575),
      inlayHintParameterColor = const Color(0x99757575),
      inlayHintOtherColor = const Color(0x99757575),
      regionBlockPaddingX = 1.0,
      regionBlockPaddingY = 1.0,
      regionBlockBorderWidth = 1.0,
      regionBlockCornerRadius = 4.0,
      regionBlockBorderColor = const Color(0xFF606060);

  /// Переопределение [caretBlink]; если `null` — из [caretColor].
  final EditorCaretBlinkTheme? caretBlinkOverride;

  /// Фон поверхности редактора.
  final Color backgroundColor;

  /// Фон строки, содержащей основную каретку.
  final Color currentLineColor;

  /// Цвет текста по умолчанию для нестилизованного текста ([BaseStyleLayer]).
  final Color defaultColor;

  /// Основное моноширинное семейство шрифта.
  final String fontFamily;

  /// Базовый размер шрифта в логических пикселях.
  final double fontSize;

  /// Базовый стиль шрифта (обычный или курсив).
  final FontStyle fontStyle;

  /// Базовая насыщенность шрифта.
  final FontWeight fontWeight;

  /// Множитель высоты строки, применяемый к [fontSize].
  final double lineHeight;

  /// Вертикальное выравнивание текста в каждой ячейке строки.
  final EditorLineVerticalAlign lineVerticalAlign;

  /// Заливка подсветки выделения (обычно полупрозрачная).
  final Color selectionColor;

  /// Цвет обводки каретки (видимая фаза мигания).
  ///
  /// Для полной настройки мигания используйте [caretBlinkOverride].
  final Color caretColor;

  /// Мигание и интерполируемый вид каретки ([EditorCaretAppearance.lerp]).
  EditorCaretBlinkTheme get caretBlink =>
      caretBlinkOverride ?? EditorCaretBlinkTheme.standard(caretColor);

  /// Фон для span'ов [HighlightKind.occurrence].
  final Color occurrenceHighlightColor;

  /// Фон для неактивной скобки в совпавшей паре.
  final Color bracketMatchColor;

  /// Фон для скобки под кареткой.
  final Color bracketMatchActiveColor;

  /// Фон для span'ов [HighlightKind.linkedEditing].
  final Color linkedEditingHighlightColor;

  /// Цвет подчёркивания интерактивной ссылки (Ctrl+hover).
  final Color navigationLinkColor;

  /// Фон IME-композиции preedit.
  final Color preeditBackgroundColor;

  /// Фон gutter (номеров строк).
  final Color gutterBackgroundColor;

  /// Цвет текста gutter (номеров строк).
  final Color gutterTextColor;

  /// Цвет волнистой линии / маркера диагностики для ошибок.
  final Color diagnosticErrorColor;

  /// Цвет диагностики для предупреждений.
  final Color diagnosticWarningColor;

  /// Цвет диагностики для информации.
  final Color diagnosticInfoColor;

  /// Цвет диагностики для подсказок.
  final Color diagnosticHintColor;

  /// Оттенок inline-подчёркивания для диагностики ошибок.
  final Color diagnosticErrorInlineColor;

  /// Оттенок inline-подчёркивания для диагностики предупреждений.
  final Color diagnosticWarningInlineColor;

  /// Оттенок inline-подчёркивания для информационной диагностики.
  final Color diagnosticInfoInlineColor;

  /// Оттенок inline-подчёркивания для диагностики-подсказок.
  final Color diagnosticHintInlineColor;

  /// Оттенок фона всей строки для диагностики ошибок.
  final Color diagnosticErrorLineColor;

  /// Цвет текста inlay-подсказки для type hints.
  final Color inlayHintTypeColor;

  /// Цвет текста inlay-подсказки для parameter hints.
  final Color inlayHintParameterColor;

  /// Цвет текста inlay-подсказки для прочих видов подсказок.
  final Color inlayHintOtherColor;

  /// Внешний отступ блока-рамки по X (в логических пикселях).
  ///
  /// Увеличивает контур наружу по горизонтали.
  final double regionBlockPaddingX;

  /// Внутренний отступ блока-рамки по Y (в логических пикселях).
  ///
  /// Применяется как inset внутрь высоты визуальной строки, чтобы рамки не
  /// пересекались между строками из-за вертикального padding'а.
  final double regionBlockPaddingY;

  /// Толщина рамки блока-рамки (в логических пикселях).
  ///
  /// Рамка рисуется внутрь фигуры (fill-полосой), поэтому не «вылезает» наружу.
  final double regionBlockBorderWidth;

  /// Радиус скругления углов рамки блока-рамки (в логических пикселях).
  final double regionBlockCornerRadius;

  /// Цвет рамки блока-рамки по умолчанию.
  ///
  /// Используется, когда у [EditorRegionBlock] не задан `borderColor`.
  final Color regionBlockBorderColor;

  /// Копия с подстановкой полей.
  EditorTheme copyWith({
    Color? backgroundColor,
    Color? currentLineColor,
    Color? defaultColor,
    String? fontFamily,
    double? fontSize,
    FontStyle? fontStyle,
    FontWeight? fontWeight,
    double? lineHeight,
    EditorLineVerticalAlign? lineVerticalAlign,
    Color? selectionColor,
    Color? caretColor,
    EditorCaretBlinkTheme? caretBlinkOverride,
    Color? occurrenceHighlightColor,
    Color? bracketMatchColor,
    Color? bracketMatchActiveColor,
    Color? linkedEditingHighlightColor,
    Color? navigationLinkColor,
    Color? preeditBackgroundColor,
    Color? gutterBackgroundColor,
    Color? gutterTextColor,
    Color? diagnosticErrorColor,
    Color? diagnosticWarningColor,
    Color? diagnosticInfoColor,
    Color? diagnosticHintColor,
    Color? diagnosticErrorInlineColor,
    Color? diagnosticWarningInlineColor,
    Color? diagnosticInfoInlineColor,
    Color? diagnosticHintInlineColor,
    Color? diagnosticErrorLineColor,
    Color? inlayHintTypeColor,
    Color? inlayHintParameterColor,
    Color? inlayHintOtherColor,
    double? regionBlockPaddingX,
    double? regionBlockPaddingY,
    double? regionBlockBorderWidth,
    double? regionBlockCornerRadius,
    Color? regionBlockBorderColor,
  }) => EditorTheme(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    currentLineColor: currentLineColor ?? this.currentLineColor,
    defaultColor: defaultColor ?? this.defaultColor,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    fontStyle: fontStyle ?? this.fontStyle,
    fontWeight: fontWeight ?? this.fontWeight,
    lineHeight: lineHeight ?? this.lineHeight,
    lineVerticalAlign: lineVerticalAlign ?? this.lineVerticalAlign,
    selectionColor: selectionColor ?? this.selectionColor,
    caretColor: caretColor ?? this.caretColor,
    caretBlinkOverride: caretBlinkOverride ?? this.caretBlinkOverride,
    occurrenceHighlightColor:
        occurrenceHighlightColor ?? this.occurrenceHighlightColor,
    bracketMatchColor: bracketMatchColor ?? this.bracketMatchColor,
    bracketMatchActiveColor:
        bracketMatchActiveColor ?? this.bracketMatchActiveColor,
    linkedEditingHighlightColor:
        linkedEditingHighlightColor ?? this.linkedEditingHighlightColor,
    navigationLinkColor: navigationLinkColor ?? this.navigationLinkColor,
    preeditBackgroundColor:
        preeditBackgroundColor ?? this.preeditBackgroundColor,
    gutterBackgroundColor: gutterBackgroundColor ?? this.gutterBackgroundColor,
    gutterTextColor: gutterTextColor ?? this.gutterTextColor,
    diagnosticErrorColor: diagnosticErrorColor ?? this.diagnosticErrorColor,
    diagnosticWarningColor:
        diagnosticWarningColor ?? this.diagnosticWarningColor,
    diagnosticInfoColor: diagnosticInfoColor ?? this.diagnosticInfoColor,
    diagnosticHintColor: diagnosticHintColor ?? this.diagnosticHintColor,
    diagnosticErrorInlineColor:
        diagnosticErrorInlineColor ?? this.diagnosticErrorInlineColor,
    diagnosticWarningInlineColor:
        diagnosticWarningInlineColor ?? this.diagnosticWarningInlineColor,
    diagnosticInfoInlineColor:
        diagnosticInfoInlineColor ?? this.diagnosticInfoInlineColor,
    diagnosticHintInlineColor:
        diagnosticHintInlineColor ?? this.diagnosticHintInlineColor,
    diagnosticErrorLineColor:
        diagnosticErrorLineColor ?? this.diagnosticErrorLineColor,
    inlayHintTypeColor: inlayHintTypeColor ?? this.inlayHintTypeColor,
    inlayHintParameterColor:
        inlayHintParameterColor ?? this.inlayHintParameterColor,
    inlayHintOtherColor: inlayHintOtherColor ?? this.inlayHintOtherColor,
    regionBlockPaddingX: regionBlockPaddingX ?? this.regionBlockPaddingX,
    regionBlockPaddingY: regionBlockPaddingY ?? this.regionBlockPaddingY,
    regionBlockBorderWidth:
        regionBlockBorderWidth ?? this.regionBlockBorderWidth,
    regionBlockCornerRadius:
        regionBlockCornerRadius ?? this.regionBlockCornerRadius,
    regionBlockBorderColor:
        regionBlockBorderColor ?? this.regionBlockBorderColor,
  );

  /// Высота строки в пикселях (`fontSize * lineHeight`).
  double get lineHeightPx => fontSize * lineHeight;
}
