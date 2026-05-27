import 'package:editor/src/model/buffer/line_index.dart';
import 'package:editor/src/model/buffer/piece_tree.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_edit.dart';

/// Изменяемый текстовый документ: буфер + индекс строк + монотонная версия.
///
/// ## Обязанности
///
/// - Хранит текст UTF-16 в [PieceTree].
/// - Поддерживает [LineIndex] для преобразования строка/столбец ↔ смещение.
/// - Увеличивает [version] после каждого успешного пакета [apply].
///
/// ## Политика изменений
///
/// Экземпляры создаются через [Document.fromText]. Внешний код должен менять
/// текст только через [Transaction] (команды, undo), который вызывает [apply].
/// Прямой доступ к буферу намеренно закрыт.
///
/// ## Пример (внутренний / тесты)
///
/// ```dart
/// final doc = Document.fromText('a\nb');
/// doc.apply([TextEdit.insert(1, 'X')]); // "aX\nb", version 1
/// doc.positionAt(2); // Position(0, 2)
/// ```
///
/// ## Ошибки
///
/// [lineStart], [getLineRange] делегируют [LineIndex] и выбрасывают [RangeError]
/// при неверных индексах строк. [apply] не проверяет пересечение правок — перекрывающиеся
/// диапазоны в одном пакете дают неопределённое состояние буфера; [Transaction] применяет правки
/// в заданном порядке.
final class Document {
  Document._(this._buffer, this._lineIndex, this._version);

  /// Создаёт документ из начального [text] (может быть пустым).
  factory Document.fromText(String text) {
    final buffer = PieceTree(text);
    return Document._(buffer, LineIndex.fromText(text), 0);
  }

  /// Текстовый буфер (piece table).
  final PieceTree _buffer;

  /// Индекс начал строк для position/offset.
  LineIndex _lineIndex;

  /// Монотонная версия, увеличивается в [apply].
  int _version;

  /// Увеличивается на единицу после каждого зафиксированного [apply] с непустыми правками.
  ///
  /// Хосты и [EditorLanguageService] используют это, чтобы игнорировать устаревшие async-результаты.
  int get version => _version;

  /// Длина документа в кодовых единицах UTF-16.
  int get length => _buffer.length;

  /// Число строк (всегда ≥ 1 для непустого текста; у пустого документа 1 строка).
  int get lineCount => _lineIndex.lineCount;

  /// Полный текст документа.
  String get text => _buffer.text;

  /// Возвращает полный [text] или подстроку для [range], если указан.
  ///
  /// Диапазон ограничивается [length], чтобы устаревший viewport после undo
  /// не приводил к [RangeError].
  String getText([Range? range]) {
    if (range == null) return text;
    final clamped = range.clampToLength(length);
    return _buffer.substring(clamped.start, clamped.end);
  }

  /// Локальный срез вокруг [offset] без материализации всего документа.
  ///
  /// Используется для подсветки скобок и слова у каретки. [margin] — число code units
  /// слева и справа от [offset].
  ({String text, int baseOffset}) textSliceAround(
    TextOffset offset, {
    int margin = 16384,
  }) {
    final len = length;
    if (len == 0) return (text: '', baseOffset: 0);
    final start = offset - margin;
    final end = offset + margin;
    final clampedStart = start < 0 ? 0 : start;
    final clampedEnd = end > len ? len : end;
    if (clampedStart >= clampedEnd) {
      return (text: '', baseOffset: clampedStart);
    }
    return (
      text: _buffer.substring(clampedStart, clampedEnd),
      baseOffset: clampedStart,
    );
  }

  /// UTF-16-смещение начала [line] (с нуля).
  ///
  /// Выбрасывает [RangeError], если `line` вне `[0, lineCount)`.
  int lineStart(int line) => _lineIndex.lineStart(line);

