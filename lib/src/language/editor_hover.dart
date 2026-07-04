import 'package:editor/src/model/position.dart';

/// Содержимое hover tooltip (LSP `textDocument/hover`).
final class EditorHover {
  const EditorHover({
    required this.contents,
    this.range,
    this.isMarkdown = false,
  });

  final String contents;
  final Range? range;
  final bool isMarkdown;
}
