import 'package:editor/src/model/position.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Декоративная «рамка вокруг текста» для непрерывного [range] документа.
///
/// В отличие от выделения каретки ([SelectionState]) и диагностики, блок —
/// это чисто визуальный слой: он не меняет текст, не двигает каретку и не
/// участвует в hit-test. Редактор рисует его поверх текста как **ступенчатый
/// контур**, повторяющий фактическую ширину каждой строки диапазона, с
/// необязательной заливкой той же формы.
///
/// ## Несколько блоков на одной строке
///
/// Каждый [EditorRegionBlock] отрисовывается независимо по собственному
/// контуру, поэтому на одной строке может лежать несколько блоков, а их
/// рамки и заливки **не сливаются** в сплошную область — между соседними
/// блоками остаётся незакрашенный зазор.
///
/// ## Пример
///
/// ```dart
/// controller.setRegionBlocks([
///   EditorRegionBlock(
///     range: Range(10, 45),
///     borderColor: const Color(0xFF4C8BF5),
///     fillColor: const Color(0x224C8BF5),
///   ),
/// ]);
/// ```
@immutable
final class EditorRegionBlock {
  /// Создаёт блок для непрерывного [range].
  ///
  /// [range] использует смещения code unit UTF-16, согласованные с [Document].
  /// Многострочный диапазон даёт ступенчатый контур; [fillColor] равный `null`
  /// рисует только рамку.
  const EditorRegionBlock({
    required this.range,
    this.borderColor,
    this.fillColor,
    this.id,
  });

  /// Непрерывный диапазон документа, который обрамляет блок.
  final Range range;

  /// Цвет линии рамки.
  ///
  /// Если `null`, используется [EditorTheme.regionBlockBorderColor].
  final Color? borderColor;

  /// Цвет заливки формы блока или `null`, чтобы рисовать только рамку.
  final Color? fillColor;

  /// Необязательный идентификатор для сопоставления/обновления блоков хостом.
  final Object? id;

  @override
  bool operator ==(Object other) =>
      other is EditorRegionBlock &&
      range == other.range &&
      borderColor == other.borderColor &&
      fillColor == other.fillColor &&
      id == other.id;

  @override
  int get hashCode => Object.hash(range, borderColor, fillColor, id);

  @override
  String toString() =>
      'EditorRegionBlock(range: $range, border: $borderColor, '
      'fill: $fillColor, id: $id)';
}