  /// Конечное смещение *содержимого* строки (без терминатора `\n` / `\r\n`).
  int lineContentEnd(int line) {
    final start = lineStart(line);
    final relativeEnd = _lineIndex.lineContentEnd(getText(getLineRange(line)));
    return start + relativeEnd;
  }

  /// Полуоткрытый диапазон, покрывающий всю логическую строку включая символы перевода строки.
  Range getLineRange(int line) {
    final start = _lineIndex.lineStart(line);
    final end = line + 1 < _lineIndex.lineCount
        ? _lineIndex.lineStart(line + 1)
        : length;
    return Range(start, end);
  }

  /// Преобразует плоское [offset] в [Position] (строка, столбец в единицах UTF-16).
  Position positionAt(TextOffset offset) =>
      _lineIndex.positionAt(offset, length);

  /// Преобразует [position] в плоское [TextOffset].
  TextOffset offsetAt(Position position) =>
      _lineIndex.offsetAt(position, length);

  /// Применяет [edits] за один атомарный шаг и возвращает сводку [DocumentChange].
  ///
  /// ## Алгоритм
  ///
  /// 1. **Агрегировать метаданные**: минимальный start, максимальный end, общая длина удаления, конкатенация вставленного текста.
  /// 2. **Применить правки буфера** с наибольшего смещения к меньшему, чтобы более ранние смещения оставались
  ///    валидными при удалении/вставке (стандартное пакетное применение в текстовых редакторах).
  /// 3. **Обновить** [LineIndex] инкрементально через [LineIndex.apply] для каждой правки.
  /// 4. **Увеличить** [version] и вычислить [DocumentChange.affectedLineRange] для инвалидации вёрстки.
  ///
  /// Пустой [edits] возвращает no-op-изменение с неизменённой [version].
  ///
  /// Используется [Transaction.commit] и undo/redo.
  ///
  /// По умолчанию правки сортируются от большего [TextEdit.range.start] к меньшему
  /// (все смещения относительно документа до пакета). Для redo объединённого набора
  /// typing/paste задайте [applyFromStartToEnd] — смещения накоплены по ходу серии.
  DocumentChange apply(
    List<TextEdit> edits, {
    bool applyFromStartToEnd = false,
  }) {
    if (edits.isEmpty) {
      return DocumentChange(
        range: const Range(0, 0),
        oldVersion: _version,
        newVersion: _version,
        affectedLineRange: const Range(0, 0),
        affectedFirstLine: 0,
        affectedLastLine: 0,
        insertedText: '',
        removedLength: 0,
      );
    }

    final oldVersion = _version;
    var minStart = edits.first.range.start;
    var maxEnd = edits.first.range.end;
    final inserted = StringBuffer();
    var removedTotal = 0;

    for (final edit in edits) {
      if (edit.range.start < minStart) minStart = edit.range.start;
      if (edit.range.end > maxEnd) maxEnd = edit.range.end;
      removedTotal += edit.range.length;
      inserted.write(edit.text);
    }

    final sorted = List<TextEdit>.of(edits)
      ..sort(
        (a, b) => applyFromStartToEnd
            ? a.range.start.compareTo(b.range.start)
            : b.range.start.compareTo(a.range.start),
      );

    for (final edit in sorted) {
      _buffer
        ..delete(edit.range.start, edit.range.end)
        ..insert(edit.range.start, edit.text);
      _lineIndex.apply(edit.range.start, edit.range.length, edit.text);
    }

    _version++;

    final newLen = _buffer.length;
    final editRange = Range(minStart, maxEnd);
    final affected = _lineIndex.affectedLineRange(editRange, newLen);
    final (firstLine, lastLine) = _lineIndex.affectedLines(editRange, newLen);

    return DocumentChange(
      range: editRange,
      oldVersion: oldVersion,
      newVersion: _version,
      affectedLineRange: affected,
      affectedFirstLine: firstLine,
      affectedLastLine: lastLine,
      insertedText: inserted.toString(),
      removedLength: removedTotal,
    );
  }
}
