import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/sorted_style_spans.dart';
import 'package:editor/src/styling/style_span.dart';

/// Объединяет диапазоны вставленного текста (координаты после каждой правки).
///
/// Нужен для [styleSpansAfterPendingChanges]: несколько insert-only правок подряд
/// дают одну «маску» без syntax-цвета, чтобы не вычитать spans по каждой правке отдельно.
Range? mergeInsertHighlightMask(Range? current, DocumentChange change) {
  final inserted = change.insertedText;
  if (inserted.isEmpty) return current;

  final added = Range(change.range.start, change.range.start + inserted.length);
  if (current == null) return added;

  final mergedStart = current.start < added.start ? current.start : added.start;
  final mergedEnd = current.end > added.end ? current.end : added.end;
  return Range(mergedStart, mergedEnd);
}

/// Сдвигает [spans] после одной [change] (диапазон правки — до применения).
List<StyleSpan> shiftStyleSpansForChange(
  List<StyleSpan> spans,
  DocumentChange change,
) {
  if (spans.isEmpty) return const [];

  final editStart = change.range.start;
  final removedLen = change.removedLength;
  final editEnd = editStart + removedLen;
  final delta = change.insertedText.length - removedLen;
  final insertEnd = editStart + change.insertedText.length;

  final result = <StyleSpan>[];
  for (final span in spans) {
    final s = span.range.start;
    final e = span.range.end;

    // Span целиком до правки — координаты не меняются.
    if (e <= editStart) {
      result.add(span);
      continue;
    }
    // Span целиком после удалённого фрагмента — сдвиг на delta.
    if (s >= editEnd) {
      result.add(_withRange(span, Range(s + delta, e + delta)));
      continue;
    }
    // Span пересекает правку: сохраняем хвост слева и/или справа от замены.
    if (s < editStart) {
      result.add(_withRange(span, Range(s, editStart)));
    }
    if (e > editEnd) {
      result.add(_withRange(span, Range(insertEnd, e + delta)));
    }
  }
  return result;
}

/// Убирает с конца [pending] записи, соответствующие отменённой вставке [undo].
void revertPendingChangesForUndo(
  List<DocumentChange> pending,
  DocumentChange undo,
) {
  var net = undo.removedLength;
  while (net > 0 && pending.isNotEmpty) {
    final last = pending.removeLast();
    net -= last.insertedText.length;
    net += last.removedLength;
  }
}

/// Схлопывает соседние insert-only правки в [pending] (быстрый набор символов).
///
/// Например, 8 правок `@3303+1`, `@3304+1`, … → одна `@3303+8`, что сокращает
/// цепочку проекций в [PendingShiftedSyntaxLayer] с O(pending) до O(1) на span.
///
/// Возвращает `true`, если список изменился.
bool coalesceAdjacentPendingInserts(List<DocumentChange> pending) {
  if (pending.length < 2) return false;
  var write = 0;
  var changed = false;
  for (var read = 0; read < pending.length; read++) {
    var merged = pending[read];
    while (read + 1 < pending.length &&
        _canCoalesceAdjacentInserts(merged, pending[read + 1])) {
      changed = true;
      read++;
      final next = pending[read];
      merged = DocumentChange(
        range: merged.range,
        oldVersion: merged.oldVersion,
        newVersion: next.newVersion,
        affectedLineRange: merged.affectedLineRange,
        affectedFirstLine: merged.affectedFirstLine,
        affectedLastLine: merged.affectedLastLine > next.affectedLastLine
            ? merged.affectedLastLine
            : next.affectedLastLine,
        insertedText: merged.insertedText + next.insertedText,
        removedLength: merged.removedLength,
      );
    }
    if (write != read) changed = true;
    pending[write++] = merged;
  }
  if (write < pending.length) {
    pending.removeRange(write, pending.length);
    changed = true;
  }
  return changed;
}

