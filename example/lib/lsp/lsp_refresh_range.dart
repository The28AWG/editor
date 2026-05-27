import 'package:editor/editor.dart';

/// Старты строк (смещения UTF-16) для [text].
List<int> lineStartOffsets(String text) {
  final starts = <int>[0];
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A) starts.add(i + 1);
  }
  return starts;
}

/// Диапазон буфера для `textDocument/semanticTokens/range` с запасом по строкам.
Range expandSemanticRefreshRange(
  String text,
  DocumentChange change, {
  int linePadding = 8,
}) {
  final len = text.length;
  if (len == 0) return const Range(0, 0);

  final starts = lineStartOffsets(text);
  final first = change.affectedFirstLine.clamp(0, starts.length - 1);
  final last = change.affectedLastLine.clamp(0, starts.length - 1);
  final lo = (first - linePadding).clamp(0, starts.length - 1);
  final hi = (last + linePadding).clamp(0, starts.length - 1);
  final rangeStart = starts[lo];
  final rangeEnd = hi + 1 < starts.length ? starts[hi + 1] : len;
  return Range(rangeStart, rangeEnd.clamp(0, len));
}

/// Крупная правка — только `semanticTokens/full`.
bool needsFullSemanticRefresh(DocumentChange? change) {
  if (change == null) return true;
  if (change.insertedText.length > 2000 || change.removedLength > 2000) {
    return true;
  }
  final affected = change.affectedLineRange;
  if (affected.end > affected.start && affected.end - affected.start > 2000) {
    return true;
  }
  return false;
}
