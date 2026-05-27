import 'dart:ui';

import 'package:editor/src/model/position.dart';

/// Частичные атрибуты стиля для полуоткрытого диапазона документа.
///
/// Поля `null` означают «не переопределять» при объединении слоёв [StyleResolver].
/// Ненулевые поля заменяют накопленное значение для перекрывающихся сегментов.
/// Span'ы с более высоким [priority] побеждают, когда несколько span'ов покрывают один code unit.
///
/// ```dart
/// StyleSpan(
///   range: Range(0, 5),
///   color: Colors.blue,
///   fontWeight: FontWeight.bold,
///   priority: 50,
/// )
/// ```
final class StyleSpan {
  /// Создаёт стилевой span с опциональными переопределениями атрибутов.
  const StyleSpan({
    required this.range,
    this.color,
    this.backgroundColor,
    this.fontWeight,
    this.fontStyle,
    this.underline = false,
    this.wavyUnderline = false,
    this.underlineColor,
    this.priority = 0,
  });

  /// Полуоткрытый диапазон документа `[start, end)`, к которому применяется этот span.
  final Range range;

  /// Переопределение цвета текста или `null` для наследования.
  final Color? color;

  /// Переопределение фона или `null` для наследования.
  final Color? backgroundColor;

  /// Переопределение насыщенности шрифта или `null` для наследования.
  final FontWeight? fontWeight;

  /// Переопределение стиля шрифта или `null` для наследования.
  final FontStyle? fontStyle;

  /// Рисовать ли прямое подчёркивание.
  final bool underline;

  /// Рисовать ли волнистое подчёркивание.
  final bool wavyUnderline;

  /// Переопределение цвета подчёркивания или `null` для значения по умолчанию.
  final Color? underlineColor;

  /// Приоритет объединения; большие значения переопределяют меньшие для того же смещения.
  final int priority;
}
