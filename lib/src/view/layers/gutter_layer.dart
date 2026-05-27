/// Контракт отрисовки gutter (колонка номеров строк).
///
/// Номера строк рисуются непосредственно в [EditorLayersPainter], когда
/// [EditorScrollable.showGutter] равен `true` — отдельного painter-виджета нет.
/// Эта библиотека реэкспортирует [EditorLayersPainter] для документации
/// и необязательного прямого использования в пользовательских scroll-хостах.
///
/// Ширина gutter фиксирована на 48 логических пикселей в [EditorScrollable].
library;

export 'package:editor/src/view/layers/editor_layers_painter.dart'
    show EditorLayersPainter;
