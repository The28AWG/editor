import 'package:editor/src/model/position.dart';
import 'package:flutter/widgets.dart';

/// Край viewport для [EditorViewportOverlayAnchor].
enum EditorViewportEdge { top, bottom, left, right, center }

/// Якорь всплывающего overlay относительно редактора или экрана.
///
/// Координаты разрешаются через [EditorOverlayGeometrySource] в момент показа
/// и при [EditorOverlayDismissPolicy.trackAnchorOnScroll].
sealed class EditorOverlayAnchor {
  const EditorOverlayAnchor();
}

/// Якорь у каретки или диапазона замены (completion replace range).
final class EditorCaretOverlayAnchor extends EditorOverlayAnchor {
  const EditorCaretOverlayAnchor({this.offset, this.replaceRange});

  /// Смещение каретки; `null` — основная каретка [Selection.primary].
  final TextOffset? offset;

  /// Диапазон partial token для autocomplete; приоритетнее [offset].
  final Range? replaceRange;
}

/// Якорь по диапазону текста (hover, code action у диагностики).
final class EditorRangeOverlayAnchor extends EditorOverlayAnchor {
  const EditorRangeOverlayAnchor(this.range);

  final Range range;
}

/// Якорь в глобальных координатах (контекстное меню, pointer).
final class EditorPointOverlayAnchor extends EditorOverlayAnchor {
  const EditorPointOverlayAnchor(this.globalPoint, {this.hitSize});

  final Offset globalPoint;

  /// Минимальный rect якоря; по умолчанию 1×lineHeight задаёт geometry.
  final Size? hitSize;
}

/// Якорь у края viewport (find bar, sticky panel).
final class EditorViewportOverlayAnchor extends EditorOverlayAnchor {
  const EditorViewportOverlayAnchor({
    this.edge = EditorViewportEdge.top,
    this.margin = EdgeInsets.zero,
  });

  final EditorViewportEdge edge;
  final EdgeInsets margin;
}