/// Две insert-only правки можно слить, если они соседние, однострочные и «мелкие».
bool _canCoalesceAdjacentInserts(DocumentChange prev, DocumentChange next) {
  if (prev.removedLength != 0 || next.removedLength != 0) return false;
  if (prev.insertedText.contains('\n') || next.insertedText.contains('\n')) {
    return false;
  }
  if (prev.insertedText.length > _structuralEditCodeUnitThreshold) return false;
  if (next.insertedText.length > _structuralEditCodeUnitThreshold) return false;
  final prevEnd = prev.range.start + prev.insertedText.length;
  return next.range.start == prevEnd;
}

/// Проецирует [offset] вперёд через одну применённую [change]
/// (offset должен быть в той же системе координат, что и [DocumentChange.range]).
///
/// - `offset <= editStart` — без изменений.
/// - `offset >= editStart + removedLength` — сдвиг на `delta = inserted - removed`.
/// - Внутри удалённого диапазона — клампится в начало вставленного фрагмента
///   (консервативная семантика для «leftmost stale anchor»).
int projectOffsetForward(int offset, DocumentChange change) {
  final editStart = change.range.start;
  final removedLen = change.removedLength;
  final insertedLen = change.insertedText.length;
  final editEnd = editStart + removedLen;
  if (offset <= editStart) return offset;
  if (offset >= editEnd) return offset + (insertedLen - removedLen);
  return editStart;
}

/// Обратная проекция [offset] через одну применённую [change]: возвращает offset
/// в системе координат **до** [change], при условии что [offset] задан в системе
/// координат **после** [change].
///
/// Используется для ленивого слоя, который из текущих координат нащупывает
/// диапазон в исходном «снимке» LSP-токенов.
///
/// - `offset <= editStart` — без изменений (часть до правки инвариантна).
/// - `offset >= editStart + insertedLength` — сдвиг назад на `delta = inserted - removed`.
/// - Внутри вставленной области — клампится в `editStart` (соответствует точке,
///   откуда вставка началась в исходных координатах).
int projectOffsetBackward(int offset, DocumentChange change) {
  final editStart = change.range.start;
  final removedLen = change.removedLength;
  final insertedLen = change.insertedText.length;
  final insertedEnd = editStart + insertedLen;
  if (offset <= editStart) return offset;
  if (offset >= insertedEnd) return offset - (insertedLen - removedLen);
  return editStart;
}

/// Прокатывает [offset] вперёд через всю цепочку [pending] (порядок применения).
int projectOffsetForwardChain(int offset, List<DocumentChange> pending) {
  var pos = offset;
  for (final c in pending) {
    pos = projectOffsetForward(pos, c);
  }
  return pos;
}

/// Прокатывает [offset] обратно через всю цепочку [pending] (в обратном порядке).
int projectOffsetBackwardChain(int offset, List<DocumentChange> pending) {
  var pos = offset;
  for (var i = pending.length - 1; i >= 0; i--) {
    pos = projectOffsetBackward(pos, pending[i]);
  }
  return pos;
}

/// Сдвигает диапазон **span**'а через одну [change] с правильной семантикой
/// границ (insert ровно в начало span'а отодвигает span вправо; удаление,
/// поглотившее span целиком, возвращает `null`).
///
/// В отличие от [projectOffsetForward] (sticky-left, для anchor'а) — здесь
/// границы интерпретируются как «span целиком до правки», «span целиком после»
/// или «span пересекает правку». Поведение совпадает с
/// [shiftStyleSpansForChange] для одиночного span.
Range? shiftRangeForward(Range range, DocumentChange change) {
  final s = range.start;
  final e = range.end;
  final editStart = change.range.start;
  final removedLen = change.removedLength;
  final insertedLen = change.insertedText.length;
  final editEnd = editStart + removedLen;
  final delta = insertedLen - removedLen;

  if (e <= editStart) return range;
  if (s >= editEnd) return Range(s + delta, e + delta);

  final outStart = s < editStart ? s : editStart + insertedLen;
  final outEnd = e > editEnd ? e + delta : editStart;
  if (outStart >= outEnd) return null;
  return Range(outStart, outEnd);
}

