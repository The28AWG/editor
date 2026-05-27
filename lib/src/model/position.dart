/// Плоское смещение в буфере документа, измеряемое в **кодовых единицах UTF-16**.
///
/// Та же конвенция, что и у:
/// - индексов Dart `String` и `TextRange`
/// - LSP `Position.character` и `Range` во многих language server
///
/// **Суррогатные пары**: одна Unicode-скалярная величина выше U+FFFF занимает два шага
/// [TextOffset]. Не вставляйте каретку между high и low surrogate без осторожности.
typedef TextOffset = int;

/// Адрес строки/столбца в документе.
///
/// [line] с нуля. [column] тоже в кодовых единицах UTF-16 от начала строки
/// (не графемные кластеры и не колонки отображения).
///
/// ## Пример
///
/// Для текста `"ab\nc"`:
/// - `Position(0, 2)` → смещение 2 (перед `\n`)
/// - `Position(1, 1)` → смещение 4 (`c`)
///
/// Преобразование через [Document.positionAt] / [Document.offsetAt].
final class Position implements Comparable<Position> {
  const Position(this.line, this.column);

  /// Индекс строки документа с нуля.
  final int line;

  /// Смещение в code units UTF-16 от начала строки (не экранные колонки).
  final int column;

  @override
  int compareTo(Position other) {
    final lineCmp = line.compareTo(other.line);
    if (lineCmp != 0) return lineCmp;
    return column.compareTo(other.column);
  }

  @override
  bool operator ==(Object other) =>
      other is Position && line == other.line && column == other.column;

  @override
  int get hashCode => Object.hash(line, column);

  @override
  String toString() => 'Position($line, $column)';
}

/// Полуоткрытый интервал `[start, end)` в пространстве [TextOffset].
///
/// - [isEmpty], когда `start >= end`
/// - [length] равен `end - start` (может быть 0)
/// - [contains] проверяет `start <= offset < end`
///
/// ## Примеры
///
/// ```dart
/// const r = Range(3, 7); // four code units
/// r.contains(3); // true
/// r.contains(7); // false (end exclusive)
/// ```
///
/// Используется в [TextEdit], [Selection], [DocumentChange], подсветке и диагностике.
final class Range {
  const Range(this.start, this.end);

  final TextOffset start;
  final TextOffset end;

  /// Истина, если диапазон не охватывает кодовых единиц.
  bool get isEmpty => start >= end;

  /// Число кодовых единиц UTF-16 в диапазоне.
  int get length => end - start;

  /// Лежит ли [offset] внутри `[start, end)`.
  bool contains(TextOffset offset) => offset >= start && offset < end;

  /// Попадает ли [position] (с [lineStart] для этой строки) в диапазон.
  bool containsPosition(Position position, int lineStart) {
    final offset = lineStart + position.column;
    return offset >= start && offset < end;
  }

  /// Пересечение двух диапазонов; может быть пустым.
  Range intersect(Range other) {
    final s = start > other.start ? start : other.start;
    final e = end < other.end ? end : other.end;
    return Range(s, e < s ? s : e);
  }

  /// Ограничивает `[start, end)` смещениями документа `[0, length]`.
  Range clampToLength(int length) {
    var s = start;
    var e = end;
    if (s < 0) s = 0;
    if (e < 0) e = 0;
    if (s > length) s = length;
    if (e > length) e = length;
    if (e < s) e = s;
    return Range(s, e);
  }

  @override
  bool operator ==(Object other) =>
      other is Range && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Range($start, $end)';
}

/// К какой стороне границы графемы/кластера «прилипает» каретка при неоднозначности.
///
/// Используется при hit-testing переносимых строк: на границе мягкого переноса
/// **upstream** ассоциируется с концом предыдущей визуальной строки; **downstream** —
/// с началом следующей.
///
/// См. [LineLayout.getOffsetAtPoint].
enum TextAffinity {
  /// Смещение каретки к более раннему тексту (например, конец предыдущей визуальной строки).
  upstream,

  /// Смещение каретки к более позднему тексту (по умолчанию для переносимых многострочных строк).
  downstream,
}
