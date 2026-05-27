import 'dart:async';

import 'package:example/lsp/dart_syntax_highlighter.dart';
import 'package:example/tree_sitter/dart_tree_sitter_highlighter.dart';
import 'package:flutter/foundation.dart';

/// Общий прогрев tree-sitter и LSP до первого [EditorView] (как в IDE).
final class ExampleLanguageServices {
  ExampleLanguageServices._();

  final Stopwatch sinceStart = Stopwatch();

  DartTreeSitterSyntaxHighlighter? treeSitter;
  DartSyntaxHighlighter? lsp;
  var treeSitterStatus = 'starting…';
  var lspStatus = 'starting…';
  var warmupPhase = 'starting…';

  void _log(String phase) {
    // ignore: avoid_print (debug)
    print('[+${sinceStart.elapsedMilliseconds}ms] warmup: $phase');
  }

  /// Параллельно поднимает бэкенды и при [initialText] прогревает подсветку.
  static Future<ExampleLanguageServices> warmUp({
    String? initialText,
    void Function(String phase)? onPhase,
  }) async {
    final s = ExampleLanguageServices._();
    s.sinceStart.start();
    void phase(String p) {
      s.warmupPhase = p;
      onPhase?.call(p);
    }

    s._log('start');
    phase('starting…');

    if (kIsWeb) {
      s
        ..treeSitterStatus = 'web (off)'
        ..lspStatus = 'unavailable';
      phase('web');
      s._log('complete (web)');
      return s;
    }

    phase('tree-sitter + LSP…');
    final results = await (_warmTreeSitter(s), _warmLspProcess(s)).wait;
    s
      ..treeSitter = results.$1
      ..lsp = results.$2;

    if (initialText != null) {
      const docVersion = 0;
      final ts = s.treeSitter;
      if (ts != null) {
        phase('tree-sitter highlight…');
        s._log('treeSitter apply (doc v$docVersion)…');
        ts.apply(initialText, docVersion);
        s._log('treeSitter apply done highlight v${ts.highlightVersion}');
      }
      final lsp = s.lsp;
      if (lsp != null) {
        phase('LSP open + tokens…');
        s._log('lsp open (doc v$docVersion)…');
        await lsp.open(initialText, docVersion);
        s._log(
          'lsp open done tokens v${lsp.tokensDocumentVersion} '
          'spans=${lsp.styleLayerFor(docVersion)?.runtimeType ?? 'null'}',
        );
      }
    }

    phase('ready');
    s._log('complete · $s');
    return s;
  }

  static Future<DartTreeSitterSyntaxHighlighter?> _warmTreeSitter(
    ExampleLanguageServices s,
  ) async {
    s._log('treeSitter tryCreate…');
    final ts = await DartTreeSitterSyntaxHighlighter.tryCreate();
    s
      ..treeSitterStatus = ts != null ? 'on' : 'off (native/jniLibs)'
      .._log('treeSitter ${ts != null ? 'ready' : 'off'}');
    return ts;
  }

  static Future<DartSyntaxHighlighter?> _warmLspProcess(
    ExampleLanguageServices s,
  ) async {
    s._log('lsp DartSyntaxHighlighter.start…');
    final highlighter = await DartSyntaxHighlighter.start();
    if (highlighter == null) {
      s
        ..lspStatus = 'unavailable'
        .._log('lsp unavailable');
      return null;
    }
    s
      ..lspStatus = 'dart language-server'
      .._log('lsp process ready');
    return highlighter;
  }

  Future<void> dispose() async {
    await lsp?.dispose();
    lsp = null;
  }

  @override
  String toString() => 'tree-sitter: $treeSitterStatus · lsp: $lspStatus';
}
