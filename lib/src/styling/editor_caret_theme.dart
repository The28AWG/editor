import 'dart:ui' show lerpDouble;

import 'package:flutter/painting.dart';

/// Внешний вид каретки: цвет и толщина штриха.
final class EditorCaretAppearance {
  /// Создаёт описание отрисовки каретки.
  const EditorCaretAppearance({
    required this.color,
    this.strokeWidth = 2,
  });

  /// Линейная интерполяция между [a] и [b] по [t] (0 — [a], 1 — [b]).
  factory EditorCaretAppearance.lerp(
    EditorCaretAppearance a,
    EditorCaretAppearance b,
    double t,
  ) {
    final clamped = t.clamp(0.0, 1.0);
    return EditorCaretAppearance(
      color: Color.lerp(a.color, b.color, clamped)!,
      strokeWidth: lerpDouble(a.strokeWidth, b.strokeWidth, clamped)!,
    );
  }

  /// Цвет линии каретки.
  final Color color;

  /// Толщина вертикальной линии в логических пикселях.
  final double strokeWidth;

  /// `false`, если каретку рисовать не нужно (нулевая альфа или ширина).
  bool get isEffectivelyVisible => strokeWidth > 0 && color.a > 0;

  /// Копия с подстановкой полей.
  EditorCaretAppearance copyWith({Color? color, double? strokeWidth}) =>
      EditorCaretAppearance(
        color: color ?? this.color,
        strokeWidth: strokeWidth ?? this.strokeWidth,
      );

  @override
  bool operator ==(Object other) =>
      other is EditorCaretAppearance &&
      other.color == color &&
      other.strokeWidth == strokeWidth;

  @override
  int get hashCode => Object.hash(color, strokeWidth);
}

/// Тема мигания каретки: конечные состояния, длительности и [appearanceAt].
///
/// [visible] и [hidden] интерполируются через [EditorCaretAppearance.lerp].
/// По умолчанию «скрытое» состояние — полностью прозрачный цвет при той же толщине.
final class EditorCaretBlinkTheme {
  /// Тема мигания с VS Code-подобными интервалами по умолчанию.
  const EditorCaretBlinkTheme({
    this.enabled = true,
    this.visible = const EditorCaretAppearance(color: Color(0xFFD4D4D4)),
    this.hidden = const EditorCaretAppearance(
      color: Color(0x00D4D4D4),
      strokeWidth: 2,
    ),
    this.visibleDuration = const Duration(milliseconds: 530),
    this.hiddenDuration = const Duration(milliseconds: 530),
    this.solidDuration = const Duration(milliseconds: 500),
  });

  /// Тема с видимым цветом [visibleColor] и прозрачным скрытым состоянием.
  factory EditorCaretBlinkTheme.standard(Color visibleColor) =>
      EditorCaretBlinkTheme(
        visible: EditorCaretAppearance(color: visibleColor),
        hidden: EditorCaretAppearance(
          color: visibleColor.withValues(alpha: 0),
        ),
      );

  /// Отключить мигание, оставив только [visible].
  const EditorCaretBlinkTheme.disabled({
    EditorCaretAppearance visible = const EditorCaretAppearance(
      color: Color(0xFFD4D4D4),
    ),
  }) : enabled = false,
       visible = visible,
       hidden = visible,
       visibleDuration = Duration.zero,
       hiddenDuration = Duration.zero,
       solidDuration = Duration.zero;

  /// Включено ли мигание после [solidDuration] бездействия.
  final bool enabled;

  /// Внешний вид в фазе «видима» (ввод, solid-пауза, начало цикла).
  final EditorCaretAppearance visible;

  /// Внешний вид в фазе «скрыта».
  final EditorCaretAppearance hidden;

  /// Длительность фазы «видима» в цикле мигания.
  final Duration visibleDuration;

  /// Длительность фазы «скрыта» в цикле мигания.
  final Duration hiddenDuration;

  /// После ввода/движения каретки каретка остаётся в [visible] не менее этого времени.
  final Duration solidDuration;

  /// Интерполированный вид при [t] ∈ [0, 1] (0 — [visible], 1 — [hidden]).
  EditorCaretAppearance appearanceAt(double t) =>
      EditorCaretAppearance.lerp(visible, hidden, t);

  @override
  bool operator ==(Object other) =>
      other is EditorCaretBlinkTheme &&
      other.enabled == enabled &&
      other.visible == visible &&
      other.hidden == hidden &&
      other.visibleDuration == visibleDuration &&
      other.hiddenDuration == hiddenDuration &&
      other.solidDuration == solidDuration;

  @override
  int get hashCode => Object.hash(
    enabled,
    visible,
    hidden,
    visibleDuration,
    hiddenDuration,
    solidDuration,
  );
}
