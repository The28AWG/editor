/// Описание одной перегрузки (LSP `SignatureInformation`).
final class EditorSignatureInformation {
  const EditorSignatureInformation({
    required this.label,
    this.documentation,
    this.parameters = const [],
    this.activeParameter,
  });

  final String label;
  final String? documentation;
  final List<String> parameters;
  final int? activeParameter;
}

/// Signature help у каретки (LSP `textDocument/signatureHelp`).
final class EditorSignatureHelp {
  const EditorSignatureHelp({
    required this.signatures,
    this.activeSignature = 0,
    this.activeParameter,
  });

  final List<EditorSignatureInformation> signatures;
  final int activeSignature;
  final int? activeParameter;
}
