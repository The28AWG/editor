import 'package:editor/src/model/position.dart';

/// Сводка зафиксированного изменения документа.
///
/// Генерируется [Document.apply] и распространяется через [Transaction] в
/// [EditorController._afterChange] и [EditorHost.onDocumentChanged].
///
/// ## Поля
///
/// - [range]: объединение всех диапазонов правок в транзакции (в координатах **до правки**
///   для границ start/end; точная семантика — в [Document.apply])
/// - [oldVersion] / [newVersion]: [Document.version] до и после
/// - [affectedLineRange]: диапазон смещений документа, покрывающий каждую строку, пересекающуюся
///   с правкой — используйте для инвалидации [LineLayout] с индекса строки
/// - [affectedFirstLine] / [affectedLastLine]: индексы строк (включительно) для [LineLayout.invalidate]
/// - [insertedText]: конкатенация всех `TextEdit.text` в порядке применения
/// - [removedLength]: всего удалено кодовых единиц UTF-16 по всем правкам
///
/// ## Пример
///
/// После ввода `x` в смещении 0:
/// - `insertedText == 'x'`, `removedLength == 0`, `newVersion == oldVersion + 1`
final class DocumentChange {
  const DocumentChange({
    required this.range,
    required this.oldVersion,
    required this.newVersion,
    required this.affectedLineRange,
    required this.affectedFirstLine,
    required this.affectedLastLine,
    required this.insertedText,
    required this.removedLength,
  });

  /// Ограничивающий диапазон пакета правок в системе координат документа на момент фиксации.
  final Range range;

  /// [Document.version] до применения.
  final int oldVersion;

  /// [Document.version] после применения.
  final int newVersion;

  /// Диапазон смещений, охватывающий все затронутые строки (для инкрементальной вёрстки).
  final Range affectedLineRange;

  /// Первая затронутая строка документа (включительно).
  final int affectedFirstLine;

  /// Последняя затронутая строка документа (включительно).
  final int affectedLastLine;

  /// Весь вставленный текст транзакции, объединённый.
  final String insertedText;

  /// Общая длина удалённых фрагментов.
  final int removedLength;
}
