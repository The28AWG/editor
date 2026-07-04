/// Парсит LSP `MarkupContent` или plain string.
String markupContentFromLsp(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is! Map<String, dynamic>) return '';
  final text = value['value'];
  return text is String ? text : '';
}

bool isMarkdownMarkup(Object? value) {
  if (value is! Map<String, dynamic>) return false;
  return value['kind'] == 'markdown';
}
