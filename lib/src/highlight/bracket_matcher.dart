import 'package:editor/src/highlight/highlight_kind.dart';
import 'package:editor/src/highlight/highlight_span.dart';
import 'package:editor/src/model/position.dart';

/// Результат сопоставления пары скобок вокруг каретки.
///
/// [openOffset] и [closeOffset] — индексы code unit пары.
/// [activeOffset] — скобка, которую касается каретка (открывающая или закрывающая).
final class BracketMatch {
  /// Создаёт совпадение скобок с активной скобкой на [activeOffset].
  const BracketMatch({
    required this.openOffset,
    required this.closeOffset,
    required this.activeOffset,
  });

  /// Смещение в документе открывающей скобки.
  final TextOffset openOffset;

  /// Смещение в документе закрывающей скобки.
  final TextOffset closeOffset;

  /// Смещение скобки под кареткой или рядом с ней.
  final TextOffset activeOffset;
}

const _openToClose = <int, int>{
  0x28: 0x29, // ( )
  0x5B: 0x5D, // [ ]
  0x7B: 0x7D, // { }
  0x3C: 0x3E, // < >
};

final _closeToOpen = <int, int>{
  for (final e in _openToClose.entries) e.value: e.key,
};

/// Находит пару соответствующих скобок для [offset] (каретка), игнорируя строки и комментарии.
///
/// Поддерживаемые пары: `()`, `[]`, `{}`, `<>`.
///
/// Алгоритм:
/// 1. Определить индекс скобки у каретки (символ перед или на [offset]).
/// 2. Если открывающая скобка: сканировать вперёд с глубиной вложенности, пропуская не-кодовые токены.
/// 3. Если закрывающая скобка: сканировать назад с глубиной вложенности.
/// 4. Вернуть [BracketMatch] или `null`, если сбалансированной пары нет.
///
/// [searchStart] и [searchEnd] — полуоткрытый диапазон code unit в [text]; поиск пары
/// ограничен им (например, viewport). Если пара не найдена внутри диапазона,
/// возвращается `null` (см. [bracketHighlightSpans] — там скобка у каретки всё равно
/// подсвечивается, если пара за пределами видимой области).
///
/// **Граничные случаи:** Скобки внутри `//`, `/* */`, `'...'` и `"..."` игнорируются.
/// Незакрытые строки/комментарии простираются до конца строки или буфера. Возвращает `null`, когда
/// каретка не на скобке и не рядом с ней.
BracketMatch? matchBrackets(
  String text,
  TextOffset offset, {
  TextOffset searchStart = 0,
  TextOffset? searchEnd,
}) {
  final end = searchEnd ?? text.length;
  if (searchStart >= end) return null;

  final index = _bracketIndexAtCaret(text, offset);
  if (index == null) return null;
  if (index < searchStart || index >= end) return null;

  final code = text.codeUnitAt(index);
  if (_openToClose.containsKey(code)) {
    final close = _findClosing(
      text,
      index,
      code,
      _openToClose[code]!,
      searchEnd: end,
    ).match;
    if (close == null || close >= end) return null;
    return BracketMatch(
      openOffset: index,
      closeOffset: close,
      activeOffset: index,
    );
  }
  if (_closeToOpen.containsKey(code)) {
    final open = _findOpening(
      text,
      index,
      code,
      _closeToOpen[code]!,
      searchStart: searchStart,
    ).match;
    if (open == null || open < searchStart) return null;
    return BracketMatch(
      openOffset: open,
      closeOffset: index,
      activeOffset: index,
    );
  }
  return null;
}

/// Преобразует скобку у каретки в [HighlightSpan].
///
/// Пара подсвечивается только если обе скобки найдены в пределах
/// [searchStart]/[searchEnd]. Иначе подсвечивается только скобка у каретки
/// ([HighlightKind.bracketActive]); за пределами viewport пара не ищется.
List<HighlightSpan> bracketHighlightSpans(
  String text,
  TextOffset offset, {
  TextOffset searchStart = 0,
  TextOffset? searchEnd,
  bool boundedSearch = false,
}) {
  final end = searchEnd ?? text.length;
  final index = _bracketIndexAtCaret(text, offset);
  if (index == null) return const [];
  if (index < searchStart || index >= end) return const [];

  final code = text.codeUnitAt(index);
  if (_openToClose.containsKey(code)) {
    final closeResult = _findClosing(
      text,
      index,
      code,
      _openToClose[code]!,
      searchEnd: end,
      boundedSearch: boundedSearch,
    );
    if (closeResult.match != null) {
      return _pairSpans(index, closeResult.match!, index);
    }
    if (closeResult.partnerOutsideBounds) {
      return _activeOnlySpan(index);
    }
    return const [];
  }
  if (_closeToOpen.containsKey(code)) {
    final openResult = _findOpening(
      text,
      index,
      code,
      _closeToOpen[code]!,
      searchStart: searchStart,
      boundedSearch: boundedSearch,
    );
    if (openResult.match != null) {
      return _pairSpans(openResult.match!, index, index);
    }
    if (openResult.partnerOutsideBounds) {
      return _activeOnlySpan(index);
    }
    return const [];
  }
  return const [];
}

List<HighlightSpan> _pairSpans(
  TextOffset openOffset,
  TextOffset closeOffset,
  TextOffset activeOffset,
) => [
  HighlightSpan(
    range: Range(openOffset, openOffset + 1),
    kind: activeOffset == openOffset
        ? HighlightKind.bracketActive
        : HighlightKind.bracket,
  ),
  HighlightSpan(
    range: Range(closeOffset, closeOffset + 1),
    kind: activeOffset == closeOffset
        ? HighlightKind.bracketActive
        : HighlightKind.bracket,
  ),
];

