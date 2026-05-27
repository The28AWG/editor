/// Извлекает `[start, end)` из [text] по индексам **кодовых единиц UTF-16**.
///
/// ## Почему не `String.substring`
///
/// Для текста только BMP они эквивалентны. Этот хелпер используется согласованно с
/// [PieceTree] и [LineLayout], чтобы все слои согласовались с координатами LSP/редактора.
/// Также обрабатывает `start >= end` без исключения (возвращает `''`).
///
/// ## Безопасность суррогатов
///
/// Если [start] или [end] разрезает суррогатную пару, результат может содержать
/// изолированный high или low surrogate — невалидные Unicode-строки. Вызывающий код
/// должен выравнивать границы по краям пары (например, при отображении позиций LSP).
///
/// ## Пример
///
/// ```dart
/// sliceCodeUnits('a😀b', 1, 3); // middle code units of emoji (surrogate pair)
/// ```
String sliceCodeUnits(String text, int start, int end) {
  if (start >= end) return '';
  final buffer = StringBuffer();
  for (var i = start; i < end; i++) {
    buffer.writeCharCode(text.codeUnitAt(i));
  }
  return buffer.toString();
}
