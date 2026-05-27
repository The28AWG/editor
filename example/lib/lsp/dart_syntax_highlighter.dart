import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:editor/editor.dart';
import 'package:example/lsp/dart_lsp_client.dart';
import 'package:example/lsp/highlight_debug.dart';
import 'package:example/lsp/lsp_refresh_range.dart';
import 'package:flutter/foundation.dart';

/// Loads Dart semantic highlighting via `dart language-server`.
///
/// При `lag > 0` (документ ушёл вперёд LSP-токенов) **не материализует**
/// сдвинутые spans — вместо этого отдаёт ленивый [PendingShiftedSyntaxLayer],
/// который проектирует исходный снимок [_sortedSpans] под запросы paint'а.
/// Слои [_syncSyntaxLayer] / [_pendingSyntaxLayer] переиспользуются между
/// keystroke'ами (стабильная ссылка для [StyleResolver.replaceLayers]).
final class DartSyntaxHighlighter {
  DartSyntaxHighlighter(this._client) {
    _pendingSyntaxLayer = PendingShiftedSyntaxLayer(
      sortedBase: _sortedSpans,
      pending: _pendingStyleChanges,
    );
    _syncSyntaxLayer = SyntaxStyleLayer(
      spans: _sortedSpans,
      alreadySorted: true,
    );
  }

  final DartLspClient _client;

  DartLspClient get client => _client;
  List<StyleSpan> _sortedSpans = const [];
  int _highlightVersion = -1;
  final _pendingStyleChanges = <DocumentChange>[];
  late SyntaxStyleLayer _syncSyntaxLayer;
  late PendingShiftedSyntaxLayer _pendingSyntaxLayer;
  Timer? _debounce;
  Timer? _lspSyncDebounce;
  final _pendingLspChanges = <DocumentChange>[];
  String Function()? _getDocumentText;
  DocumentChange? _lastRefreshChange;
  var _syncGeneration = 0;

  /// Document version the current tokens were computed for.
  int? get tokensDocumentVersion =>
      _highlightVersion >= 0 ? _highlightVersion : null;

  /// Отставание документа от LSP-токенов (для отладки).
  int? versionLag(int documentVersion) =>
      _highlightVersion >= 0 ? documentVersion - _highlightVersion : null;

  List<EditorDiagnostic> get diagnostics => _client.diagnostics;

  /// Подставляет палитру semantic tokens и перезапрашивает полный снимок.
  Future<void> applySemanticTokenColors(
    Map<String, Color> colors,
    String text,
    int documentVersion,
  ) async {
    _client.setSemanticTokenColors(colors);
    await _refreshNow(text, documentVersion, forceFull: true);
  }

  set onDiagnostics(
    void Function(List<EditorDiagnostic> diagnostics, String analyzedText)?
    handler,
  ) {
    _client.onDiagnostics = handler;
  }

  /// Возвращает синтаксический [StyleLayer] для [documentVersion] или `null`,
  /// если токены ещё не получены.
  StyleLayer? styleLayerFor(
    int documentVersion, {
    ViewportStyleScope? viewport,
  }) {
    if (_highlightVersion < 0 || _sortedSpans.isEmpty) return null;
    if (_highlightVersion > documentVersion) return null;
    if (documentVersion == _highlightVersion) {
      _syncSyntaxLayer
        ..replaceSortedSpans(_sortedSpans, alreadySorted: true)
        ..setSpanSearchBoundsFromViewport(viewport);
      _logViewportSearchBounds(
        'sync',
        viewport,
        _syncSyntaxLayer.spanSearchBounds,
      );
      return _syncSyntaxLayer;
    }
    final clipBefore = shouldClipStaleTail(_pendingStyleChanges)
        ? leftmostPendingStartInCurrentCoords(_pendingStyleChanges)
        : null;
    _pendingSyntaxLayer.syncFrom(
      sortedBase: _sortedSpans,
      pending: _pendingStyleChanges,
      documentVersion: documentVersion,
      clipBefore: clipBefore,
      viewport: viewport,
    );
    _logViewportSearchBounds(
      'pending',
      viewport,
      _pendingSyntaxLayer.spanSearchBounds,
    );
    return _pendingSyntaxLayer;
  }

  SpanSearchBounds? _lastLoggedViewportBounds;