/// Прокатывает [range] вперёд через всю цепочку [pending] правок.
///
/// Возвращает `null`, если хоть одна правка поглотила span целиком.
Range? shiftRangeForwardChain(Range range, List<DocumentChange> pending) {
  var r = range;
  for (final c in pending) {
    final next = shiftRangeForward(r, c);
    if (next == null) return null;
    r = next;
  }
  return r;
}

/// Порог в кодовых единицах, выше которого правка считается «структурной»
/// (большая вставка/удаление). Подобрано под типичную клавишную правку
/// (~1–4 символа) против paste/replace целых выражений (десятки и сотни).
const int _structuralEditCodeUnitThreshold = 32;

/// Должен ли «серый клип» применяться к хвосту display spans для данных [pending]
/// правок (т.е. правки достаточно «структурные», чтобы геометрический сдвиг был
/// семантически опасен).
///
/// Возвращает `true`, если хоть одна правка:
/// - вставляет/удаляет `> 32` кодовых единиц (paste, replace),
/// - вставляет символ перевода строки (`\n`),
/// - пересекает несколько строк документа (`affectedFirstLine != affectedLastLine`).
///
/// На «простых» одностроковых правках (ввод одиночного символа, backspace, undo
/// одного слова) возвращает `false` — сдвинутые spans остаются видимыми, как в
/// VS Code: пользователь не теряет подсветку хвоста, артефакт цвета возможен
/// только на изменённой строке до прихода свежих токенов.
bool shouldClipStaleTail(List<DocumentChange> pending) {
  for (final c in pending) {
    if (c.insertedText.length > _structuralEditCodeUnitThreshold) return true;
    if (c.removedLength > _structuralEditCodeUnitThreshold) return true;
    if (c.insertedText.contains('\n')) return true;
    if (c.affectedFirstLine != c.affectedLastLine) return true;
  }
  return false;
}

/// Возвращает минимальный offset любой записи [pending], спроецированный в
/// текущую систему координат (после применения всех [pending]); `null` для пустого журнала.
///
/// Каждая `pending[i].range.start` хранится в координатах «после `pending[0..i-1]`»,
/// поэтому её нужно прогонять через `projectOffsetForward` по последующим правкам.
/// Используется как anchor для [clipStyleSpansBefore], когда правки не монотонны
/// слева направо (например, multicursor, find-and-replace, code action).
int? leftmostPendingStartInCurrentCoords(List<DocumentChange> pending) {
  if (pending.isEmpty) return null;
  var min = -1;
  for (var i = 0; i < pending.length; i++) {
    var pos = pending[i].range.start;
    for (var j = i + 1; j < pending.length; j++) {
      pos = projectOffsetForward(pos, pending[j]);
    }
    if (min < 0 || pos < min) min = pos;
  }
  return min < 0 ? null : min;
}

/// Оставляет только участки строго до [offset] (хвост — базовый цвет темы).
///
/// Сдвиг LSP-spans геометрически корректен, но семантика на хвосте неверна,
/// пока analyzer не ответил — не рисуем syntax правее первой правки.
List<StyleSpan> clipStyleSpansBefore(List<StyleSpan> spans, int offset) {
  if (spans.isEmpty) return const [];

  final out = <StyleSpan>[];
  for (final span in spans) {
    final r = span.range;
    if (r.end <= offset) {
      out.add(span);
    } else if (r.start < offset) {
      out.add(_withRange(span, Range(r.start, offset)));
    }
  }
  return out;
}

/// Одна правка поверх уже сдвинутых [spans]; новая вставка без syntax-цвета.
List<StyleSpan> applyStyleSpanEditIncremental(
  List<StyleSpan> spans,
  DocumentChange change,
) {
  var result = shiftStyleSpansForChange(spans, change);
  if (change.insertedText.isNotEmpty) {
    result = styleSpansExcludingSortedRange(
      result,
      Range(
        change.range.start,
        change.range.start + change.insertedText.length,
      ),
    );
  }
  return result;
}

