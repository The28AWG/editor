/// Осевая прямоугольная область для геометрии выделения, каретки или подсветки.
///
/// Координаты в пространстве макета (пиксели от верхнего левого угла области
/// содержимого документа). [left] и [right] могут совпадать для прямоугольника каретки нулевой ширины.
///
/// ```dart
/// final boxes = layout.getBoxesForRange(selection, lineHeightFactor);
/// for (final box in boxes) {
///   canvas.drawRect(
///     Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
///     paint,
///   );
/// }
/// ```
final class EditorBox {
  /// Создаёт прямоугольник по координатам граней.
  const EditorBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// Левая грань в координатах X макета.
  final double left;

  /// Верхняя грань в координатах Y макета.
  final double top;

  /// Правая грань в координатах X макета.
  final double right;

  /// Нижняя грань в координатах Y макета.
  final double bottom;
}
