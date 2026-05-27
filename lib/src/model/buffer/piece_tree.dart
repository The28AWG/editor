import 'package:editor/src/model/text_code_units.dart';

/// Какой физический буфер использует [_Piece].
enum _BufferKind {
  /// Неизменяемый снимок при создании (аргумент конструктора [PieceTree]).
  original,

  /// Буфер только для добавления — все правки после загрузки.
  add,
}

/// Непрерывный фрагмент в [_BufferKind.original] или [_BufferKind.add].
final class _Piece {
  const _Piece(this.kind, this.start, this.length);

  final _BufferKind kind;

  /// Начальное смещение в выбранном буфере (кодовые единицы UTF-16).
  final int start;

  /// Длина фрагмента в кодовых единицах UTF-16.
  final int length;
}

/// Редактируемый текстовый буфер на основе **таблицы фрагментов** (piece table, также piece chain).
///
/// ## Зачем таблица фрагментов
///
/// Классические редакторы сохраняют исходный файл неизменным и добавляют новый текст
/// в отдельный буфер. Логический текст документа — это последовательность *фрагментов*,
/// каждый из которых указывает на подстроку `original` или `add`. Вставки и удаления
/// лишь перестраивают фрагменты — они не копируют весь документ, поэтому правки
/// больших файлов остаются дешёвыми.
///
/// ## Система координат
///
/// Все смещения измеряются в **кодовых единицах UTF-16**, согласованно с [Document],
/// LSP и Flutter `TextRange`. Суррогатные пары (эмодзи, часть CJK в UTF-16) считаются
/// за две единицы при некорректном разрезе — вызывающий код не должен разрезать пару
/// посередине.
///
/// ## Типичное использование
///
/// ```dart
/// final tree = PieceTree('hello');
/// tree.insert(5, ' world'); // "hello world"
/// tree.delete(5, 11);       // back to "hello"
/// ```
///
/// [Document] владеет [PieceTree]; код хоста должен изменять текст через [Transaction],
/// а не напрямую через [PieceTree].
///
/// ## Ошибки
///
/// - [substring], [insert] (при `allowEnd == false`) и [delete] выбрасывают
///   [RangeError], если смещения выходят за `[0, length]` (или за конец при insert).
/// - Пустая вставка/удаление — no-op и не выбрасывает исключений.
///
/// См. также: [LineIndex], [Document.apply].
final class PieceTree {
  /// Создаёт дерево, в котором начальное содержимое целиком находится в буфере **original**.
  PieceTree(String initial)
    : _original = initial,
      _pieces = initial.isEmpty
          ? <_Piece>[]
          : <_Piece>[_Piece(_BufferKind.original, 0, initial.length)];

  final String _original;
  final StringBuffer _add = StringBuffer();

  /// Упорядоченная цепочка фрагментов, составляющих логический текст.
  List<_Piece> _pieces;

  /// Общая длина документа в кодовых единицах UTF-16.
  int get length {
    var total = 0;
    for (final p in _pieces) {
      total += p.length;
    }
    return total;
  }

  /// Полный логический текст (материализует все фрагменты).
  ///
  /// Предпочитайте [substring], если нужен только диапазон — [text] выделяет новую строку
  /// для всего документа.
  String get text => toString();

  /// Возвращает `[start, end)`, обходя фрагменты и конкатенируя срезы.
  ///
  /// Алгоритм:
  /// 1. Пропускать целые фрагменты, пока `pieceEnd > start`.
  /// 2. Для первого пересекающегося фрагмента читать с `localStart = max(0, start - offset)`.
  /// 3. Для последнего фрагмента читать до `localEnd = min(piece.length, end - offset)`.
  ///
  /// Выбрасывает [RangeError], если `start < 0`, `end < start` или `end > length`.
  String substring(int start, int end) {
    if (start < 0 || end < start || end > length) {
      throw RangeError.range(end, start, length, 'end');
    }
    if (start == end) return '';
    final buffer = StringBuffer();
    var offset = 0;
    for (final piece in _pieces) {
      final pieceEnd = offset + piece.length;
      if (pieceEnd <= start) {
        offset = pieceEnd;
        continue;
      }
      if (offset >= end) break;

      final localStart = start > offset ? start - offset : 0;
      final localEnd = end < pieceEnd ? end - offset : piece.length;
      buffer.write(_readPiece(piece, localStart, localEnd));
      offset = pieceEnd;
    }
    return buffer.toString();
  }

