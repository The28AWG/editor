import 'dart:async';

import 'package:editor/src/styling/editor_caret_theme.dart';
import 'package:editor/src/view/caret/caret_blink_phase.dart';
import 'package:flutter/foundation.dart';

/// Управляет фазой мигания каретки и уведомляет слушателей для [markNeedsPaint].
///
/// Перепланирует [Timer] только на границах фаз (solid / visible / hidden), без
/// покадрового [Ticker].
final class CaretBlinkController extends ChangeNotifier {
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();

  var _focused = false;
  var _hasCollapsedCaret = false;
  var _compositionActive = false;
  var _lerpT = 0.0;
  Duration _solidUntil = Duration.zero;

  /// 0 — [EditorCaretBlinkTheme.visible], 1 — [hidden].
  double get lerpT => _lerpT;

  /// Рисовать ли каретку (фокус и хотя бы одна свёрнутая позиция).
  bool get shouldPaintCaret => _focused && _hasCollapsedCaret;

  /// Текущий вид каретки для [theme] с учётом [lerpT].
  EditorCaretAppearance appearanceFor(EditorCaretBlinkTheme theme) =>
      theme.appearanceAt(_lerpT);

  Duration get _elapsed =>
      _clock.isRunning ? _clock.elapsed : Duration.zero;

  /// Синхронизирует фокус, выделение, IME; при [recordActivity] продлевает solid-паузу.
  void syncWithCachedTheme({
    required bool focused,
    required bool hasCollapsedCaret,
    required bool compositionActive,
    required EditorCaretBlinkTheme theme,
    bool recordActivity = false,
  }) {
    _focused = focused;
    _hasCollapsedCaret = hasCollapsedCaret;
    _compositionActive = compositionActive;

    if (recordActivity || compositionActive) {
      _lerpT = 0;
      if (!_clock.isRunning) _clock.start();
      _solidUntil = _elapsed + theme.solidDuration;
    } else if (focused && hasCollapsedCaret && !_clock.isRunning) {
      _clock.start();
    }

    if (!focused || !hasCollapsedCaret) {
      _cancelTimer();
      if (!focused) notifyListeners();
      return;
    }

    if (compositionActive) {
      _cancelTimer();
      if (_lerpT != 0) {
        _lerpT = 0;
        notifyListeners();
      }
      return;
    }

    _applyPhase(theme);
    _scheduleNext(theme);
  }

  void _applyPhase(EditorCaretBlinkTheme theme) {
    final next = caretBlinkLerpT(
      elapsed: _elapsed,
      solidUntil: _solidUntil,
      theme: theme,
    );
    if (next == _lerpT) return;
    _lerpT = next;
    notifyListeners();
  }

  void _scheduleNext(EditorCaretBlinkTheme theme) {
    _cancelTimer();
    if (!_focused || !_hasCollapsedCaret || _compositionActive) return;
    if (!theme.enabled) return;

    final delay = caretBlinkDelayUntilNextPhase(
      elapsed: _elapsed,
      solidUntil: _solidUntil,
      theme: theme,
    );
    if (delay <= Duration.zero) {
      _onTimer(theme);
      return;
    }
    _timer = Timer(delay, () => _onTimer(theme));
  }

  void _onTimer(EditorCaretBlinkTheme theme) {
    if (!_focused || !_hasCollapsedCaret || _compositionActive) return;
    _applyPhase(theme);
    _scheduleNext(theme);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    _clock.stop();
    super.dispose();
  }
}
