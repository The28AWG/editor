import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Автопрокрутка viewport при выделении указателем у краёв видимой области.
///
/// Пока указатель в «мертвой зоне» [edgeSize] у верхнего/нижнего/левого/правого края,
/// [Ticker] вызывает [onTick] с delta, пропорциональной глубине в зоне (квадратичная
/// кривая — медленный старт у границы, ускорение к краю).
final class SelectionDragAutoscroll {
  SelectionDragAutoscroll({
    required this.vsync,
    required this.viewportHeight,
    required this.viewportWidth,
    required this.edgeSize,
    required this.maxSpeedPxPerSec,
    required this.onTick,
  });

  /// Источник [Ticker] (обычно [SingleTickerProviderStateMixin] State).
  final TickerProvider vsync;

  /// Текущая высота viewport в логических пикселях (может меняться при layout).
  final double Function() viewportHeight;

  /// Текущая ширина viewport; `0` отключает горизонтальный autoscroll.
  final double Function() viewportWidth;

  /// Ширина «мертвой зоны» у каждого края, где начинается прокрутка.
  final double edgeSize;

  /// Максимальная скорость прокрутки (px/s) при указателе на самом краю.
  final double maxSpeedPxPerSec;

  /// Вызывается каждый кадр: `(deltaY, deltaX)` в логических пикселях.
  final void Function(double deltaY, double deltaX) onTick;

  Ticker? _ticker;
  ui.Offset? _pointerInViewport;
  Duration _lastElapsed = Duration.zero;

  bool get isRunning => _ticker?.isActive ?? false;

  void updatePointerInViewport(ui.Offset? localInViewport) {
    _pointerInViewport = localInViewport;
    if (localInViewport == null) {
      _stop();
      return;
    }
    // Вне мёртвых зон тикер не нужен — экономим кадры.
    if (_scrollDeltaForPointer(localInViewport) == Offset.zero) {
      _stop();
    } else {
      _ensureTicker();
    }
  }

  void dispose() {
    _ticker?.dispose();
    _ticker = null;
  }

  void _ensureTicker() {
    _ticker ??= vsync.createTicker(_onTick);
    if (_ticker!.isActive) return;
    _lastElapsed = Duration.zero;
    _ticker!.start();
  }

  /// Останавливает тикер без [Ticker.dispose] — [SingleTickerProviderStateMixin]
  /// допускает только одно создание ticker за жизнь State.
  void _stop() {
    _ticker?.stop();
    _lastElapsed = Duration.zero;
  }

  void _onTick(Duration elapsed) {
    final pointer = _pointerInViewport;
    if (pointer == null) {
      _stop();
      return;
    }
    final delta = _scrollDeltaForPointer(pointer);
    if (delta == Offset.zero) {
      _stop();
      return;
    }

    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    if (dt <= Duration.zero) return;

    final sec = dt.inMicroseconds / 1000000.0;
    onTick(delta.dy * sec, delta.dx * sec);
  }

  /// Единичные скорости по осям (−1…1), умножаются на [maxSpeedPxPerSec] и dt.
  Offset _scrollDeltaForPointer(ui.Offset local) {
    final h = viewportHeight();
    final w = viewportWidth();
    if (h <= 0 && w <= 0) return Offset.zero;

    var sy = 0.0;
    var sx = 0.0;

    if (h > 0) {
      if (local.dy < edgeSize) {
        sy = -_speedFactor(edgeSize - local.dy, edgeSize);
      } else if (local.dy > h - edgeSize) {
        sy = _speedFactor(local.dy - (h - edgeSize), edgeSize);
      }
    }

    if (w > 0) {
      if (local.dx < edgeSize) {
        sx = -_speedFactor(edgeSize - local.dx, edgeSize);
      } else if (local.dx > w - edgeSize) {
        sx = _speedFactor(local.dx - (w - edgeSize), edgeSize);
      }
    }

    if (sy == 0 && sx == 0) return Offset.zero;
    return Offset(sx * maxSpeedPxPerSec, sy * maxSpeedPxPerSec);
  }

  /// t² — плавное нарастание скорости от 0 у внутренней границы зоны до 1 у края.
  double _speedFactor(double depth, double zone) {
    if (zone <= 0) return 1;
    final t = (depth / zone).clamp(0.0, 1.0);
    return t * t;
  }
}
