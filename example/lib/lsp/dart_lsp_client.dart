import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:editor/editor.dart';
import 'package:example/lsp/highlight_debug.dart';
import 'package:example/lsp/lsp_completion.dart';
import 'package:example/lsp/lsp_debug.dart';
import 'package:example/lsp/lsp_diagnostics.dart';
import 'package:example/lsp/lsp_framing.dart';
import 'package:example/lsp/lsp_hover.dart';
import 'package:example/lsp/lsp_inlay_hints.dart';
import 'package:example/lsp/lsp_location.dart';
import 'package:example/lsp/lsp_position.dart';
import 'package:example/lsp/lsp_server_capabilities.dart';
import 'package:example/lsp/lsp_signature_help.dart';
import 'package:example/lsp/semantic_tokens_decoder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Dart analysis server (LSP) client: semantic tokens (full / range).
///
/// Document text is synced only via LSP ([textDocument/didOpen] / [didChange]);
/// no scratch file is written under [projectRoot].
final class DartLspClient {
  DartLspClient._({
    required this.documentUri,
    required this._process,
    required this._decoder,
  });

  final String documentUri;
  final Process _process;
  SemanticTokensDecoder _decoder;

  final _incoming = <int>[];
  var _nextId = 1;
  var _ready = false;
  var _serverCaps = const LspServerCapabilities();
  var _documentVersion = 0;
  String? _syncedText;
  List<dynamic>? _cachedDocumentLinks;
  int _cachedDocumentLinksVersion = -1;
  final _completionResolveStore = <String, Map<String, dynamic>>{};

  /// Text last sent to the server via [syncDocumentText] / [syncDocument].
  String? get lastSyncedText => _syncedText;
  final _pending = <int, Completer<dynamic>>{};
  List<EditorDiagnostic> diagnostics = const [];
  List<EditorInlayHint> inlayHints = const [];
  void Function(List<EditorDiagnostic> diagnostics, String analyzedText)?
  onDiagnostics;
  void Function(List<EditorInlayHint> hints)? onInlayHints;

