import 'package:flutter/painting.dart';

/// Кэшированные ширины глифов для каждого code unit из [TextPainter].
///
/// Используется [LineLayout] для hit-testing, переноса и измерения при отсутствии inlay.
/// Ширины измеряются с фиксированными [fontFamily] и [fontSize];
/// вызывайте [clear] после смены шрифта.
///
/// ```dart
/// final cache = GlyphCache(fontFamily: 'monospace', fontSize: 16);
/// final w = cache.charWidth('A'.codeUnitAt(0));
/// final lineWidth = cache.measureText('hello');
/// ```
///
/// **Граничные случаи:** [measureText] возвращает `0` для пустых строк. Суррогатные
/// пары измеряются как два отдельных code unit'а, что соответствует модели индексации
/// code unit'ов редактора.
final class GlyphCache {
  /// Создаёт кэш для заданных метрик шрифта.
  GlyphCache({
    required this.fontFamily,
    required this.fontSize,
    this.devicePixelRatio = 1,
  });

  /// Семейство шрифта, передаваемое в [TextPainter] при измерении глифов.
  final String fontFamily;

  /// Размер шрифта в логических пикселях.
  final double fontSize;

  /// Соотношение пикселей устройства (зарезервировано для будущего субпиксельного выравнивания).
  double devicePixelRatio;

  /// [TextStyle], используемый для всех измерений в этом кэше.
  TextStyle get textStyle =>
      TextStyle(fontFamily: fontFamily, fontSize: fontSize);

  /// Ширина одного UTF-16 code unit, кэшируется после первого обращения.
  ///
  /// Размещает один символ с [textStyle] через [TextPainter.layout].
  double charWidth(int codeUnit) {
    final cached = _widthCache[codeUnit];
    if (cached != null) return cached;

    final painter = TextPainter(
      text: TextSpan(text: String.fromCharCode(codeUnit), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    _widthCache[codeUnit] = width;
    return width;
  }

  /// Сумма [charWidth] для каждого code unit в [text].
  ///
  /// Возвращает `0`, когда [text] пуст.
  double measureText(String text) {
    if (text.isEmpty) return 0;
    var width = 0.0;
    for (var i = 0; i < text.length; i++) {
      width += charWidth(text.codeUnitAt(i));
    }
    return width;
  }

  final Map<int, double> _widthCache = {};

  /// Очищает внутренний кэш ширин (например, после смены шрифта или DPR).
  void clear() => _widthCache.clear();
}
