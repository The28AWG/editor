import 'dart:ffi';
import 'dart:io';

import 'package:editor/editor.dart';
import 'package:example/tree_sitter/tree_sitter_native_config.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tree_sitter/tree_sitter.dart';

/// Быстрая синтаксическая подсветка Dart через tree-sitter (FFI).
///
/// Приоритет span'ов `40` — ниже LSP semantic (`50`), чтобы вторая волна перекрывала первую.
final class DartTreeSitterSyntaxHighlighter {
  DartTreeSitterSyntaxHighlighter._(this._parser, this._query)
    : _captureColors = const {},
      _syntaxLayer = SyntaxStyleLayer(
        spans: const [],
        layerPriority: _syntaxPriority,
      );

  static const _syntaxPriority = 40;

  final Parser _parser;
  final Query _query;
  final SyntaxStyleLayer _syntaxLayer;
  Map<String, Color> _captureColors;

  List<StyleSpan> _sortedSpans = const [];
  var _highlightVersion = -1;
  String? _lastText;

  int? get highlightVersion =>
      _highlightVersion >= 0 ? _highlightVersion : null;

  /// Создаёт highlighter или `null`, если нативные библиотеки недоступны.
  static Future<DartTreeSitterSyntaxHighlighter?> tryCreate() async {
    if (kIsWeb) return null;
    if (!TreeSitterNativeConfig.ensureConfigured()) {
      debugPrint('DartTreeSitterSyntaxHighlighter: native libs not configured');
      return null;
    }

    try {
      final querySource = await _loadHighlightsQuery();
      if (querySource == null) {
        debugPrint('DartTreeSitterSyntaxHighlighter: highlights.scm not found');
        return null;
      }

      final parser = Parser(
        sharedLibrary: TreeSitterNativeConfig.dartGrammarLibraryPath,
        entryPoint: TreeSitterNativeConfig.dartGrammarEntryPoint,
      );
      final probe = parser.parse('void main() {}');
      final language = treeSitterApi.ts_tree_language(probe.tree);
      final query = Query.fromSource(language: language, source: querySource);
      return DartTreeSitterSyntaxHighlighter._(parser, query);
    } on Object catch (e, st) {
      debugPrint('DartTreeSitterSyntaxHighlighter: $e\n$st');
      return null;
    }
  }

  static Future<String?> _loadHighlightsQuery() async {
    try {
      return await rootBundle.loadString('native/queries/highlights.scm');
    } on Object {
      // Desktop / flutter test из каталога example
    }
    final root = TreeSitterNativeConfig.examplePackageRoot;
    if (root == null) return null;
    final file = File('$root/native/queries/highlights.scm');
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  }

  /// Синхронно пересчитывает span'ы для [text] / [documentVersion].
  void apply(String text, int documentVersion) {
    _lastText = text;
    _sortedSpans = sortedStyleSpans(_highlight(text));
    _highlightVersion = documentVersion;
    _syntaxLayer.replaceSortedSpans(_sortedSpans, alreadySorted: true);
  }

  /// Подставляет палитру capture (`highlights.scm`) и пересчитывает снимок.
  void setCaptureColors(Map<String, Color> colors) {
    _captureColors = colors;
    final text = _lastText;
    final version = _highlightVersion;
    if (text != null && version >= 0) apply(text, version);
  }

  /// Слой для [EditorHost.styleLayersFor] или `null`, если ещё не было [apply].
  StyleLayer? styleLayerFor(
    int documentVersion, {
    ViewportStyleScope? viewport,
  }) {
    if (_highlightVersion < 0 || _sortedSpans.isEmpty) return null;
    if (_highlightVersion != documentVersion) return null;
    _syntaxLayer.updateViewport(viewport);
    return _syntaxLayer;
  }

  List<StyleSpan> _highlight(String text) {
    if (text.isEmpty) return const [];

    final tree = _parser.parse(text);
    final api = treeSitterApi;
    final cursor = QueryCursor();
    final match = calloc<TSQueryMatch>();
    final captureIndex = calloc<Uint32>();
    final spans = <StyleSpan>[];

    try {
      api.ts_query_cursor_exec(cursor.cursor, _query.query, tree.root);
      while (api.ts_query_cursor_next_capture(
        cursor.cursor,
        match,
        captureIndex,
      )) {
        final i = captureIndex.value;
        if (i >= match.ref.capture_count) continue;

        final capture = (match.ref.captures + i).ref;
        final node = capture.node;
        if (node.isNull) continue;

        final start = node.startByte;
        final end = node.endByte;
        if (start < 0 || end <= start || end > text.length) continue;

        final lenPtr = calloc<Uint32>();
        try {
          final namePtr = api.ts_query_capture_name_for_id(
            _query.query,
            capture.index,
            lenPtr,
          );
          if (namePtr == nullptr) continue;
          final name = namePtr.cast<Utf8>().toDartString();
          if (name == 'none') continue;

          final color = _captureColors[name];
          if (color == null) continue;

          spans.add(
            StyleSpan(
              range: Range(start, end),
              color: color,
              priority: _syntaxPriority,
            ),
          );
        } finally {
          malloc.free(lenPtr);
        }
      }
    } finally {
      malloc
        ..free(match)
        ..free(captureIndex);
    }

    return spans;
  }
}