  /// Вставляет [text] в позицию [offset] (0 ≤ offset ≤ length).
  ///
  /// Алгоритм:
  /// 1. Добавить [text] в `_add`; новый фрагмент указывает на эту область.
  /// 2. Если вставка в конец документа — добавить один фрагмент и выйти.
  /// 3. Иначе [_locate] находит фрагмент, содержащий [offset]:
  ///    - `local == 0`: вставка перед фрагментом.
  ///    - `local == piece.length`: вставка после фрагмента.
  ///    - иначе: **разделить** фрагмент на `left | insert | right`, затем [_normalize].
  ///
  /// Пустой [text] игнорируется.
  void insert(int offset, String text) {
    if (text.isEmpty) return;
    _validateOffset(offset, allowEnd: true);

    final addStart = _add.length;
    _add.write(text);
    final insertPiece = _Piece(_BufferKind.add, addStart, text.length);

    if (offset == length) {
      _pieces.add(insertPiece);
      return;
    }

    final loc = _locate(offset);
    final piece = _pieces[loc.index];
    final local = offset - loc.pieceStart;

    if (local == 0) {
      _pieces.insert(loc.index, insertPiece);
      return;
    }
    if (local >= piece.length) {
      _pieces.insert(loc.index + 1, insertPiece);
      return;
    }

    final left = _Piece(piece.kind, piece.start, local);
    final right = _Piece(piece.kind, piece.start + local, piece.length - local);
    _pieces
      ..removeAt(loc.index)
      ..insertAll(loc.index, <_Piece>[left, insertPiece, right]);
    _normalize();
  }

  /// Удаляет полуоткрытый диапазон `[start, end)`.
  ///
  /// Алгоритм:
  /// - **Один фрагмент**: [_replaceSpan] обрезает или удаляет этот фрагмент.
  /// - **Несколько фрагментов**: сохранить хвост первого и голову последнего;
  ///   удалить все промежуточные; [_normalize] объединяет смежные фрагменты одного буфера.
  ///
  /// `start == end` — no-op.
  void delete(int start, int end) {
    if (start == end) return;
    _validateRange(start, end);
    final first = _locate(start);
    final last = end == length ? _locate(end - 1) : _locate(end);

    if (first.index == last.index) {
      final piece = _pieces[first.index];
      final localStart = start - first.pieceStart;
      final localEnd = end - first.pieceStart;
      _replaceSpan(first.index, piece, localStart, localEnd);
      return;
    }

    final firstPiece = _pieces[first.index];
    final firstLocalStart = start - first.pieceStart;
    final lastPiece = _pieces[last.index];
    final lastLocalEnd = end == length
        ? lastPiece.length
        : end - last.pieceStart;

    // Между first и last — только «обрезки» краёв; все средние фрагменты удаляются целиком.
    final replacement = <_Piece>[];
    if (firstLocalStart > 0) {
      replacement.add(
        _Piece(firstPiece.kind, firstPiece.start, firstLocalStart),
      );
    }
    if (lastLocalEnd < lastPiece.length) {
      replacement.add(
        _Piece(
          lastPiece.kind,
          lastPiece.start + lastLocalEnd,
          lastPiece.length - lastLocalEnd,
        ),
      );
    }

    _pieces
      ..removeRange(first.index, last.index + 1)
      ..insertAll(first.index, replacement);
    _normalize();
  }