  void _logViewportSearchBounds(
    String label,
    ViewportStyleScope? viewport,
    SpanSearchBounds? bounds,
  ) {
    if (viewport == null || !kHighlightDebug) return;
    final b = bounds;
    if (b != null &&
        _lastLoggedViewportBounds != null &&
        b.lo == _lastLoggedViewportBounds!.lo &&
        b.hi == _lastLoggedViewportBounds!.hi) {
      return;
    }
    _lastLoggedViewportBounds = b == null ? null : SpanSearchBounds(b.lo, b.hi);
    highlightDebugLog(
      'viewport $label layer spans=${_sortedSpans.length} '
      'docRange=[${viewport.documentRange.start},${viewport.documentRange.end}) '
      'search=${b?.lo ?? 0}..${b?.hi ?? _sortedSpans.length}',
    );
  }

  static Future<DartSyntaxHighlighter?> start() async {
    final root = _findProjectRoot();
    if (root == null) {
      debugPrint('DartSyntaxHighlighter: pubspec.yaml not found');
      return null;
    }
    final client = await DartLspClient.start(projectRoot: root);
    if (client == null) return null;
    return DartSyntaxHighlighter(client);
  }

  static String? _findProjectRoot() {
    if (kIsWeb) return null;
    var dir = Directory.current;
    for (var i = 0; i < 12; i++) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  Future<void> open(String text, int documentVersion) async {
    await _client.openDocument(text);
    await _refreshNow(text, documentVersion);
  }

  void noteDocumentChange(DocumentChange change, {int? documentVersion}) {
    final pendingBefore = _pendingStyleChanges.length;
    final sw = kHighlightDebug ? (Stopwatch()..start()) : null;
    var revertedFully = false;
    var undoReverted = 0;

    if (isUndoLikeChange(change)) {
      final coverable = _undoFullyCoveredByPending(change);
      if (coverable) {
        final before = _pendingStyleChanges.length;
        revertPendingChangesForUndo(_pendingStyleChanges, change);
        undoReverted = before - _pendingStyleChanges.length;
        revertedFully = true;
      } else {
        _pendingStyleChanges.add(change);
      }
    } else {
      _pendingStyleChanges.add(change);
    }
    coalesceAdjacentPendingInserts(_pendingStyleChanges);

    sw?.stop();
    final clipAnchor = leftmostPendingStartInCurrentCoords(
      _pendingStyleChanges,
    );
    final clipApplied =
        _pendingStyleChanges.isNotEmpty &&
        shouldClipStaleTail(_pendingStyleChanges);
    highlightDebugLog(
      'noteChange ${describeDocumentChange(change)}'
      '${isUndoLikeChange(change) ? ' [undo-like]' : ''}'
      '${isInsertLikeChange(change) ? ' [insert-like]' : ''}\n'
      '  highlightVersion=$_highlightVersion docVersion=$documentVersion '
      'lag=${documentVersion != null ? versionLag(documentVersion) : '?'}'
      '${revertedFully ? ' undoReverted=$undoReverted' : ''}\n'
      '  pending $pendingBefore -> ${_pendingStyleChanges.length} '
      '${summarizePendingChanges(_pendingStyleChanges)}\n'
      '  spans base=${_sortedSpans.length}'
      '${clipAnchor != null ? ' clipAnchor=$clipAnchor clipped=${clipApplied ? 'yes' : 'no'}' : ''}'
      '${sw != null ? ' rebuild=${sw.elapsedMicroseconds}µs' : ''}',
    );
  }

  bool _undoFullyCoveredByPending(DocumentChange undo) {
    if (_pendingStyleChanges.isEmpty) return false;
    var net = undo.removedLength;
    for (var i = _pendingStyleChanges.length - 1; i >= 0 && net > 0; i--) {
      final c = _pendingStyleChanges[i];
      net -= c.insertedText.length;
      net += c.removedLength;
    }
    return net == 0;
  }

  void scheduleDocumentSync(String Function() getText, DocumentChange change) {
    _pendingLspChanges.add(change);
    _getDocumentText = getText;
    _lspSyncDebounce?.cancel();
    _lspSyncDebounce = Timer(const Duration(milliseconds: 300), _flushLspSync);
    highlightDebugLog(
      'lspSync scheduled in 300ms (pendingLsp=${_pendingLspChanges.length})',
    );
  }

  void _flushLspSync() {
    final getText = _getDocumentText;
    if (getText == null) return;
    final text = getText();
    final changes = List<DocumentChange>.of(_pendingLspChanges);
    _pendingLspChanges.clear();
    _getDocumentText = null;
    highlightDebugLog(
      'lspSync flush ${changes.length} change(s) textLen=${text.length}',
    );
    if (changes.isEmpty) {
      _client.syncDocumentText(text);
    } else {
      _client.syncDocumentEdits(changes, text);
    }
  }

  void scheduleRefresh(
    int documentVersion, {
    required DocumentChange change,
    required String Function() currentDocumentText,
    required int Function() currentDocumentVersion,
    required void Function(int highlightedVersion) onUpdated,
  }) {
    _lastRefreshChange = change;
    noteDocumentChange(change, documentVersion: documentVersion);
    scheduleDocumentSync(currentDocumentText, change);

    final lag = versionLag(documentVersion);
    if (isUndoLikeChange(change) && lag != null && lag > 0) {
      _debounce?.cancel();
      highlightDebugLog(
        'semanticTokens undo lag=$lag → immediate full (no debounce)',
      );
      unawaited(
        _refreshNow(
          currentDocumentText(),
          documentVersion,
          refreshChange: change,
          onUpdated: onUpdated,
        ),
      );
      return;
    }

    _debounce?.cancel();
    highlightDebugLog(
      'semanticTokens debounce 250ms for docVersion=$documentVersion',
    );
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      await _refreshNow(
        currentDocumentText(),
        documentVersion,
        refreshChange: _lastRefreshChange,
        onUpdated: onUpdated,
      );
      final docVersion = currentDocumentVersion();
      if (docVersion != documentVersion) {
        highlightDebugLog(
          'semanticTokens catch-up docVersion $documentVersion -> $docVersion',
        );
        await _refreshNow(
          currentDocumentText(),
          docVersion,
          refreshChange: _lastRefreshChange,
          forceFull: true,
          onUpdated: onUpdated,
        );
      }
    });
  }

  Future<void> _refreshNow(
    String text,
    int documentVersion, {
    DocumentChange? refreshChange,
    bool forceFull = false,
    void Function(int highlightedVersion)? onUpdated,
  }) async {
    final sw = kHighlightDebug ? (Stopwatch()..start()) : null;
    _flushLspSync();
    final gen = ++_syncGeneration;
    final change = refreshChange ?? _lastRefreshChange;
    final useRange =
        !forceFull &&
        !needsFullSemanticRefresh(change) &&
        _client.semanticTokensRange &&
        _sortedSpans.isNotEmpty &&
        change != null;

    highlightDebugLog(
      'semanticTokens request gen=$gen mode=${useRange ? 'range' : 'full'} '
      'docVersion=$documentVersion textLen=${text.length} '
      'pendingStyle=${_pendingStyleChanges.length}',
    );

    List<StyleSpan> spans;
    if (useRange) {
      final refreshRange = expandSemanticRefreshRange(text, change);
      final patch = await _client.fetchSemanticTokensRange(text, refreshRange);
      if (patch.isEmpty) {
        highlightDebugLog('semanticTokens range empty → full');
        spans = await _client.fetchSemanticTokensFull(text);
      } else {
        spans = mergeStyleSpansForRange(_sortedSpans, patch, refreshRange);
        highlightDebugLog(
          'semanticTokens range merged refreshRange='
          '[${refreshRange.start},${refreshRange.end}) '
          'patch=${patch.length} total=${spans.length}',
        );
      }
    } else {
      spans = await _client.fetchSemanticTokensFull(text);
    }

    if (gen != _syncGeneration) {
      highlightDebugLog('semanticTokens stale gen=$gen (now $_syncGeneration)');
      return;
    }
    final pendingCleared = _pendingStyleChanges.length;
    _pendingStyleChanges.clear();
    _sortedSpans = sortedStyleSpans(spans);
    _lastLoggedViewportBounds = null;
    _highlightVersion = documentVersion;
    sw?.stop();
    highlightDebugLog(
      'semanticTokens done gen=$gen highlightVersion=$_highlightVersion '
      'spans=${_sortedSpans.length} clearedPending=$pendingCleared'
      '${sw != null ? ' total=${sw.elapsedMilliseconds}ms' : ''}',
    );
    onUpdated?.call(documentVersion);
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    _lspSyncDebounce?.cancel();
    _flushLspSync();
    await _client.dispose();
  }
}
