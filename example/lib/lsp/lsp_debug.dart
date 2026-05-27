import 'package:flutter/foundation.dart';

/// Set to `false` to silence LSP diagnostics tracing.
const kLspDiagnosticsDebug = false;

void lspDiagLog(String message) {
  if (!kLspDiagnosticsDebug) return;
  debugPrint('[LSP diagnostics] $message');
}
