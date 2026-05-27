import 'package:editor/src/model/position.dart';

/// Индекс смещений начала строк в документе UTF-16.
///
/// ## Переводы строк
///
/// Распознаваемые последовательности (как во многих редакторах):
/// - `\n` (LF)
/// - `\r` (CR отдельно)
/// - `\r\n` (CRLF) — считается одним переводом; индекс сдвигается на обе кодовые единицы
///
/// ## Использование
///
/// Принадлежит [Document]. После правки вызывайте [apply] (инкрементально) или
/// [rebuild] (полное пересканирование). Для запросов только на чтение —
/// [lineStart], [positionAt], [offsetAt].
///
/// ## Пустой документ
///
/// [lineCount] равен 1 с единственным началом в 0; [positionAt] отображает смещение 0 в
/// `Position(0, 0)`.
///
/// ## Ошибки
///
/// - [lineStart], [offsetAt]: [RangeError] при неверной строке или смещении за концом документа.
/// - [positionAt]: [RangeError], если `offset` ∉ `[0, documentLength]`.
final class LineIndex {
  LineIndex._(this._lineStarts);

  /// Один раз сканирует [text] и записывает UTF-16-смещение первого символа каждой строки.
  factory LineIndex.fromText(String text) {
    final starts = <int>[0];
    _scanNewlines(text, 0, (lineStart) => starts.add(lineStart));
    return LineIndex._(starts);
  }

  List<int> _lineStarts;

  /// Число строк (не меньше 1).
  int get lineCount => _lineStarts.length;

  /// Смещение в документе, где начинается [line].
  ///
  /// Выбрасывает [RangeError], если `line < 0` или `line >= lineCount`.
  int lineStart(int line) {
    if (line < 0 || line >= _lineStarts.length) {
      throw RangeError.range(line, 0, _lineStarts.length - 1, 'line');
    }
    return _lineStarts[line];
  }

  /// Индекс строки, содержащей [offset] (бинарный поиск).
  int lineIndexAt(TextOffset offset) {
    var lo = 0;
    var hi = _lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Конечное смещение *содержимого* строки (без завершающих `\r`/`\n`).
  ///
  /// Алгоритм: взять сырой конец строки из начала следующей (или EOF), затем убрать
  /// одну или две кодовые единицы терминатора, если они есть.
  /// [lineText] — срез одной логической строки (как [Document.getText] для [getLineRange]).
  int lineContentEnd(String lineText) {
    var end = lineText.length;
    if (end == 0) return 0;
    if (end >= 2 &&
        lineText.codeUnitAt(end - 2) == 0x0D &&
        lineText.codeUnitAt(end - 1) == 0x0A) {
      return end - 2;
    }
    final last = lineText.codeUnitAt(end - 1);
    if (last == 0x0A || last == 0x0D) return end - 1;
    return end;
  }

  /// Заменяет начала строк после правки документа (полное пересканирование).
  void rebuild(String text) {
    _lineStarts = LineIndex.fromText(text)._lineStarts;
  }

  /// Обновляет индекс после замены `[editStart, editEnd)` на [inserted].
  ///
  /// Не материализует весь документ — только сканирует [inserted] и сдвигает хвост.
  void apply(int editStart, int removedLength, String inserted) {
    final editEnd = editStart + removedLength;
    final delta = inserted.length - removedLength;

    final newStarts = <int>[];

    // Фаза 1: начала строк, полностью левее правки — без изменений.
    for (final off in _lineStarts) {
      if (off < editStart) {
        newStarts.add(off);
      }
    }

    // Фаза 2: начало строки, содержащей editStart, плюс новые \n внутри [inserted].
    final lineAtEdit = lineIndexAt(editStart);
    final lineStartAtEdit = _lineStarts[lineAtEdit];
    if (lineStartAtEdit <= editStart &&
        (newStarts.isEmpty || newStarts.last != lineStartAtEdit)) {
      newStarts.add(lineStartAtEdit);
    }

    _scanNewlines(inserted, editStart, newStarts.add);

    // Фаза 3: хвост документа правее editEnd сдвигается на delta вставки/удаления.
    // Строго `> editEnd`: начало строки ровно на [editEnd] исчезает, если удалён `\n` перед ним.
    for (final off in _lineStarts) {
      if (off > editEnd) {
        newStarts.add(off + delta);
      }
    }

    if (newStarts.isEmpty) {
      newStarts.add(0);
    }

    _lineStarts = newStarts;
  }

  /// Преобразует плоское [offset] в [Position] (бинарный поиск по [_lineStarts]).
  Position positionAt(TextOffset offset, int documentLength) {
    if (offset < 0 || offset > documentLength) {
      throw RangeError.range(offset, 0, documentLength, 'offset');
    }
    if (documentLength == 0) {
      return const Position(0, 0);
    }
    final line = lineIndexAt(offset);
    return Position(line, offset - _lineStarts[line]);
  }

  /// Преобразует [position] в плоское смещение.
  ///
  /// Выбрасывает исключение, если строка неверна или `lineStart + column > documentLength`.
  TextOffset offsetAt(Position position, int documentLength) {
    if (position.line < 0 || position.line >= _lineStarts.length) {
      throw RangeError.range(position.line, 0, _lineStarts.length - 1, 'line');
    }
    final offset = _lineStarts[position.line] + position.column;
    if (offset > documentLength) {
      throw RangeError.range(offset, 0, documentLength);
    }
    return offset;
  }

  /// Диапазон смещений в документе, покрывающий все строки, затронутые правкой.
  ///
  /// Используется [DocumentChange], чтобы [LineLayout] мог инвалидировать с первой
  /// затронутой строки. Ограничивает концы правки, когда документ уменьшается.
  Range affectedLineRange(Range editRange, int newLength) {
    if (newLength == 0) return const Range(0, 0);

    final startOffset = editRange.start.clamp(0, newLength - 1);
    final endOffset = editRange.end <= 0
        ? 0
        : (editRange.end - 1).clamp(0, newLength - 1);

    final startLine = positionAt(startOffset, newLength).line;
    final endLine = positionAt(endOffset, newLength).line;
    final lineStartOffset = _lineStarts[startLine];
    final lineEndOffset = endLine + 1 < _lineStarts.length
        ? _lineStarts[endLine + 1]
        : newLength;
    return Range(lineStartOffset, lineEndOffset);
  }

  /// Первая и последняя (включительно) строки документа, затронутые правкой [editRange].
  (int firstLine, int lastLine) affectedLines(Range editRange, int newLength) {
    if (newLength == 0) return (0, 0);
    final startOffset = editRange.start.clamp(0, newLength - 1);
    final endOffset = editRange.end <= 0
        ? startOffset
        : (editRange.end - 1).clamp(0, newLength - 1);
    final first = positionAt(startOffset, newLength).line;
    final last = positionAt(endOffset, newLength).line;
    return (first, last);
  }

  static void _scanNewlines(
    String text,
    int baseOffset,
    void Function(int lineStart) onLineStart,
  ) {
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code == 0x0A) {
        onLineStart(baseOffset + i + 1);
      } else if (code == 0x0D) {
        if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A) {
          i++;
        }
        onLineStart(baseOffset + i + 1);
      }
    }
  }
}
