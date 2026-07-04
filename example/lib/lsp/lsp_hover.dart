import 'package:editor/editor.dart';
import 'package:example/lsp/lsp_markup.dart';
import 'package:example/lsp/lsp_position.dart';

EditorHover? hoverFromLsp(String text, Object? result) {
  if (result is! Map<String, dynamic>) return null;
  final contents = result['contents'];
  if (contents == null) return null;

  final rangeRaw = result['range'];
  Range? range;
  if (rangeRaw is Map<String, dynamic>) {
    range = rangeFromLsp(text, rangeRaw);
  }

  if (contents is String) {
    return EditorHover(contents: contents, range: range);
  }
  if (contents is List) {
    final buffer = StringBuffer();
    for (final part in contents) {
      if (part is! Map<String, dynamic>) continue;
      final value = part['value'];
      if (value is String) buffer.writeln(value);
    }
    final joined = buffer.toString().trimRight();
    if (joined.isEmpty) return null;
    return EditorHover(contents: joined, range: range);
  }
  if (contents is Map<String, dynamic>) {
    final value = markupContentFromLsp(contents);
    if (value.isEmpty) return null;
    return EditorHover(
      contents: value,
      range: range,
      isMarkdown: isMarkdownMarkup(contents),
    );
  }
  return null;
}
