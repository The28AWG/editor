import 'dart:ui' as ui;

import 'package:editor/src/layout/line_layout.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/editor_theme.dart';

/// Преобразует координаты указателя в [TextOffset] документа.
///
/// [surfaceLocal] — координаты относительно [RenderBox] поверхности редактора:
/// origin в верхнем левом углу содержимого документа (как [EditorBox.top]).
final class DocumentPointerMapper {
  const DocumentPointerMapper({
    required this.lineLayout,
    required this.document,
    required this.theme,
    required this.gutterWidth,
  });

  final LineLayout lineLayout;
  final Document document;
  final EditorTheme theme;
  final double gutterWidth;

  /// Document Y = [surfaceLocal.dy]; X в текстовой области = [surfaceLocal.dx] − [gutterWidth].
  TextOffset? surfaceLocalToOffset(ui.Offset surfaceLocal) {
    final lineH = theme.lineHeightPx;
    // Клик чуть выше первой строки (y < 0) иначе попадает в document.length.
    final y = surfaceLocal.dy < 0 ? 0.0 : surfaceLocal.dy;
    var line = 0;
    var accY = 0.0;
    while (line < document.lineCount) {
      final visuals = lineLayout.visualLinesForDocumentLine(line);
      final blockH = lineH * visuals.length;
      if (y >= accY && y < accY + blockH) {
        final x = surfaceLocal.dx - gutterWidth;
        return lineLayout.getOffsetAtPoint(
          line,
          x,
          localYInLine: y - accY,
          lineHeightFactor: theme.lineHeight,
        );
      }
      accY += blockH;
      line++;
    }
    return document.length;
  }
}
