import 'package:editor/editor.dart';
import 'package:example/lsp/lsp_position.dart';

/// Парсит LSP `Location`, `Location[]`, `LocationLink` или `LocationLink[]`.
EditorDocumentLocation? documentLocationFromLsp(
  Object? result,
  String textForOpenDocument,
) {
  if (result == null) return null;
  if (result is List) {
    for (final item in result) {
      final loc = documentLocationFromLsp(item, textForOpenDocument);
      if (loc != null) return loc;
    }
    return null;
  }
  if (result is! Map<String, dynamic>) return null;

  final targetUri = result['targetUri'] as String?;
  if (targetUri != null) {
    final rangeRaw =
        result['targetSelection'] as Map<String, dynamic>? ??
        result['targetRange'] as Map<String, dynamic>? ??
        result['range'] as Map<String, dynamic>?;
    if (rangeRaw == null) return null;
    return EditorDocumentLocation(
      uri: targetUri,
      range: rangeFromLsp(textForOpenDocument, rangeRaw),
    );
  }

  final uri = result['uri'] as String?;
  final rangeRaw = result['range'] as Map<String, dynamic>?;
  if (uri == null || rangeRaw == null) return null;
  return EditorDocumentLocation(
    uri: uri,
    range: rangeFromLsp(textForOpenDocument, rangeRaw),
  );
}

/// `DocumentLink` под [offset] в открытом [text].
EditorLinkTarget? documentLinkTargetFromLsp(
  Object? result,
  String text,
  TextOffset offset, {
  required String fallbackDocumentUri,
}) {
  if (result is! List) return null;
  for (final item in result) {
    if (item is! Map<String, dynamic>) continue;
    final rangeRaw = item['range'] as Map<String, dynamic>?;
    if (rangeRaw == null) continue;
    final range = rangeFromLsp(text, rangeRaw);
    if (offset < range.start || offset >= range.end) continue;

    final targetUri = item['target'] as String? ?? fallbackDocumentUri;
    return EditorLinkTarget(
      highlightRange: range,
      destination: EditorDocumentLocation(uri: targetUri, range: range),
    );
  }
  return null;
}
