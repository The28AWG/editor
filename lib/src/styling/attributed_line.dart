import 'package:editor/src/styling/attributed_run.dart';

/// Одна строка документа, разбитая на стилизованные [AttributedRun] для макета и отрисовки.
///
/// Создаётся [StyleResolver.attributedLine]. [documentStart] — смещение в буфере
/// первого code unit строки `[lineIndex, lineIndex+1)`.
final class AttributedLine {
  /// Создаёт атрибутированную строку с индексом, начальным смещением и прогонами.
  const AttributedLine({
    required this.lineIndex,
    required this.documentStart,
    required this.runs,
  });

  /// Индекс строки документа с нуля.
  final int lineIndex;

  /// Смещение в документе, где начинается эта строка.
  final int documentStart;

  /// Непрерывные стилизованные сегменты, покрывающие содержимое строки (может быть один прогон).
  final List<AttributedRun> runs;
}
