import 'dart:ui';

/// Полностью разрешённый стиль текстового прогона, готовый для [TextPainter] или отрисовки.
///
/// В отличие от [StyleSpan], каждое поле конкретно (без nullable переопределений).
/// Создаётся [StyleResolver] при объединении [StyleLayer].
final class ResolvedStyle {
  /// Создаёт разрешённый стиль со всеми атрибутами отрисовки.
  const ResolvedStyle({
    required this.color,
    required this.backgroundColor,
    required this.fontWeight,
    required this.fontStyle,
    required this.underline,
    this.wavyUnderline = false,
    this.underlineColor,
    required this.fontSize,
    required this.fontFamily,
  });

  /// Цвет текста переднего плана.
  final Color color;

  /// Заливка фона за прогоном (может быть прозрачной).
  final Color backgroundColor;

  /// Насыщенность шрифта для этого прогона.
  final FontWeight fontWeight;

  /// Стиль шрифта (обычный или курсив).
  final FontStyle fontStyle;

  /// Рисуется ли прямое подчёркивание.
  final bool underline;

  /// Рисуется ли волнистое подчёркивание (например, диагностика).
  final bool wavyUnderline;

  /// Опциональный цвет штриха подчёркивания; при null при отрисовке используется цвет текста.
  final Color? underlineColor;

  /// Размер шрифта в логических пикселях.
  final double fontSize;

  /// Имя семейства шрифта.
  final String fontFamily;
}
