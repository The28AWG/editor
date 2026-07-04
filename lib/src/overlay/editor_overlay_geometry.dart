import 'package:editor/src/layout/line_layout.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/overlay/editor_overlay_anchor.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Источник геометрии редактора для позиционирования overlay.
///
/// Реализуется [EditorScrollable] и подключается к [EditorOverlayCoordinator]
/// через [EditorController.attachOverlayGeometry].
abstract class EditorOverlayGeometrySource {
  double get gutterWidth;

  EditorTheme get theme;

  Document get document;

  SelectionState get selection;

  /// Прямоугольник каретки в глобальных координатах.
  Rect? caretRectInGlobal({TextOffset? offset});

  /// Объединённый bbox диапазона в глобальных координатах.
  Rect? rangeRectInGlobal(Range range);

  /// Видимая область viewport в глобальных координатах.
  Rect? viewportRectInGlobal();

  /// Преобразует global → локальные координаты overlay-root (viewport).
  Offset? globalToViewportLocal(Offset global);

  /// Преобразует global rect → локальные координаты viewport.
  Rect? globalRectToViewportLocal(Rect global) {
    final topLeft = globalToViewportLocal(global.topLeft);
    final bottomRight = globalToViewportLocal(global.bottomRight);
    if (topLeft == null || bottomRight == null) return null;
    return Rect.fromPoints(topLeft, bottomRight);
  }
}

/// Разрешает [EditorOverlayAnchor] в rect в координатах viewport.
Rect? resolveOverlayAnchorRect({
  required EditorOverlayAnchor anchor,
  required EditorOverlayGeometrySource geometry,
}) => switch (anchor) {
  EditorCaretOverlayAnchor(:final offset, :final replaceRange) => () {
    if (replaceRange != null) {
      final global = geometry.rangeRectInGlobal(replaceRange);
      return global == null ? null : geometry.globalRectToViewportLocal(global);
    }
    final global = geometry.caretRectInGlobal(offset: offset);
    return global == null ? null : geometry.globalRectToViewportLocal(global);
  }(),
  EditorRangeOverlayAnchor(:final range) => () {
    final global = geometry.rangeRectInGlobal(range);
    return global == null ? null : geometry.globalRectToViewportLocal(global);
  }(),
  EditorPointOverlayAnchor(:final globalPoint, :final hitSize) => () {
    final lineH = geometry.theme.lineHeightPx;
    final size = hitSize ?? Size(48, lineH);
    final global = Rect.fromCenter(
      center: globalPoint,
      width: size.width,
      height: size.height,
    );
    return geometry.globalRectToViewportLocal(global);
  }(),
  EditorViewportOverlayAnchor(:final edge, :final margin) => () {
    final viewport = geometry.viewportRectInGlobal();
    if (viewport == null) return null;
    final local = geometry.globalRectToViewportLocal(viewport);
    if (local == null) return null;
    return switch (edge) {
      EditorViewportEdge.top => Rect.fromLTWH(
        local.left + margin.left,
        local.top + margin.top,
        local.width - margin.horizontal,
        0,
      ),
      EditorViewportEdge.bottom => Rect.fromLTWH(
        local.left + margin.left,
        local.bottom - margin.bottom,
        local.width - margin.horizontal,
        0,
      ),
      EditorViewportEdge.left => Rect.fromLTWH(
        local.left + margin.left,
        local.top + margin.top,
        0,
        local.height - margin.vertical,
      ),
      EditorViewportEdge.right => Rect.fromLTWH(
        local.right - margin.right,
        local.top + margin.top,
        0,
        local.height - margin.vertical,
      ),
      EditorViewportEdge.center => Rect.fromCenter(
        center: local.center,
        width: 0,
        height: 0,
      ),
    };
  }(),
};

/// Живые привязки к layout/viewport [EditorScrollable] для геометрии overlay.
abstract class EditorOverlayGeometryBindings {
  LineLayout get lineLayout;

  Document get document;

  EditorTheme get theme;

  SelectionState get selection;

  double get gutterWidth;

  RenderBox? get surfaceBox;

  RenderBox? get viewportBox;
}

/// Реализация [EditorOverlayGeometrySource] на базе [EditorOverlayGeometryBindings].
final class EditorScrollableOverlayGeometry
    implements EditorOverlayGeometrySource {
  EditorScrollableOverlayGeometry(this._bindings);

  final EditorOverlayGeometryBindings _bindings;

  @override
  double get gutterWidth => _bindings.gutterWidth;

  @override
  EditorTheme get theme => _bindings.theme;

  @override
  Document get document => _bindings.document;

  @override
  SelectionState get selection => _bindings.selection;

  Rect? _localRangeOnSurface(Range range) {
    final boxes = _bindings.lineLayout.getBoxesForRange(
      range,
      theme.lineHeight,
    );
    if (boxes.isEmpty) return null;

    var left = boxes.first.left;
    var top = boxes.first.top;
    var right = boxes.first.right;
    var bottom = boxes.first.bottom;
    for (var i = 1; i < boxes.length; i++) {
      final b = boxes[i];
      if (b.left < left) left = b.left;
      if (b.top < top) top = b.top;
      if (b.right > right) right = b.right;
      if (b.bottom > bottom) bottom = b.bottom;
    }
    return Rect.fromLTRB(gutterWidth + left, top, gutterWidth + right, bottom);
  }

  @override
  Rect? caretRectInGlobal({TextOffset? offset}) {
    final head = offset ?? selection.primary.head;
    final local = _localRangeOnSurface(Range(head, head));
    if (local == null) return null;
    final box = _bindings.surfaceBox;
    if (box == null) return null;
    return Rect.fromPoints(
      box.localToGlobal(local.topLeft),
      box.localToGlobal(local.bottomRight),
    );
  }

  @override
  Rect? rangeRectInGlobal(Range range) {
    final local = _localRangeOnSurface(range);
    if (local == null) return null;
    final box = _bindings.surfaceBox;
    if (box == null) return null;
    return Rect.fromPoints(
      box.localToGlobal(local.topLeft),
      box.localToGlobal(local.bottomRight),
    );
  }

  @override
  Rect? viewportRectInGlobal() {
    final box = _bindings.viewportBox;
    if (box == null) return null;
    return Rect.fromLTWH(
      0,
      0,
      box.size.width,
      box.size.height,
    ).shift(box.localToGlobal(Offset.zero));
  }

  @override
  Offset? globalToViewportLocal(Offset global) {
    final box = _bindings.viewportBox;
    if (box == null) return null;
    return box.globalToLocal(global);
  }

  @override
  Rect? globalRectToViewportLocal(Rect global) {
    final topLeft = globalToViewportLocal(global.topLeft);
    final bottomRight = globalToViewportLocal(global.bottomRight);
    if (topLeft == null || bottomRight == null) return null;
    return Rect.fromPoints(topLeft, bottomRight);
  }
}
