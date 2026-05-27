import 'dart:convert';

/// Encodes an LSP message with a `Content-Length` header.
List<int> lspEncode(Map<String, Object?> message) {
  final body = utf8.encode(jsonEncode(message));
  final header = utf8.encode('Content-Length: ${body.length}\r\n\r\n');
  return [...header, ...body];
}

/// Appends [chunk] to [buffer] and parses complete LSP messages.
void lspFeed(
  List<int> chunk,
  List<int> buffer,
  void Function(Map<String, dynamic> message) onMessage,
) {
  buffer.addAll(chunk);
  while (true) {
    final headerEnd = _indexOfHeaderEnd(buffer);
    if (headerEnd < 0) return;

    final header = utf8.decode(buffer.sublist(0, headerEnd));
    final match = RegExp(r'Content-Length: (\d+)').firstMatch(header);
    if (match == null) return;

    final length = int.parse(match.group(1)!);
    final bodyStart = headerEnd + 4;
    if (buffer.length < bodyStart + length) return;

    final bodyBytes = buffer.sublist(bodyStart, bodyStart + length);
    buffer.removeRange(0, bodyStart + length);
    onMessage(jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>);
  }
}

int _indexOfHeaderEnd(List<int> bytes) {
  for (var i = 0; i + 3 < bytes.length; i++) {
    if (bytes[i] == 0x0D &&
        bytes[i + 1] == 0x0A &&
        bytes[i + 2] == 0x0D &&
        bytes[i + 3] == 0x0A) {
      return i;
    }
  }
  return -1;
}
