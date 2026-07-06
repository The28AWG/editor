import 'package:flutter/widgets.dart';

/// Предпочтительное размещение overlay относительно якоря.
enum EditorOverlayPlacement { below, above, besideStart, besideEnd, center }

/// Выравнивание дочерней панели по поперечной оси относительно bbox родителя.
///
/// Для [EditorOverlayPlacement.besideStart]/[EditorOverlayPlacement.besideEnd] —
/// вертикаль (start = верх, end = низ). Для [EditorOverlayPlacement.below]/
/// [EditorOverlayPlacement.above] — горизонталь (start = левый край).
enum EditorOverlayChildAlign { start, center, end }

/// Угол/ребро для изменения размера панели.
enum EditorOverlayResizeHandle { bottomRight, bottom, right }

/// Область захвата для перетаскивания overlay.
enum EditorOverlayDragHandle {
  /// Тонкая полоска с grip над содержимым (библиотека рисует сама).
  header,

  /// Drag-зона задаётся в [builder] через [EditorOverlayPanelDragHandle].
  custom,
}

/// Политика размещения и ограничений размера overlay.
final class EditorOverlayLayoutPolicy {
  const EditorOverlayLayoutPolicy({
    this.placement = EditorOverlayPlacement.below,
    this.flipIfOverflow = true,
    this.clampToViewport = true,
    this.gap = 4,
    this.margin = EdgeInsets.zero,
    this.maxWidth,
    this.maxHeight,
    this.preferredWidth,
    this.preferredHeight,
    this.minWidth = 120,
    this.minHeight = 24,
    this.resizable = false,
    this.resizeHandle = EditorOverlayResizeHandle.bottomRight,
    this.draggable = false,
    this.dragHandle = EditorOverlayDragHandle.header,
    this.childAlign = EditorOverlayChildAlign.start,
  });

  final EditorOverlayPlacement placement;
  final bool flipIfOverflow;

  /// `true` — удерживать панель внутри viewport [EditorView]; `false` — в пределах overlay-хоста.
  final bool clampToViewport;
  final double gap;
  final EdgeInsets margin;
  final double? maxWidth;
  final double? maxHeight;
  final double? preferredWidth;
  final double? preferredHeight;
  final double minWidth;
  final double minHeight;
  final bool resizable;
  final EditorOverlayResizeHandle resizeHandle;
  final bool draggable;
  final EditorOverlayDragHandle dragHandle;

  /// Выравнивание относительно bbox родителя ([EditorOverlayDescriptor.parentId]).
  final EditorOverlayChildAlign childAlign;

  /// Копия с другим [placement] (для дочерних панелей, например details справа).
  EditorOverlayLayoutPolicy withPlacement(EditorOverlayPlacement placement) =>
      EditorOverlayLayoutPolicy(
        placement: placement,
        flipIfOverflow: flipIfOverflow,
        clampToViewport: clampToViewport,
        gap: gap,
        margin: margin,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        preferredWidth: preferredWidth,
        preferredHeight: preferredHeight,
        minWidth: minWidth,
        minHeight: minHeight,
        resizable: resizable,
        resizeHandle: resizeHandle,
        draggable: draggable,
        dragHandle: dragHandle,
        childAlign: childAlign,
      );
}

/// Результат расчёта позиции overlay в координатах viewport.
final class EditorOverlayLayoutResult {
  const EditorOverlayLayoutResult({
    required this.offset,
    required this.maxWidth,
    required this.maxHeight,
    required this.effectivePlacement,
  });

  final Offset offset;
  final double maxWidth;
  final double maxHeight;
  final EditorOverlayPlacement effectivePlacement;
}

