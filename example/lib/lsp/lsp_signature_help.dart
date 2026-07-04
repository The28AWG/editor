import 'package:editor/editor.dart';
import 'package:example/lsp/lsp_markup.dart';

EditorSignatureHelp? signatureHelpFromLsp(Object? result) {
  if (result is! Map<String, dynamic>) return null;
  final sigsRaw = result['signatures'];
  if (sigsRaw is! List || sigsRaw.isEmpty) return null;

  final signatures = <EditorSignatureInformation>[];
  for (final raw in sigsRaw) {
    if (raw is! Map<String, dynamic>) continue;
    final label = raw['label'];
    if (label is! String || label.isEmpty) continue;

    final params = <String>[];
    final paramsRaw = raw['parameters'];
    if (paramsRaw is List) {
      for (final p in paramsRaw) {
        if (p is! Map<String, dynamic>) continue;
        final pl = p['label'];
        if (pl is String) {
          params.add(pl);
        } else if (pl is List && pl.length >= 2) {
          params.add(pl[1].toString());
        }
      }
    }

    signatures.add(
      EditorSignatureInformation(
        label: label,
        documentation: _optionalDoc(raw['documentation']),
        parameters: params,
        activeParameter: raw['activeParameter'] as int?,
      ),
    );
  }

  if (signatures.isEmpty) return null;
  return EditorSignatureHelp(
    signatures: signatures,
    activeSignature: result['activeSignature'] as int? ?? 0,
    activeParameter: result['activeParameter'] as int?,
  );
}

String? _optionalDoc(Object? value) {
  final text = markupContentFromLsp(value);
  return text.isEmpty ? null : text;
}