/// Сдвигает LSP-spans по цепочке правок; вставки без подсветки (базовый цвет).
List<StyleSpan> styleSpansAfterPendingChanges(
  List<StyleSpan> sortedBase,
  List<DocumentChange> changes,
) {
  if (changes.isEmpty) return List<StyleSpan>.of(sortedBase);

  var spans = List<StyleSpan>.of(sortedBase);
  Range? insertMask;
  for (final change in changes) {
    spans = shiftStyleSpansForChange(spans, change);
    insertMask = mergeInsertHighlightMask(insertMask, change);
  }
  if (insertMask != null) {
    spans = styleSpansExcludingSortedRange(spans, insertMask);
  }
  return sortedStyleSpans(spans);
}

/// Убирает из отсортированных [spans] участок [mask] за один проход O(n).
List<StyleSpan> styleSpansExcludingSortedRange(
  List<StyleSpan> sorted,
  Range mask,
) {
  if (sorted.isEmpty || mask.start >= mask.end) {
    return List<StyleSpan>.of(sorted);
  }

  final out = <StyleSpan>[];
  for (var i = 0; i < sorted.length; i++) {
    final span = sorted[i];
    final r = span.range;
    if (r.end <= mask.start) {
      out.add(span);
      continue;
    }
    if (r.start >= mask.end) {
      out.addAll(sorted.sublist(i));
      break;
    }
    out.addAll(_subtractRangeFromSpan(span, mask));
  }
  return out;
}

/// Убирает из [spans] участки, пересекающие [exclude] (остаётся базовый цвет темы).
List<StyleSpan> styleSpansExcludingRanges(
  List<StyleSpan> spans,
  List<Range> exclude,
) {
  if (spans.isEmpty || exclude.isEmpty) return List<StyleSpan>.of(spans);
  if (exclude.length == 1) {
    return styleSpansExcludingSortedRange(spans, exclude.first);
  }

  var result = List<StyleSpan>.of(spans);
  for (final mask in exclude) {
    if (mask.start >= mask.end) continue;
    final next = <StyleSpan>[];
    for (final span in result) {
      next.addAll(_subtractRangeFromSpan(span, mask));
    }
    result = next;
  }
  return result;
}

/// Вырезает [mask] из [span], возвращая 0–2 непересекающихся фрагмента.
List<StyleSpan> _subtractRangeFromSpan(StyleSpan span, Range mask) {
  final r = span.range;
  if (r.end <= mask.start || r.start >= mask.end) return [span];

  final parts = <StyleSpan>[];
  if (r.start < mask.start) {
    parts.add(_withRange(span, Range(r.start, mask.start)));
  }
  if (r.end > mask.end) {
    parts.add(_withRange(span, Range(mask.end, r.end)));
  }
  return parts;
}

/// Копия [span] с другим диапазоном; атрибуты стиля сохраняются.
StyleSpan _withRange(StyleSpan span, Range range) => StyleSpan(
  range: range,
  color: span.color,
  backgroundColor: span.backgroundColor,
  fontWeight: span.fontWeight,
  fontStyle: span.fontStyle,
  underline: span.underline,
  wavyUnderline: span.wavyUnderline,
  underlineColor: span.underlineColor,
  priority: span.priority,
);

/// Заменяет spans в [refreshRange] на [rangeSpans], остальное сохраняет.
List<StyleSpan> mergeStyleSpansForRange(
  List<StyleSpan> sorted,
  List<StyleSpan> rangeSpans,
  Range refreshRange,
) {
  if (refreshRange.start >= refreshRange.end) {
    return sortedStyleSpans([...sorted, ...rangeSpans]);
  }

  final kept = <StyleSpan>[];
  for (final span in sorted) {
    final r = span.range;
    if (r.end <= refreshRange.start || r.start >= refreshRange.end) {
      kept.add(span);
      continue;
    }
    if (r.start < refreshRange.start) {
      kept.add(_withRange(span, Range(r.start, refreshRange.start)));
    }
    if (r.end > refreshRange.end) {
      kept.add(_withRange(span, Range(refreshRange.end, r.end)));
    }
  }
  return sortedStyleSpans([...kept, ...rangeSpans]);
}
