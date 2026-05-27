import 'package:editor/editor.dart';

/// UTF-16 LSP position ↔ editor offset.
Position lspPositionAt(String text, TextOffset offset) {
  var line = 0;
  var lineStart = 0;
  final clamped = offset < 0
      ? 0
      : offset > text.length
      ? text.length
      : offset;
  for (var i = 0; i < clamped; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      line++;
      lineStart = i + 1;
    }
  }
  return Position(line, clamped - lineStart);
}

TextOffset offsetAtLspPosition(String text, Position position) {
  var line = 0;
  var lineStart = 0;
  for (var i = 0; i < text.length; i++) {
    if (line == position.line) {
      final col = position.column;
      final end = _lineEnd(text, lineStart);
      final offset = lineStart + col;
      return offset > end ? end : offset;
    }
    if (text.codeUnitAt(i) == 0x0A) {
      line++;
      lineStart = i + 1;
    }
  }
  if (line == position.line) {
    final end = text.length;
    final offset = lineStart + position.column;
    return offset > end ? end : offset;
  }
  return text.length;
}

Range rangeFromLsp(String text, Map<String, dynamic> range) {
  final start = range['start'] as Map<String, dynamic>;
  final end = range['end'] as Map<String, dynamic>;
  final startOff = offsetAtLspPosition(
    text,
    Position(start['line'] as int, start['character'] as int),
  );
  final endOff = offsetAtLspPosition(
    text,
    Position(end['line'] as int, end['character'] as int),
  );
  return Range(startOff, endOff);
}

Map<String, Object> lspRangeFor(String text, Range range) {
  final start = lspPositionAt(text, range.start);
  final end = lspPositionAt(text, range.end);
  return {
    'start': {'line': start.line, 'character': start.column},
    'end': {'line': end.line, 'character': end.column},
  };
}

int _lineEnd(String text, int lineStart) {
  for (var i = lineStart; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A) return i;
  }
  return text.length;
}