  @override
  String toString() => substring(0, length);

  /// Читает `[start, end)` в локальных координатах одного фрагмента.
  String _readPiece(_Piece piece, int start, int end) {
    final source = piece.kind == _BufferKind.original
        ? _original
        : _add.toString();
    return sliceCodeUnits(source, piece.start + start, piece.start + end);
  }

  /// Заменяет удалённую часть `[localStart, localEnd)` внутри одного фрагмента.
  ///
  /// Четыре случая:
  /// - Удалить весь фрагмент → убрать из списка.
  /// - Удалить с начала → укоротить фрагмент слева.
  /// - Удалить до конца → укоротить фрагмент справа.
  /// - Удалить середину → разделить на два фрагмента.
  void _replaceSpan(int index, _Piece piece, int localStart, int localEnd) {
    if (localStart == 0 && localEnd >= piece.length) {
      _pieces.removeAt(index);
      return;
    }
    if (localStart == 0) {
      _pieces[index] = _Piece(
        piece.kind,
        piece.start + localEnd,
        piece.length - localEnd,
      );
      return;
    }
    if (localEnd >= piece.length) {
      _pieces[index] = _Piece(piece.kind, piece.start, localStart);
      return;
    }
    _pieces
      ..removeAt(index)
      ..insertAll(index, [
        _Piece(piece.kind, piece.start, localStart),
        _Piece(piece.kind, piece.start + localEnd, piece.length - localEnd),
      ]);
  }

  /// Объединяет последовательные фрагменты, смежные в одном буфере.
  ///
  /// Предотвращает неограниченный рост числа фрагментов после множества мелких правок в одной области.
  void _normalize() {
    final merged = <_Piece>[];
    for (final piece in _pieces) {
      if (piece.length == 0) continue;
      if (merged.isNotEmpty) {
        final last = merged.last;
        if (last.kind == piece.kind &&
            last.start + last.length == piece.start) {
          merged[merged.length - 1] = _Piece(
            last.kind,
            last.start,
            last.length + piece.length,
          );
          continue;
        }
      }
      merged.add(piece);
    }
    _pieces = merged;
  }

  /// Проверяет [offset]; при [allowEnd] допускает `offset == length`.
  void _validateOffset(int offset, {required bool allowEnd}) {
    final max = allowEnd ? length : (length == 0 ? 0 : length - 1);
    if (length == 0 && offset != 0) {
      throw RangeError.range(offset, 0, 0);
    }
    if (offset < 0 || offset > max) {
      throw RangeError.range(offset, 0, max);
    }
  }

  /// Проверяет полуоткрытый диапазон `[start, end)` в границах документа.
  void _validateRange(int start, int end) {
    if (start < 0 || end < start || end > length) {
      throw RangeError.range(end, start, length);
    }
  }

  /// Находит индекс фрагмента и смещение в документе, где лежит [offset].
  ///
  /// Если [offset] равен общей длине (вставка в конец), возвращает последний фрагмент
  /// (или индекс 0 для пустого документа).
  _PieceLocation _locate(int offset) {
    var pieceStart = 0;
    for (var i = 0; i < _pieces.length; i++) {
      final piece = _pieces[i];
      final pieceEnd = pieceStart + piece.length;
      if (offset < pieceEnd) {
        return _PieceLocation(i, pieceStart);
      }
      pieceStart = pieceEnd;
    }
    if (_pieces.isEmpty) {
      return _PieceLocation(0, 0);
    }
    return _PieceLocation(_pieces.length - 1, pieceStart);
  }
}

/// Результат [_locate]: индекс в [_pieces] и смещение начала этого фрагмента в документе.
final class _PieceLocation {
  const _PieceLocation(this.index, this.pieceStart);

  /// Индекс в [_pieces].
  final int index;

  /// Смещение начала фрагмента в документе.
  final int pieceStart;
}
