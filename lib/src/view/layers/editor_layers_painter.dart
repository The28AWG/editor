import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/diagnostics/diagnostic_decorations.dart'
    show diagnosticInlineMessageColor;
import 'package:editor/src/diagnostics/inline_diagnostic_label.dart';
import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/inlay/inlay_hint_style.dart';
import 'package:editor/src/layout/glyph_cache.dart';
import 'package:editor/src/layout/line_layout.dart';
import 'package:editor/src/layout/line_text_metrics.dart';
import 'package:editor/src/layout/visual_line.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_code_units.dart';
import 'package:editor/src/styling/resolved_style.dart';
import 'package:editor/src/view/caret/caret_blink_controller.dart';
import 'package:flutter/widgets.dart';

/// [CustomPainter], отрисовывающий полный визуальный стек редактора.
///
/// Порядок отрисовки за кадр:
/// 1. Фон и необязательная колонка gutter.
/// 2. Подсветка текущей строки для основной линии каретки.
/// 3. Номера строк в gutter (при [showGutter]).
/// 4. Текст документа с чередованием inlay hints.
/// 5. Inline «призрачные» диагностические сообщения на последней визуальной строке каждой линии.
/// 6. Прямоугольники выделения (несвёрнутые диапазоны).
/// 7. Линии каретки (свёрнутые выделения).
///
/// Перерисовывается при уведомлении [controller] ([repaint: controller]).
final class EditorLayersPainter extends CustomPainter {
  /// Создаёт painter для указанных [controller] и [lineLayout].
  EditorLayersPainter({
    required this.controller,
    required this.lineLayout,
    required this.glyphCache,
    required this.caretBlink,
    this.showGutter = false,
    this.gutterWidth = 48,
    Listenable? repaint,
  }) : super(repaint: repaint ?? controller);

  /// Источник документа, темы, выделения, диагностики и viewport.
  final EditorController controller;

  /// Перенос строк, геометрия hit-test и метрики inlay.
  final LineLayout lineLayout;

  /// Общие измерения ширины символов.
  final GlyphCache glyphCache;

  /// Фаза мигания и видимость каретки (фокус).
  final CaretBlinkController caretBlink;

  /// Рисовать ли gutter с номерами строк.
  final bool showGutter;

  /// Ширина колонки gutter в логических пикселях.
  final double gutterWidth;

