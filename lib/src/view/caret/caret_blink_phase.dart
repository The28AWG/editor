import 'package:editor/src/styling/editor_caret_theme.dart';

/// Вычисляет [t] для [EditorCaretBlinkTheme.appearanceAt] по монотонному времени.
///
/// [elapsed] — время с момента старта; [solidUntil] — конец solid-паузы после
/// последней активности (ввод, движение каретки, IME).
double caretBlinkLerpT({
  required Duration elapsed,
  required Duration solidUntil,
  required EditorCaretBlinkTheme theme,
}) {
  if (!theme.enabled) return 0;
  if (elapsed < solidUntil) return 0;

  final cycle = theme.visibleDuration + theme.hiddenDuration;
  if (cycle <= Duration.zero) return 0;

  final idle = elapsed - solidUntil;
  final pos = Duration(
    microseconds: idle.inMicroseconds % cycle.inMicroseconds,
  );
  return pos < theme.visibleDuration ? 0.0 : 1.0;
}

/// Задержка до следующей смены фазы мигания (для [Timer], не для каждого кадра).
Duration caretBlinkDelayUntilNextPhase({
  required Duration elapsed,
  required Duration solidUntil,
  required EditorCaretBlinkTheme theme,
}) {
  if (!theme.enabled) {
    return const Duration(days: 365);
  }
  if (elapsed < solidUntil) {
    return solidUntil - elapsed;
  }

  final cycle = theme.visibleDuration + theme.hiddenDuration;
  if (cycle <= Duration.zero) {
    return const Duration(days: 365);
  }

  final idle = elapsed - solidUntil;
  final pos = Duration(
    microseconds: idle.inMicroseconds % cycle.inMicroseconds,
  );
  if (pos < theme.visibleDuration) {
    return theme.visibleDuration - pos;
  }
  return cycle - pos;
}
