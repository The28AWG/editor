import 'package:editor/src/model/position.dart';

/// Одна операция замены: удалить полуоткрытый диапазон [range) и вставить [text].
///
/// ## Семантика
///
/// Эквивалентно: `document[range.start:range.end] = text`
///
/// [delta] — чистое изменение длины документа: `text.length - range.length`.
///
/// ## Фабрики
///
/// ```dart
/// TextEdit.insert(5, 'hi');           // insert at offset
/// TextEdit.delete(Range(1, 4));       // delete range
/// TextEdit.replace(Range(0, 1), 'Z'); // replace first char
/// ```
///
/// ## Пакетирование
///
/// [Transaction] и [Document.apply] могут применить несколько правок за одну
/// транзакцию. Смещения в последующих правках относятся к документу **до** пакета
/// при передаче в [Document.apply] (который сортирует по убыванию перед применением).
///
/// ## Ошибки
///
/// [TextEdit] сам не проверяет диапазоны. Неверные смещения проявляются как
/// [RangeError] из [PieceTree] при применении правки.
final class TextEdit {
  const TextEdit(this.range, this.text);

  /// Заменить [range] на [text].
  factory TextEdit.replace(Range range, String text) => TextEdit(range, text);

  /// Вставить [text] в [offset] (диапазон нулевой длины).
  factory TextEdit.insert(TextOffset offset, String text) =>
      TextEdit(Range(offset, offset), text);

  /// Удалить [range] (пустая замена).
  factory TextEdit.delete(Range range) => TextEdit(range, '');

  /// Область для удаления перед вставкой [text].
  final Range range;

  /// Строка замены UTF-16 (может быть пустой при чистом удалении).
  final String text;

  /// Чистое изменение длины после применения этой правки.
  int get delta => text.length - range.length;
}
