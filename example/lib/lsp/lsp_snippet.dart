/// Преобразует LSP snippet (`insertTextFormat: 2`) в plain text для [TextEdit].
String snippetToPlainText(String snippet) {
  var text = snippet;
  text = text.replaceAllMapped(
    RegExp(r'\$\{(\d+):([^}]*)\}'),
    (m) => m.group(2)!,
  );
  text = text.replaceAll(RegExp(r'\$\{\d+\}'), '');
  text = text.replaceAll(RegExp(r'\$\d+'), '');
  return text;
}
