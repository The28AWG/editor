import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/inlay/inlay_hint_style.dart';
import 'package:editor/src/layout/glyph_cache.dart';
import 'package:editor/src/layout/line_text_metrics.dart';
import 'package:editor/src/layout/styled_run_layout.dart';
import 'package:editor/src/layout/visual_line.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:flutter/painting.dart';

/// Сопоставляет смещения документа с горизонтальными координатами layout при наличии inlay.
///
/// Inlay hints резервируют ширину на отрисованной строке, не сдвигая значения
/// [TextOffset] документа. Этот класс обеспечивает двустороннее преобразование:
///
/// - [layoutX] — смещение документа → X-позиция с учётом резервов inlay.
/// - [offsetAtLayoutX] — X-позиция → ближайшее смещение документа (hit-testing).
///
/// ## Алгоритм ([layoutX])
///
/// Обход hints по порядку якорей на [VisualLine]:
/// 1. Измерить текст от cursor до следующего якоря hint или целевого смещения.
/// 2. Если достигнуто целевое смещение, вернуть накопленный X.
/// 3. Иначе добавить [inlayWidth] и продолжить с якоря hint.
///
/// Смещения документа не изменяются — растёт только X для отрисовки/hit-test.
final class InlayLayoutMetrics {
  /// Создаёт метрики для списка [inlays] и [glyphCache] измерений.
  InlayLayoutMetrics({
    required this.glyphCache,
    required this.theme,
    required this.inlays,
    required this.styledLayout,
  });

  /// Кэш ширины символов, общий с line layout.
  final GlyphCache glyphCache;

  /// Hit-test / layout X с учётом style runs (как отрисовка).
  final StyledRunLayout styledLayout;

  /// Тема для размера шрифта и цветов hint.
  final EditorTheme theme;

  /// Все inlay hints для текущего прохода layout.
  final List<EditorInlayHint> inlays;

  /// Возвращает hints, чей [EditorInlayHint.anchorOffset] попадает в [visual].
  ///
  /// Hints строго до [visual.documentStart] или после [visual.documentEnd]
  /// исключаются. Результат отсортирован по возрастанию смещения якоря.
  List<EditorInlayHint> hintsForVisual(VisualLine visual) {
    if (inlays.isEmpty) return const [];
    final result = <EditorInlayHint>[];
    for (final hint in inlays) {
      if (hint.anchorOffset < visual.documentStart) continue;
      if (hint.anchorOffset > visual.documentEnd) continue;
      result.add(hint);
    }
    result.sort((a, b) => a.anchorOffset.compareTo(b.anchorOffset));
    return result;
  }

  /// Полная горизонтальная ширина, зарезервированная для [hint] (padding + label + padding).
  double inlayWidth(EditorInlayHint hint) {
    final painter = layoutRunPainter(
      text: hint.label,
      style: TextStyle(
        color: inlayHintColor(hint.kind, theme),
        fontSize: theme.fontSize * 0.9,
        fontFamily: theme.fontFamily,
        fontStyle: FontStyle.italic,
      ),
    );
    return hint.paddingLeft + painter.width + hint.paddingRight;
  }

  /// Преобразует смещение документа [offset] на [visual] в layout X (пиксели от начала строки).
  ///
  /// [offset] ограничивается диапазоном `[visual.documentStart, visual.documentEnd]`.
  /// Ширины inlay между [cursor] и [offset] включаются в сумму.
  double layoutX(int lineIndex, VisualLine visual, TextOffset offset) {
    final clamped = _clampOffset(visual, offset);
    final hints = hintsForVisual(visual);
    var x = 0.0;
    var cursor = visual.documentStart;

    for (final hint in hints) {
      if (clamped <= hint.anchorOffset) {
        return x + _measureSlice(lineIndex, visual, cursor, clamped);
      }
      x += _measureSlice(lineIndex, visual, cursor, hint.anchorOffset);
      x += inlayWidth(hint);
      cursor = hint.anchorOffset;
    }
    return x + _measureSlice(lineIndex, visual, cursor, clamped);
  }

  /// Обратное к [layoutX]: сопоставляет горизонтальный [x] со смещением документа на [visual].
  ///
  /// Если [x] попадает в зарезервированную ширину inlay, возвращает
  /// [EditorInlayHint.anchorOffset] hint. Возвращает [visual.documentStart] при `x <= 0`.
  TextOffset offsetAtLayoutX(int lineIndex, VisualLine visual, double x) {
    if (x <= 0) return visual.documentStart;

    final hints = hintsForVisual(visual);
    var layout = 0.0;
    var cursor = visual.documentStart;

    for (final hint in hints) {
      final textW = _measureSlice(lineIndex, visual, cursor, hint.anchorOffset);
      if (x < layout + textW) {
        return _offsetInTextSlice(
          lineIndex,
          visual,
          cursor,
          hint.anchorOffset,
          x - layout,
        );
      }
      layout += textW;

      // Клик по «пустому» месту inlay → каретка на якорь hint, не между символами.
      final inlayW = inlayWidth(hint);
      if (x < layout + inlayW) return hint.anchorOffset;
      layout += inlayW;
      cursor = hint.anchorOffset;
    }

    final tail = visual.documentEnd - cursor;
    if (tail <= 0) return visual.documentEnd;
    return _offsetInTextSlice(
      lineIndex,
      visual,
      cursor,
      visual.documentEnd,
      x - layout,
    );
  }

  /// [localX] — пиксели от начала сегмента `[sliceStart, sliceEnd)` (без ширины inlay).
  TextOffset _offsetInTextSlice(
    int lineIndex,
    VisualLine visual,
    TextOffset sliceStart,
    TextOffset sliceEnd,
    double localX,
  ) {
    if (localX <= 0) return sliceStart;
    final sliceWidth = _measureSlice(lineIndex, visual, sliceStart, sliceEnd);
    if (localX >= sliceWidth) return sliceEnd;

    final styledBase = styledLayout.layoutX(lineIndex, visual, sliceStart);
    return styledLayout.offsetAtLayoutX(lineIndex, visual, styledBase + localX);
  }

  /// Ширина `[start, end)` с учётом style runs.
  double _measureSlice(
    int lineIndex,
    VisualLine visual,
    TextOffset start,
    TextOffset end,
  ) {
    if (end <= start) return 0;
    return styledLayout.layoutX(lineIndex, visual, end) -
        styledLayout.layoutX(lineIndex, visual, start);
  }

  /// Ограничивает [offset] включительным диапазоном документа [visual].
  TextOffset _clampOffset(VisualLine visual, TextOffset offset) {
    if (offset < visual.documentStart) return visual.documentStart;
    if (offset > visual.documentEnd) return visual.documentEnd;
    return offset;
  }
}