/// Вычисляет позицию overlay в локальных координатах [layoutBounds].
EditorOverlayLayoutResult computeOverlayLayout({
  required Rect anchorRect,
  required Rect layoutBounds,
  required EditorOverlayLayoutPolicy policy,
  Size? contentSize,
  Rect? relativeToRect,
}) {
  final anchor = relativeToRect ?? anchorRect;
  final margin = policy.margin;
  final isChild = relativeToRect != null;
  final vw = layoutBounds.width - margin.horizontal;
  final vh = layoutBounds.height - margin.vertical;
  final boundsOrigin = layoutBounds.topLeft;

  var maxW = policy.maxWidth ?? vw;
  var maxH = policy.maxHeight ?? vh;
  if (contentSize != null) {
    maxW = maxW.clamp(policy.minWidth, vw);
    maxH = maxH.clamp(policy.minHeight, vh);
  }

  final prefW = (policy.preferredWidth ?? contentSize?.width ?? policy.minWidth)
      .clamp(policy.minWidth, maxW);
  final prefH =
      (policy.preferredHeight ?? contentSize?.height ?? policy.minHeight).clamp(
        policy.minHeight,
        maxH,
      );

  var placement = policy.placement;
  var top = 0.0;
  var left = 0.0;

  Offset positionFor(EditorOverlayPlacement p) => switch (p) {
    EditorOverlayPlacement.below => Offset(
      isChild
          ? _childAlignHorizontal(
              parent: anchor,
              childExtent: prefW,
              align: policy.childAlign,
            )
          : anchor.left,
      anchor.bottom + policy.gap,
    ),
    EditorOverlayPlacement.above => Offset(
      isChild
          ? _childAlignHorizontal(
              parent: anchor,
              childExtent: prefW,
              align: policy.childAlign,
            )
          : anchor.left,
      anchor.top - prefH - policy.gap,
    ),
    EditorOverlayPlacement.besideEnd => Offset(
      anchor.right + policy.gap,
      isChild
          ? _childAlignVertical(
              parent: anchor,
              childExtent: prefH,
              align: policy.childAlign,
            )
          : anchor.top,
    ),
    EditorOverlayPlacement.besideStart => Offset(
      anchor.left - prefW - policy.gap,
      isChild
          ? _childAlignVertical(
              parent: anchor,
              childExtent: prefH,
              align: policy.childAlign,
            )
          : anchor.top,
    ),
    EditorOverlayPlacement.center => Offset(
      anchor.center.dx - prefW / 2,
      anchor.center.dy - prefH / 2,
    ),
  };

  var pos = positionFor(placement);

  if (policy.flipIfOverflow) {
    final belowOverflow =
        pos.dy + prefH > boundsOrigin.dy + vh + margin.top &&
        placement == EditorOverlayPlacement.below;
    final aboveOverflow =
        pos.dy < boundsOrigin.dy + margin.top &&
        placement == EditorOverlayPlacement.above;
    final endOverflow =
        pos.dx + prefW > boundsOrigin.dx + vw + margin.left &&
        placement == EditorOverlayPlacement.besideEnd;
    final startOverflow =
        pos.dx < boundsOrigin.dx + margin.left &&
        placement == EditorOverlayPlacement.besideStart;

    if (belowOverflow) {
      placement = EditorOverlayPlacement.above;
      pos = positionFor(placement);
    } else if (aboveOverflow) {
      placement = EditorOverlayPlacement.below;
      pos = positionFor(placement);
    } else if (endOverflow) {
      placement = EditorOverlayPlacement.besideStart;
      pos = positionFor(placement);
    } else if (startOverflow) {
      placement = EditorOverlayPlacement.besideEnd;
      pos = positionFor(placement);
    }
  }

  left = pos.dx + margin.left;
  top = pos.dy + margin.top;

  if (policy.clampToViewport) {
    final minLeft = boundsOrigin.dx + margin.left;
    final minTop = boundsOrigin.dy + margin.top;
    final maxLeft = boundsOrigin.dx + margin.left + vw - prefW;
    final maxTop = boundsOrigin.dy + margin.top + vh - prefH;
    if (left > maxLeft) left = maxLeft;
    if (left < minLeft) left = minLeft;
    if (top > maxTop) top = maxTop;
    if (top < minTop) top = minTop;
  }

  return EditorOverlayLayoutResult(
    offset: Offset(left, top),
    maxWidth: maxW,
    maxHeight: maxH,
    effectivePlacement: placement,
  );
}

/// Границы layout в координатах viewport редактора.
///
/// [clampToViewport] `true` — только видимая область [EditorView] (поведение по умолчанию).
/// `false` — весь overlay-хост (экран), панель может выходить за край viewport.
Rect overlayLayoutBounds({
  required Rect viewportRectLocal,
  required Offset viewportGlobalOrigin,
  required Size overlayHostSize,
  required bool clampToViewport,
}) {
  if (clampToViewport) return viewportRectLocal;
  return Rect.fromLTWH(
    -viewportGlobalOrigin.dx,
    -viewportGlobalOrigin.dy,
    overlayHostSize.width,
    overlayHostSize.height,
  );
}

/// Ограничивает пользовательское смещение в пределах [layoutBounds].
Offset clampOverlayUserOffset({
  required Offset baseOffset,
  required Offset userOffset,
  required Size panelSize,
  required Rect layoutBounds,
  EdgeInsets margin = EdgeInsets.zero,
  bool clamp = true,
}) {
  if (!clamp) return userOffset;

  var left = baseOffset.dx + userOffset.dx;
  var top = baseOffset.dy + userOffset.dy;
  final minLeft = layoutBounds.left + margin.left;
  final minTop = layoutBounds.top + margin.top;
  final maxLeft = layoutBounds.right - margin.right - panelSize.width;
  final maxTop = layoutBounds.bottom - margin.bottom - panelSize.height;

  left = panelSize.width <= layoutBounds.width - margin.horizontal
      ? left.clamp(minLeft, maxLeft)
      : minLeft;
  top = panelSize.height <= layoutBounds.height - margin.vertical
      ? top.clamp(minTop, maxTop)
      : minTop;

  return Offset(left - baseOffset.dx, top - baseOffset.dy);
}

/// [userOffset] из желаемого верхнего левого угла панели в глобальных координатах.
Offset overlayUserOffsetFromGlobal({
  required Offset panelGlobalTopLeft,
  required Offset viewportGlobalOrigin,
  required Offset layoutOffset,
}) => Offset(
  panelGlobalTopLeft.dx - viewportGlobalOrigin.dx - layoutOffset.dx,
  panelGlobalTopLeft.dy - viewportGlobalOrigin.dy - layoutOffset.dy,
);

double _childAlignVertical({
  required Rect parent,
  required double childExtent,
  required EditorOverlayChildAlign align,
}) => switch (align) {
  EditorOverlayChildAlign.start => parent.top,
  EditorOverlayChildAlign.center =>
    parent.top + (parent.height - childExtent) / 2,
  EditorOverlayChildAlign.end => parent.bottom - childExtent,
};

double _childAlignHorizontal({
  required Rect parent,
  required double childExtent,
  required EditorOverlayChildAlign align,
}) => switch (align) {
  EditorOverlayChildAlign.start => parent.left,
  EditorOverlayChildAlign.center =>
    parent.left + (parent.width - childExtent) / 2,
  EditorOverlayChildAlign.end => parent.right - childExtent,
};
