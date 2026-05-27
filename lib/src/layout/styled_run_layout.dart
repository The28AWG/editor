import 'package:editor/src/layout/line_text_metrics.dart';
import 'package:editor/src/layout/visual_line.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_code_units.dart';
import 'package:editor/src/styling/attributed_run.dart';
import 'package:editor/src/styling/resolved_style.dart';
import 'package:flutter/painting.dart';

/// Горизонтальный layout по style runs — те же [TextPainter], что и при отрисовке.
///
/// [GlyphCache] не учитывает bold/italic и даёт сдвиг hit-test относительно картинки.
///
/// [runsForLine] обычно подключают к [LineLayout.attributedRunsForLine], что даёт
/// общий кэш [AttributedRun] на строку и убирает повторный sweep-line при hit-test
/// и paint в одном кадре.
final class StyledRunLayout {
  const StyledRunLayout({required this.document, required this.runsForLine});

  final Document document;
  final List<AttributedRun> Function(int lineIndex) runsForLine;

  /// X от начала [visual] до [offset] (пиксели).
  double layoutX(int lineIndex, VisualLine visual, TextOffset offset) {
    final clamped = _clamp(visual, offset);
    var x = 0.0;
    for (final slice in _slices(lineIndex, visual)) {
      if (clamped <= slice.start) return x;
      if (clamped >= slice.end) {
        x += slice.painter.width;
        continue;
      }
      if (clamped > slice.start) {
        final local = clamped - slice.start;
        final prefix = sliceCodeUnits(slice.text, 0, local);
        if (prefix.isNotEmpty) {
          x += layoutRunPainter(
            text: prefix,
            style: textStyleForResolvedStyle(slice.style),
          ).width;
        }
      }
      return x;
    }
    return x;
  }

  /// Смещение документа по layout X на [visual] (через [TextPainter.getPositionForOffset]).
  TextOffset offsetAtLayoutX(int lineIndex, VisualLine visual, double x) {
    if (x <= 0) return visual.documentStart;

    var layout = 0.0;
    for (final slice in _slices(lineIndex, visual)) {
      final w = slice.painter.width;
      if (x < layout + w) {
        final pos = slice.painter.getPositionForOffset(Offset(x - layout, 0));
        return slice.start + pos.offset;
      }
      layout += w;
    }
    return visual.documentEnd;
  }

  TextOffset _clamp(VisualLine visual, TextOffset offset) {
    if (offset < visual.documentStart) return visual.documentStart;
    if (offset > visual.documentEnd) return visual.documentEnd;
    return offset;
  }

  /// Обрезает [AttributedRun] по границам [visual] и строит [TextPainter] на каждый сегмент.
  Iterable<_RunSlice> _slices(int lineIndex, VisualLine visual) sync* {
    for (final run in runsForLine(lineIndex)) {
      final start = run.start < visual.documentStart
          ? visual.documentStart
          : run.start;
      final end = run.end > visual.documentEnd ? visual.documentEnd : run.end;
      if (start >= end) continue;

      final localStart = start - run.start;
      final localEnd = end - run.start;
      final text = sliceCodeUnits(run.text, localStart, localEnd);
      if (text.isEmpty) continue;

      yield _RunSlice(
        start: start,
        end: end,
        text: text,
        style: run.style,
        painter: layoutRunPainter(
          text: text,
          style: textStyleForResolvedStyle(run.style),
        ),
      );
    }
  }
}

/// Один непрерывный сегмент style run внутри [VisualLine] с предвычисленным layout.
final class _RunSlice {
  const _RunSlice({
    required this.start,
    required this.end,
    required this.text,
    required this.style,
    required this.painter,
  });

  final TextOffset start;
  final TextOffset end;
  final String text;
  final ResolvedStyle style;
  final TextPainter painter;
}