  /// Отрисовывает видимые строки, gutter, выделение и каретки за один проход.
  @override
  void paint(Canvas canvas, Size size) {
    final theme = controller.theme;
    final doc = controller.document;

    final lineH = theme.lineHeightPx;
    final textOffsetX = showGutter ? gutterWidth : 0.0;

    canvas.drawRect(Offset.zero & size, Paint()..color = theme.backgroundColor);

    if (showGutter) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, gutterWidth, size.height),
        Paint()..color = theme.gutterBackgroundColor,
      );
    }

    // [SingleChildScrollView] уже сдвигает child на −scrollOffset; рисуем в
    // координатах документа (canvas Y = document Y), без повторного вычитания scroll.
    final scroll = controller.viewport.scrollOffset;
    final viewH = controller.viewport.viewportHeight;
    final overscan = controller.viewport.overscanLines * lineH;
    final viewTop = scroll - overscan;
    final viewBottom = scroll + viewH + overscan;

    final inlineByLine = {
      for (final label in controller.inlineDiagnosticLabels)
        label.documentLine: label,
    };

    if (viewH > 0) {
      canvas
        ..save()
        ..clipRect(Rect.fromLTWH(0, scroll, size.width, viewH));
    }

    // Прыгаем к первой строке, чьё нижнее ребро ещё в viewport: без word-wrap
    // это O(1), с переносом — O(log n) через _blockTops. Так paint больше не
    // обходит все 0..lineCount при правке в середине большого файла.
    final lineHeightFactor = theme.lineHeight;
    final firstLine = lineLayout
        .lineIndexForDocumentY(viewTop, lineHeightFactor)
        .clamp(0, doc.lineCount - 1);
    var documentY = lineLayout.lineTopY(firstLine, lineHeightFactor);
    for (var line = firstLine; line < doc.lineCount; line++) {
      final visuals = lineLayout.visualLinesForDocumentLine(line);
      final blockH = lineH * visuals.length;
      final blockTop = documentY;
      documentY += blockH;

      if (blockTop > viewBottom) break;

      var y = blockTop;
      final primaryHead = controller.selection.primary.head;
      final headPos = doc.positionAt(primaryHead);

      if (headPos.line == line) {
        canvas.drawRect(
          Rect.fromLTWH(textOffsetX, y, size.width - textOffsetX, blockH),
          Paint()..color = theme.currentLineColor,
        );
      }

      if (showGutter) {
        final gutterText = TextPainter(
          text: TextSpan(
            text: '${line + 1}',
            style: TextStyle(
              color: theme.gutterTextColor,
              fontSize: theme.fontSize,
              fontFamily: theme.fontFamily,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        gutterText.paint(
          canvas,
          Offset(
            gutterWidth - gutterText.width - 8,
            y + (blockH - gutterText.height) / 2.0,
          ),
        );
      }

      final inlineLabel = inlineByLine[line];

      for (var vi = 0; vi < visuals.length; vi++) {
        final visual = visuals[vi];
        final xAfter = _paintVisualLine(
          canvas,
          line,
          y,
          lineH,
          textOffsetX,
          visual: visual,
        );
        if (inlineLabel != null && vi == visuals.length - 1) {
          _paintInlineDiagnostic(canvas, xAfter, y, lineH, inlineLabel);
        }
        y += lineH;
      }
    }

    if (viewH > 0) {
      canvas.restore();
    }

    _paintSelection(canvas, textOffsetX);
    _paintCarets(canvas, textOffsetX);
  }

  /// Заливает прямоугольники выделения из [lineLayout.getBoxesForRange].
  void _paintSelection(Canvas canvas, double textOffsetX) {
    for (final sel in controller.selection.selections) {
      if (sel.isCollapsed) continue;
      final boxes = lineLayout.getBoxesForRange(
        sel.range,
        controller.theme.lineHeight,
      );
      final paint = Paint()..color = controller.theme.selectionColor;
      for (final box in boxes) {
        canvas.drawRect(
          Rect.fromLTWH(
            textOffsetX + box.left,
            box.top,
            box.right - box.left,
            box.bottom - box.top,
          ),
          paint,
        );
      }
    }
  }

  /// Рисует одну визуальную строку, чередуя текст документа и inlay hints.
  ///
  /// Когда [lineLayout.inlayMetrics] равен null, рисует весь визуальный диапазон
  /// за один проход. Иначе обходит hints по порядку якорей: сегмент текста, hint,
  /// сегмент текста, … Возвращает X-позицию после отрисованного содержимого.
  double _paintVisualLine(
    Canvas canvas,
    int line,
    double y,
    double lineH,
    double textOffsetX, {
    required VisualLine visual,
  }) {
    final lineBaselineY = _lineBaselineYForVisual(line, y, lineH, visual);
    final metrics = lineLayout.inlayMetrics;
    if (metrics == null) {
      return _paintDocumentRange(
        canvas,
        line,
        textOffsetX,
        visual: visual,
        rangeStart: visual.documentStart,
        rangeEnd: visual.documentEnd,
        lineBaselineY: lineBaselineY,
      );
    }

    final hints = metrics.hintsForVisual(visual);
    var x = textOffsetX;
    var segmentStart = visual.documentStart;

    // Текст документа и inlay чередуются: [segmentStart, anchor) → hint → следующий сегмент.
    for (final hint in hints) {
      x = _paintDocumentRange(
        canvas,
        line,
        x,
        visual: visual,
        rangeStart: segmentStart,
        rangeEnd: hint.anchorOffset,
        lineBaselineY: lineBaselineY,
      );
      x = _paintInlayHint(canvas, x, hint, lineBaselineY);
      segmentStart = hint.anchorOffset;
    }

    return _paintDocumentRange(
      canvas,
      line,
      x,
      visual: visual,
      rangeStart: segmentStart,
      rangeEnd: visual.documentEnd,
      lineBaselineY: lineBaselineY,
    );
  }

  /// Вычисляет baseline Y для визуальной строки из resolved style runs.
  ///
  /// Использует [LineTextMetrics.fromPainters], когда runs есть; иначе fallback
  /// на значения темы. Применяет [EditorTheme.lineVerticalAlign] внутри [lineH].
  double _lineBaselineYForVisual(
    int line,
    double y,
    double lineH,
    VisualLine visual,
  ) {
    final theme = controller.theme;
    final runs = lineLayout.attributedRunsForLine(line);
    final painters = <TextPainter>[];

    for (final run in runs) {
      final overlapStart = run.start < visual.documentStart
          ? visual.documentStart
          : run.start;
      final overlapEnd = run.end > visual.documentEnd
          ? visual.documentEnd
          : run.end;
      if (overlapStart >= overlapEnd) continue;

      final localStart = overlapStart - run.start;
      final localEnd = overlapEnd - run.start;
      final slice = sliceCodeUnits(run.text, localStart, localEnd);
      if (slice.isEmpty) continue;

      painters.add(
        layoutRunPainter(text: slice, style: _textStyleForRun(run.style)),
      );
    }

    final lineMetrics = painters.isEmpty
        ? LineTextMetrics.fromTheme(theme)
        : LineTextMetrics.fromPainters(painters);
    final contentTop = lineMetrics.contentTop(
      y,
      lineH,
      theme.lineVerticalAlign,
    );
    return lineMetrics.lineBaselineY(contentTop);
  }

  /// Рисует стилизованный текст для `[rangeStart, rangeEnd)` и возвращает trailing X.
  ///
  /// Разрешает перекрывающиеся style runs, нарезает code units по run и рисует
  /// через [layoutRunPainter]. Когда перекрывающих runs нет (пустой slice), использует
  /// только [InlayLayoutMetrics.layoutX] или [GlyphCache.measureText] для ширины.
  double _paintDocumentRange(
    Canvas canvas,
    int line,
    double textOffsetX, {
    required VisualLine visual,
    required TextOffset rangeStart,
    required TextOffset rangeEnd,
    required double lineBaselineY,
  }) {
    if (rangeEnd <= rangeStart) return textOffsetX;

    final runs = lineLayout.attributedRunsForLine(line);
    final painters = <TextPainter>[];
    final runTexts = <String>[];

    for (final run in runs) {
      final overlapStart = run.start < rangeStart ? rangeStart : run.start;
      final overlapEnd = run.end > rangeEnd ? rangeEnd : run.end;
      if (overlapStart >= overlapEnd) continue;

      final localStart = overlapStart - run.start;
      final localEnd = overlapEnd - run.start;
      final slice = sliceCodeUnits(run.text, localStart, localEnd);
      if (slice.isEmpty) continue;

      runTexts.add(slice);
      painters.add(
        layoutRunPainter(text: slice, style: _textStyleForRun(run.style)),
      );
    }

    if (painters.isEmpty) {
      final metrics = lineLayout.inlayMetrics;
      if (metrics != null) {
        return textOffsetX + metrics.layoutX(line, visual, rangeEnd);
      }
      final localEnd = rangeEnd - visual.documentStart;
      final localStart = rangeStart - visual.documentStart;
      return textOffsetX +
          glyphCache.measureText(
            sliceCodeUnits(visual.text, localStart, localEnd),
          );
    }

    var x = textOffsetX;
    for (var i = 0; i < painters.length; i++) {
      final painter = painters[i];
      painter.paint(canvas, runPaintOffset(painter, x, lineBaselineY));
      x += painters[i].width;
    }
    return x;
  }

  /// Рисует один [EditorInlayHint] курсивом при 90% размера шрифта.
  double _paintInlayHint(
    Canvas canvas,
    double x,
    EditorInlayHint hint,
    double lineBaselineY,
  ) {
    final theme = controller.theme;
    var posX = x + hint.paddingLeft;

    final painter = layoutRunPainter(
      text: hint.label,
      style: TextStyle(
        color: inlayHintColor(hint.kind, theme),
        fontSize: theme.fontSize * 0.9,
        fontFamily: theme.fontFamily,
        fontStyle: FontStyle.italic,
      ),
    );
    painter.paint(canvas, runPaintOffset(painter, posX, lineBaselineY));
    return posX + painter.width + hint.paddingRight;
  }

  /// Рисует курсивное «призрачное» диагностическое сообщение после текста документа на строке.
  void _paintInlineDiagnostic(
    Canvas canvas,
    double x,
    double y,
    double lineH,
    InlineDiagnosticLabel label,
  ) {
    final theme = controller.theme;
    final gap = glyphCache.measureText('  ');
    final painter = layoutRunPainter(
      text: ' ${label.message}',
      style: TextStyle(
        color: diagnosticInlineMessageColor(label.severity, theme),
        fontSize: theme.fontSize,
        fontFamily: theme.fontFamily,
        fontStyle: FontStyle.italic,
      ),
    );
    final metrics = LineTextMetrics.fromPainters([painter]);
    final contentTop = metrics.contentTop(y, lineH, theme.lineVerticalAlign);
    painter.paint(
      canvas,
      runPaintOffset(painter, x + gap, metrics.lineBaselineY(contentTop)),
    );
  }

  TextStyle _textStyleForRun(ResolvedStyle style) =>
      textStyleForResolvedStyle(style);

  /// Рисует вертикальные линии каретки для свёрнутых выделений (поддержка мультикурсора).
  void _paintCarets(Canvas canvas, double textOffsetX) {
    if (!caretBlink.shouldPaintCaret) return;

    final appearance = caretBlink.appearanceFor(controller.theme.caretBlink);
    if (!appearance.isEffectivelyVisible) return;

    final paint = Paint()
      ..color = appearance.color
      ..strokeWidth = appearance.strokeWidth;
    for (final sel in controller.selection.selections) {
      if (!sel.isCollapsed) continue;
      final boxes = lineLayout.getBoxesForRange(
        Range(sel.head, sel.head),
        controller.theme.lineHeight,
      );
      if (boxes.isEmpty) continue;
      final box = boxes.first;
      canvas.drawLine(
        Offset(textOffsetX + box.left, box.top),
        Offset(textOffsetX + box.left, box.bottom),
        paint,
      );
    }
  }

  /// Перерисовка при смене контроллера или экземпляра [lineLayout].
  @override
  bool shouldRepaint(covariant EditorLayersPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.lineLayout != lineLayout ||
      oldDelegate.caretBlink != caretBlink;
}
