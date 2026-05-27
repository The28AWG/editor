import 'package:editor/src/model/position.dart';

/// Одна визуальная строка после переноса по словам.
///
/// Одна строка [Document] может дать несколько [VisualLine], когда задан
/// [LineLayout.wrapWidth]. Каждая визуальная строка сопоставляет непрерывный фрагмент
/// текста документа с пиксельной геометрией через [documentStart], [documentEnd] и
/// [width].
///
/// ```dart
/// final layout = LineLayout(document: doc, resolver: resolver, ...);
/// for (final visual in layout.visualLinesForDocumentLine(0)) {
///   print('${visual.text} (${visual.width}px)');
/// }
/// ```
final class VisualLine {
  /// Создаёт визуальную строку, охватывающую `[documentStart, documentEnd)` в буфере.
  const VisualLine({
    required this.documentStart,
    required this.documentEnd,
    required this.text,
    required this.width,
  });

  /// Включительное начальное смещение в документе (индекс code unit).
  final TextOffset documentStart;

  /// Исключительное конечное смещение в документе (индекс code unit).
  final TextOffset documentEnd;

  /// Фрагмент текста для этой визуальной строки (может не включать завершающий `\n` строки документа).
  final String text;

  /// Горизонтальная протяжённость в пикселях (сумма ширин глифов или ширина макета с учётом inlay).
  final double width;

  /// Возвращает копию с выборочно заменёнными полями.
  VisualLine copyWith({
    TextOffset? documentStart,
    TextOffset? documentEnd,
    String? text,
    double? width,
  }) => VisualLine(
    documentStart: documentStart ?? this.documentStart,
    documentEnd: documentEnd ?? this.documentEnd,
    text: text ?? this.text,
    width: width ?? this.width,
  );
}