List<HighlightSpan> _activeOnlySpan(TextOffset index) => [
  HighlightSpan(
    range: Range(index, index + 1),
    kind: HighlightKind.bracketActive,
  ),
];

/// Индекс скобки под кареткой: символ на [offset] или непосредственно перед ним.
TextOffset? _bracketIndexAtCaret(String text, TextOffset offset) {
  if (offset > 0) {
    final before = text.codeUnitAt(offset - 1);
    if (_isBracket(before)) return offset - 1;
  }
  if (offset < text.length) {
    final at = text.codeUnitAt(offset);
    if (_isBracket(at)) return offset;
  }
  return null;
}

/// `true`, если code unit — одна из поддерживаемых скобок.
bool _isBracket(int codeUnit) =>
    _openToClose.containsKey(codeUnit) || _closeToOpen.containsKey(codeUnit);

/// Ищет закрывающую [closeCode] для открывающей на [openIndex] (сканирование вперёд, depth).
({TextOffset? match, bool partnerOutsideBounds}) _findClosing(
  String text,
  TextOffset openIndex,
  int openCode,
  int closeCode, {
  required TextOffset searchEnd,
  bool boundedSearch = false,
}) {
  var depth = 0;
  for (var i = openIndex; i < text.length && i < searchEnd;) {
    if (!_isCode(text, i)) {
      i = _tokenEndAt(text, _tokenStart(text, i));
      continue;
    }
    final c = text.codeUnitAt(i);
    if (c == openCode) {
      depth++; // вложенная открывающая
    } else if (c == closeCode) {
      depth--;
      if (depth == 0) return (match: i, partnerOutsideBounds: false);
    }
    i++;
  }
  return (
    match: null,
    // depth > 0: открывающая найдена, но закрывающая за пределами searchEnd —
    // для UI подсветим только активную скобразу ([boundedSearch] / viewport).
    partnerOutsideBounds:
        depth > 0 && (boundedSearch || searchEnd < text.length),
  );
}

/// Ищет открывающую [openCode] для закрывающей на [closeIndex] (сканирование назад, depth).
({TextOffset? match, bool partnerOutsideBounds}) _findOpening(
  String text,
  TextOffset closeIndex,
  int closeCode,
  int openCode, {
  required TextOffset searchStart,
  bool boundedSearch = false,
}) {
  var depth = 0;
  for (var i = closeIndex; i >= 0 && i >= searchStart;) {
    if (!_isCode(text, i)) {
      i = _tokenStart(text, i) - 1;
      continue;
    }
    final c = text.codeUnitAt(i);
    if (c == closeCode) {
      depth++; // вложенная закрывающая при движении назад
    } else if (c == openCode) {
      depth--;
      if (depth == 0) return (match: i, partnerOutsideBounds: false);
    }
    i--;
  }
  return (
    match: null,
    // Симметрично [_findClosing]: пара есть, но открывающая левее searchStart.
    partnerOutsideBounds: depth > 0 && (boundedSearch || searchStart > 0),
  );
}

/// Начало лексического токена (код, `//`, `/*`, строка), содержащего [index].
int _tokenStart(String text, int index) {
  var pos = 0;
  while (pos < text.length) {
    final end = _tokenEndAt(text, pos);
    if (index >= pos && index < end) return pos;
    pos = end;
  }
  return text.length;
}

/// Конец лексического токена с [start]: один code unit, комментарий или строка.
int _tokenEndAt(String text, int start) {
  if (start >= text.length) return text.length;
  final c = text.codeUnitAt(start);
  if (c == 0x2F && start + 1 < text.length) {
    if (text.codeUnitAt(start + 1) == 0x2F) return _lineEnd(text, start + 2);
    if (text.codeUnitAt(start + 1) == 0x2A) {
      return _blockCommentEnd(text, start + 2);
    }
  }
  if (c == 0x22 || c == 0x27) return _stringEnd(text, start, c);
  return start + 1;
}

/// `true`, если позиция [index] не внутри комментария или строкового литерала.
bool _isCode(String text, int index) {
  final start = _tokenStart(text, index);
  final c = text.codeUnitAt(start);
  if (c == 0x2F && start + 1 < text.length) {
    final next = text.codeUnitAt(start + 1);
    if (next == 0x2F || next == 0x2A) return false;
  }
  return c != 0x22 && c != 0x27;
}

/// Индекс LF или конца буфера для однострочного комментария, начиная с [start].
int _lineEnd(String text, int start) {
  for (var i = start; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A) return i;
  }
  return text.length;
}

/// Индекс после `*/` или конца буфера для блочного комментария с [start].
int _blockCommentEnd(String text, int start) {
  for (var i = start; i + 1 < text.length; i++) {
    if (text.codeUnitAt(i) == 0x2A && text.codeUnitAt(i + 1) == 0x2F) {
      return i + 2;
    }
  }
  return text.length;
}

/// Индекс после закрывающей кавычки [quote]; учитывает `\` escape и LF в `'...'`.
int _stringEnd(String text, int start, int quote) {
  var i = start + 1;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c == 0x5C) {
      i += 2;
      continue;
    }
    if (c == quote) return i + 1;
    if (c == 0x0A && quote == 0x27) return i;
    i++;
  }
  return text.length;
}
