import 'dart:ui';

import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/styling/editor_theme.dart';

/// Возвращает цвет темы для inlay hint указанного [kind].
///
/// Используется в [EditorLayersPainter], [InlayLayoutMetrics] и виджетном
/// [TextInlayHint] для единообразного оформления.
Color inlayHintColor(EditorInlayHintKind kind, EditorTheme theme) =>
    switch (kind) {
      EditorInlayHintKind.type => theme.inlayHintTypeColor,
      EditorInlayHintKind.parameter => theme.inlayHintParameterColor,
      EditorInlayHintKind.other => theme.inlayHintOtherColor,
    };