  static Future<DartLspClient?> start({required String projectRoot}) async {
    if (kIsWeb) return null;
    if (!(Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      return null;
    }

    final dartExe = Platform.environment['DART_EXECUTABLE'] ?? 'dart';
    Process process;
    try {
      process = await Process.start(dartExe, ['language-server']);
    } on Object catch (e, st) {
      debugPrint('dart language-server start failed: $e\n$st');
      return null;
    }

    final documentUri = _virtualDocumentUri(projectRoot);
    lspDiagLog('LSP documentUri=$documentUri (in-memory, no disk file)');

    final client = DartLspClient._(
      documentUri: documentUri,
      process: process,
      decoder: SemanticTokensDecoder(
        tokenTypes: const [],
        tokenModifiers: const [],
        colorsByType: const {},
      ),
    );

    process.stdout.listen((chunk) {
      lspFeed(chunk, client._incoming, client._onMessage);
    });
    process.stderr.listen((chunk) {
      final text = utf8.decode(chunk);
      if (text.trim().isNotEmpty) debugPrint('LSP stderr: $text');
    });

    final initResult =
        await client._call('initialize', {
              'processId': pid,
              'rootUri': Uri.directory(projectRoot).toString(),
              'capabilities': {
                'textDocument': {
                  'semanticTokens': {
                    'formats': ['relative'],
                    'requests': {
                      'range': true,
                      'full': {'delta': true},
                    },
                    'tokenTypes': [],
                    'tokenModifiers': [],
                  },
                  'documentHighlight': const {},
                  'inlayHint': const {},
                  'definition': const {},
                  'documentLink': const {},
                  'completion': {
                    'completionItem': {
                      'snippetSupport': true,
                      'documentationFormat': ['markdown', 'plaintext'],
                    },
                  },
                  'hover': {
                    'contentFormat': ['markdown', 'plaintext'],
                  },
                  'signatureHelp': {
                    'signatureInformation': {
                      'documentationFormat': ['markdown', 'plaintext'],
                    },
                  },
                },
              },
            })
            as Map<String, dynamic>?;

    final legend =
        initResult?['capabilities']?['semanticTokensProvider']?['legend']
            as Map<String, dynamic>?;
    if (legend != null) {
      client._decoder = SemanticTokensDecoder(
        tokenTypes: List<String>.from(legend['tokenTypes'] as List),
        tokenModifiers: List<String>.from(legend['tokenModifiers'] as List),
        colorsByType: const {},
      );
    }

    client
      .._serverCaps = LspServerCapabilities.fromJson(
        initResult?['capabilities'] as Map<String, dynamic>?,
      )
      .._notify('initialized', {})
      .._ready = true;
    final caps = client._serverCaps;
    highlightDebugLog(
      'LSP caps semanticTokens=${caps.semanticTokens} '
      'range=${caps.semanticTokensRange} '
      'fullDelta=${caps.semanticTokensFullDelta}',
    );
    if (caps.semanticTokens && !caps.semanticTokensRange) {
      highlightDebugLog(
        'semanticTokens: только full (Dart analysis server не отдаёт range)',
      );
    }
    return client;
  }

  /// Подставляет палитру semantic token types (имена из legend LSP).
  void setSemanticTokenColors(Map<String, Color> colors) {
    _decoder = _decoder.copyWith(colorsByType: colors);
  }

  /// [file:] URI under the project; path is never created — Dart LSP ignores
  /// [untitled:] for analysis but accepts a non-existent workspace [file:] URI
  /// when content is supplied by the client.
  static String _virtualDocumentUri(String projectRoot) =>
      Uri.file('$projectRoot/test/__editor_virtual__.dart').toString();

  Future<void> dispose() async {
    if (_ready) {
      _notify('textDocument/didClose', {
        'textDocument': {'uri': documentUri},
      });
      await _call('shutdown', null);
      _notify('exit', {});
    }
    _process.kill();
  }

  Future<void> openDocument(String text) {
    _syncedText = text;
    _documentVersion = 1;
    _notify('textDocument/didOpen', {
      'textDocument': {
        'uri': documentUri,
        'languageId': 'dart',
        'version': _documentVersion,
        'text': text,
      },
    });
    return Future<void>.value();
  }

  /// Sends [text] to the server immediately (triggers analysis / diagnostics).
  void syncDocumentText(String text) {
    if (!_ready) return;
    _pushDocument(text);
    lspDiagLog(
      'didChange → server (${text.length} chars, LSP v$_documentVersion)',
    );
  }

  /// Инкрементальные [changes] в порядке применения; [resultingText] — итоговый буфер.
  void syncDocumentEdits(List<DocumentChange> changes, String resultingText) {
    if (!_ready) return;
    if (changes.isEmpty) {
      syncDocumentText(resultingText);
      return;
    }

    var snapshot = _syncedText ?? '';
    final contentChanges = <Map<String, Object?>>[];

    for (final change in changes) {
      final deleteRange = Range(
        change.range.start,
        change.range.start + change.removedLength,
      );
      contentChanges.add({
        'range': lspRangeFor(snapshot, deleteRange),
        'rangeLength': change.removedLength,
        'text': change.insertedText,
      });
      snapshot =
          '${snapshot.characters.getRange(0, change.range.start).toString()}'
          '${change.insertedText}'
          '${snapshot.characters.getRange(change.range.start + change.removedLength, snapshot.length).toString()}';
    }

    if (snapshot != resultingText) {
      syncDocumentText(resultingText);
      return;
    }

    _syncedText = resultingText;
    _documentVersion++;
    _cachedDocumentLinks = null;
    _cachedDocumentLinksVersion = -1;
    _notify('textDocument/didChange', {
      'textDocument': {'uri': documentUri, 'version': _documentVersion},
      'contentChanges': contentChanges,
    });
    _notify('textDocument/didSave', {
      'textDocument': {'uri': documentUri},
    });
    lspDiagLog(
      'didChange (incremental ${changes.length}) → server '
      '(${resultingText.length} chars, LSP v$_documentVersion)',
    );
  }

  bool get semanticTokensRange => _serverCaps.semanticTokensRange;

  Future<List<StyleSpan>> syncDocument(String text) =>
      fetchSemanticTokensFull(text);

  Future<List<StyleSpan>> fetchSemanticTokensFull(String text) async {
    if (!_ready) return const [];
    _pushDocument(text);
    return _requestSemanticTokensFull();
  }

  Future<List<StyleSpan>> fetchSemanticTokensRange(
    String text,
    Range range,
  ) async {
    if (!_ready || !_serverCaps.semanticTokensRange) return const [];
    _pushDocument(text);
    final result = await _call('textDocument/semanticTokens/range', {
      'textDocument': {'uri': documentUri},
      'range': lspRangeFor(text, range),
    });
    return _decodeSemanticTokens(result);
  }

  void _pushDocument(String text) {
    if (_syncedText == text) return;
    _syncedText = text;
    _documentVersion++;
    _cachedDocumentLinks = null;
    _cachedDocumentLinksVersion = -1;
    _notify('textDocument/didChange', {
      'textDocument': {'uri': documentUri, 'version': _documentVersion},
      'contentChanges': [
        {'text': text},
      ],
    });
    // Nudge analyzer to publish diagnostics (no disk write).
    _notify('textDocument/didSave', {
      'textDocument': {'uri': documentUri},
    });
  }

  Future<List<Range>> documentHighlights(String text, Position position) async {
    if (!_ready || !_serverCaps.documentHighlight) return const [];
    _pushDocument(text);
    final result = await _call('textDocument/documentHighlight', {
      'textDocument': {'uri': documentUri},
      'position': {'line': position.line, 'character': position.column},
    });
    if (result is! List) return const [];
    final ranges = <Range>[];
    for (final item in result) {
      if (item is! Map<String, dynamic>) continue;
      final range = item['range'];
      if (range is! Map<String, dynamic>) continue;
      ranges.add(rangeFromLsp(text, range));
    }
    return ranges;
  }

  Future<List<Range>?> linkedEditingRanges(
    String text,
    Position position,
  ) async {
    if (!_ready || !_serverCaps.linkedEditing) return null;
    _pushDocument(text);
    final result = await _call('textDocument/linkedEditingRange', {
      'textDocument': {'uri': documentUri},
      'position': {'line': position.line, 'character': position.column},
    });
    if (result is! Map<String, dynamic>) return null;
    final rangesRaw = result['ranges'];
    if (rangesRaw is! List) return null;
    final ranges = <Range>[];
    for (final item in rangesRaw) {
      if (item is! Map<String, dynamic>) continue;
      ranges.add(rangeFromLsp(text, item));
    }
    return ranges.isEmpty ? null : ranges;
  }

  Future<EditorDocumentLocation?> definition(
    String text,
    Position position,
  ) async {
    if (!_ready || !_serverCaps.definition) return null;
    _pushDocument(text);
    final result = await _call('textDocument/definition', {
      'textDocument': {'uri': documentUri},
      'position': {'line': position.line, 'character': position.column},
    });
    return documentLocationFromLsp(result, text);
  }

  Future<List<dynamic>> documentLinks(String text) async {
    if (!_ready || !_serverCaps.documentLink) return const [];
    _pushDocument(text);
    if (_cachedDocumentLinks != null &&
        _cachedDocumentLinksVersion == _documentVersion) {
      return _cachedDocumentLinks!;
    }
    final result = await _call('textDocument/documentLink', {
      'textDocument': {'uri': documentUri},
    });
    final links = result is List ? result : const [];
    _cachedDocumentLinks = links;
    _cachedDocumentLinksVersion = _documentVersion;
    return links;
  }

  Future<List<EditorInlayHint>> requestInlayHints(
    String text,
    Range range,
  ) async {
    if (!_ready || !_serverCaps.inlayHints) return const [];
    _pushDocument(text);
    final result = await _call('textDocument/inlayHint', {
      'textDocument': {'uri': documentUri},
      'range': lspRangeFor(text, range),
    });
    if (result is! List) return const [];
    final parsed = inlayHintsFromLsp(text, result);
    inlayHints = parsed;
    onInlayHints?.call(parsed);
    return parsed;
  }

  Future<EditorCompletionList?> completion(
    String text,
    Position position, {
    EditorCompletionTrigger trigger = EditorCompletionTrigger.invoked,
    String? triggerCharacter,
  }) async {
    if (!_ready || !_serverCaps.completion) return null;
    _pushDocument(text);
    final params = <String, Object?>{
      'textDocument': {'uri': documentUri},
      'position': {'line': position.line, 'character': position.column},
    };
    final kind = switch (trigger) {
      EditorCompletionTrigger.invoked => 1,
      EditorCompletionTrigger.triggerCharacter => 2,
      EditorCompletionTrigger.incomplete => 3,
    };
    params['context'] = {
      'triggerKind': kind,
      'triggerCharacter': ?triggerCharacter,
    };
    final result = await _call('textDocument/completion', params);
    return completionListFromLsp(
      text,
      offsetAtLspPosition(text, position),
      result,
      _completionResolveStore,
    );
  }

  Future<EditorCompletionItem?> resolveCompletionItem(
    String text,
    EditorCompletionItem item,
  ) async {
    if (!_ready || !_serverCaps.completionResolve) return item;
    final token = item.resolveToken;
    if (token == null) return item;
    final raw = _completionResolveStore[token];
    if (raw == null) return item;
    _pushDocument(text);
    final result = await _call('completionItem/resolve', {
      'completionItem': raw,
    });
    if (result is! Map<String, dynamic>) return item;
    return completionItemResolvedFromLsp(
      text,
      item.textEdit?.range ?? Range(0, 0),
      result,
      item,
      _completionResolveStore,
    );
  }

  Future<EditorHover?> hover(String text, Position position) async {
    if (!_ready || !_serverCaps.hover) return null;
    _pushDocument(text);
    final result = await _call('textDocument/hover', {
      'textDocument': {'uri': documentUri},
      'position': {'line': position.line, 'character': position.column},
    });
    return hoverFromLsp(text, result);
  }

  Future<EditorSignatureHelp?> signatureHelp(
    String text,
    Position position,
  ) async {
    if (!_ready || !_serverCaps.signatureHelp) return null;
    _pushDocument(text);
    final result = await _call('textDocument/signatureHelp', {
      'textDocument': {'uri': documentUri},
      'position': {'line': position.line, 'character': position.column},
    });
    return signatureHelpFromLsp(result);
  }

  Future<List<StyleSpan>> _requestSemanticTokensFull() async {
    if (!_serverCaps.semanticTokens) return const [];
    final result = await _call('textDocument/semanticTokens/full', {
      'textDocument': {'uri': documentUri},
    });
    return _decodeSemanticTokens(result);
  }

  List<StyleSpan> _decodeSemanticTokens(Object? result) {
    if (result is! Map<String, dynamic>) return const [];
    final data = result['data'] as List<dynamic>?;
    if (data == null) return const [];
    final text = _syncedText ?? '';
    if (text.isEmpty) return const [];
    return _decoder.decode(text, data.map((e) => (e as num).toInt()).toList());
  }

  bool _documentUriMatches(String? uri) {
    if (uri == null) return true;
    if (uri == documentUri) return true;
    return Uri.parse(uri) == Uri.parse(documentUri);
  }

  void _handlePublishDiagnostics(Object? params) {
    if (params is! Map<String, dynamic>) {
      lspDiagLog('publishDiagnostics: bad params type ${params.runtimeType}');
      return;
    }

    final uri = params['uri'] as String?;
    final version = params['version'];
    final raw = params['diagnostics'];
    final rawCount = raw is List ? raw.length : 0;

    lspDiagLog(
      'publishDiagnostics: raw=$rawCount version=$version\n'
      '  uri=$uri\n'
      '  expected=$documentUri\n'
      '  match=${_documentUriMatches(uri)}',
    );

    if (!_documentUriMatches(uri)) {
      lspDiagLog('ignored: diagnostics for another file');
      return;
    }

    final text = _syncedText ?? '';
    diagnostics = diagnosticsFromLsp(text, params);
    lspDiagLog(
      'parsed ${diagnostics.length} diagnostic(s), syncedText=${text.length} chars',
    );
    for (final d in diagnostics) {
      lspDiagLog(
        '  [${d.severity.name}] ${d.range.start}-${d.range.end}: ${d.message}',
      );
    }
    onDiagnostics?.call(diagnostics, text);
  }

  void _onMessage(Map<String, dynamic> message) {
    final id = message['id'];
    if (id is! int) {
      final method = message['method'];
      if (method == 'textDocument/publishDiagnostics') {
        _handlePublishDiagnostics(message['params']);
        return;
      }
      if (method == 'window/logMessage') {
        debugPrint('LSP: ${message['params']}');
        return;
      }
      lspDiagLog('notification (ignored): $method');
      return;
    }

    final completer = _pending.remove(id);
    if (completer == null) return;

    if (message['error'] != null) {
      final error = message['error'] as Map<String, dynamic>?;
      // Method not found — optional LSP feature unsupported by this server.
      if (error?['code'] != -32601) {
        debugPrint('LSP error: ${message['error']}');
      }
      completer.complete(null);
      return;
    }
    completer.complete(message['result']);
  }

  Future<dynamic> _call(String method, Map<String, Object?>? params) {
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    final message = <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
    };
    if (params != null) message['params'] = params;
    _send(message);
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove(id);
        return null;
      },
    );
  }

  void _notify(String method, Map<String, Object?> params) {
    _send({'jsonrpc': '2.0', 'method': method, 'params': params});
  }

  void _send(Map<String, Object?> message) {
    _process.stdin.add(lspEncode(message));
  }
}
