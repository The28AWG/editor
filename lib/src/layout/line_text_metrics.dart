import 'dart:math' as math;

import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/resolved_style.dart';
import 'package:flutter/painting.dart';

/// Вертикальные границы стилизованных прогонов на одной визуальной строке.
///
/// Все прогоны разделяют [lineBaselineY]; каждый рисуется на
/// `lineBaselineY - runAscent`. [blockHeight] — объединение прямоугольников прогонов и
/// используется для размещения текста внутри ячейки строки документа (`lineHeightPx`).
///
/// Пользовательские глифы (например, лигатуры, где `=>` рисуется одной формой,
/// но остаётся двумя code unit'ами в буфере) могут использовать те же метрики: разместите
/// оверлей через [TextPainter] или отрисовку [Canvas], затем включите его в [LineTextMetrics.fromPainters]
/// или вручную расширьте [maxAscent]/[maxDescent] перед [contentTop].
///
/// ```dart
/// final metrics = LineTextMetrics.fromTheme(theme);
/// final top = metrics.contentTop(lineTop, lineHeightPx, theme.lineVerticalAlign);
/// final baseline = metrics.lineBaselineY(top);
/// ```
final class LineTextMetrics {
  /// Создаёт метрики из предвычисленных значений ascent и descent.
  const LineTextMetrics({
    required this.maxAscent,
    required this.maxDescent,
    required this.maxPainterHeight,
  });

  /// Вычисляет метрики как максимум ascent, descent и height среди [painters].
  ///
  /// Возвращает нулевые метрики, когда [painters] пуст.
  factory LineTextMetrics.fromPainters(List<TextPainter> painters) {
    if (painters.isEmpty) {
      return const LineTextMetrics(
        maxAscent: 0,
        maxDescent: 0,
        maxPainterHeight: 0,
      );
    }

    var maxAscent = 0.0;
    var maxDescent = 0.0;
    var maxPainterHeight = 0.0;

    for (final painter in painters) {
      final ascent = runAlphabeticAscent(painter);
      final descent = painter.height - ascent;
      if (ascent > maxAscent) maxAscent = ascent;
      if (descent > maxDescent) maxDescent = descent;
      if (painter.height > maxPainterHeight) {
        maxPainterHeight = painter.height;
      }
    }

    return LineTextMetrics(
      maxAscent: maxAscent,
      maxDescent: maxDescent,
      maxPainterHeight: maxPainterHeight,
    );
  }

  /// Оценивает метрики, размещая `'Mg'` с [style].
  ///
  /// Использует типичную пару ascender/descender для согласованного размещения строк.
  factory LineTextMetrics.fromTextStyle(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Mg', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return LineTextMetrics.fromPainters([painter]);
  }

  /// Сокращение для [fromTextStyle] с параметрами шрифта [EditorTheme].
  factory LineTextMetrics.fromTheme(EditorTheme theme) =>
      LineTextMetrics.fromTextStyle(
        TextStyle(
          fontSize: theme.fontSize,
          fontFamily: theme.fontFamily,
          fontWeight: theme.fontWeight,
          fontStyle: theme.fontStyle,
        ),
      );

  /// Максимальное расстояние от верха макета до алфавитной baseline среди прогонов.
  final double maxAscent;

  /// Максимальное расстояние от алфавитной baseline до низа макета среди прогонов.
  final double maxDescent;

  /// Максимальный [TextPainter.height] среди прогонов (>= [blockHeight]).
  final double maxPainterHeight;

  /// Общая вертикальная протяжённость текстового блока (`maxAscent + maxDescent`).
  double get blockHeight => maxAscent + maxDescent;

  /// Верх текстового блока внутри ячейки строки документа.
  ///
  /// [lineTop] — верх ячейки; [lineHeightPx] — полная высота ячейки.
  /// [align] задаёт, располагается ли текст у верха, по центру или у низа ячейки.
  double contentTop(
    double lineTop,
    double lineHeightPx,
    EditorLineVerticalAlign align,
  ) => switch (align) {
    EditorLineVerticalAlign.top => lineTop,
    EditorLineVerticalAlign.center =>
      lineTop + (lineHeightPx - blockHeight) / 2,
    EditorLineVerticalAlign.bottom => lineTop + lineHeightPx - blockHeight,
  };

  /// Общая алфавитная baseline Y для каждого прогона на строке.
  ///
  /// [contentTop] получается из [contentTop]; добавьте [maxAscent], чтобы достичь baseline.
  double lineBaselineY(double contentTop) => contentTop + maxAscent;
}

/// Преобразует [ResolvedStyle] во Flutter [TextStyle] (как при отрисовке строк).
TextStyle textStyleForResolvedStyle(ResolvedStyle style) {
  final hasUnderline = style.underline || style.wavyUnderline;
  return TextStyle(
    color: style.color,
    fontSize: style.fontSize,
    fontFamily: style.fontFamily,
    fontWeight: style.fontWeight,
    fontStyle: style.fontStyle,
    decoration: hasUnderline ? TextDecoration.underline : TextDecoration.none,
    decorationStyle: style.wavyUnderline
        ? TextDecorationStyle.wavy
        : TextDecorationStyle.solid,
    decorationColor: style.underlineColor ?? style.color,
    backgroundColor: style.backgroundColor.a > 0 ? style.backgroundColor : null,
  );
}

/// Создаёт размещённый [TextPainter] для одного атрибутированного прогона.
///
/// Использует направление LTR; вызывающий код не должен переиспользовать painter
/// после смены шрифта без повторного layout.
TextPainter layoutRunPainter({
  required String text,
  required TextStyle style,
}) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
)..layout();

/// Ascent от верха макета до алфавитной baseline для [painter].
///
/// Требует предварительного вызова [painter.layout].
double runAlphabeticAscent(TextPainter painter) =>
    painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

/// Смещение отрисовки, при котором baseline [painter] совпадает с [lineBaselineY].
///
/// Возвращает `Offset(x, lineBaselineY - ascent)`, чтобы все прогоны выровнялись по одной baseline.
Offset runPaintOffset(TextPainter painter, double x, double lineBaselineY) =>
    Offset(x, lineBaselineY - runAlphabeticAscent(painter));

/// Наибольшая высота блока среди [metrics] и дополнительных painters (пользовательские глифы).
///
/// Объединяет, беря максимум по каждому полю из [metrics] и метрик,
/// полученных из [extraPainters]. Возвращает [metrics] без изменений, если [extraPainters] пуст.
LineTextMetrics mergeMetrics(
  LineTextMetrics metrics,
  List<TextPainter> extraPainters,
) {
  if (extraPainters.isEmpty) return metrics;
  final merged = LineTextMetrics.fromPainters(extraPainters);
  return LineTextMetrics(
    maxAscent: math.max(metrics.maxAscent, merged.maxAscent),
    maxDescent: math.max(metrics.maxDescent, merged.maxDescent),
    maxPainterHeight: math.max(
      metrics.maxPainterHeight,
      merged.maxPainterHeight,
    ),
  );
}
