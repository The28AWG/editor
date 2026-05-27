import 'package:editor/editor.dart';
import 'package:example/lsp/lsp_debug.dart';
import 'package:example/lsp/lsp_position.dart';

/// Parses LSP `textDocument/publishDiagnostics` params.
List<EditorDiagnostic> diagnosticsFromLsp(
  String text,
  Map<String, dynamic> params,
) {
  final items = params['diagnostics'];
  if (items is! List) {
    lspDiagLog('diagnosticsFromLsp: missing or invalid "diagnostics" list');
    return const [];
  }

  final result = <EditorDiagnostic>[];
  for (final item in items) {
    if (item is! Map<String, dynamic>) continue;
    final range = item['range'];
    if (range is! Map<String, dynamic>) continue;
    final message = item['message'];
    if (message is! String || message.isEmpty) continue;

    result.add(
      EditorDiagnostic(
        range: rangeFromLsp(text, range),
        message: message,
        severity: _severityFromLsp(item['severity'] as int?),
        source: item['source'] as String?,
      ),
    );
  }
  return result;
}

DiagnosticSeverity _severityFromLsp(int? value) => switch (value) {
  2 => DiagnosticSeverity.warning,
  3 => DiagnosticSeverity.information,
  4 => DiagnosticSeverity.hint,
  _ => DiagnosticSeverity.error,
};
