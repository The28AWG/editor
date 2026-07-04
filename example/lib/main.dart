import 'dart:async';

import 'package:editor/editor.dart';
import 'package:example/appearance/app_appearance_controller.dart';
import 'package:example/appearance/app_appearance_scope.dart';
import 'package:example/appearance/dart_editor_appearance.dart';
import 'package:example/example_language_services.dart';
import 'package:example/lsp/dart_language_service.dart';
import 'package:example/lsp/dart_syntax_highlighter.dart';
import 'package:example/lsp/highlight_debug.dart';
import 'package:example/lsp/lsp_debug.dart';
import 'package:example/overlay/dart_lsp_overlay_controller.dart';
import 'package:example/overlay/editor_overlay_demos.dart';
import 'package:example/selection_debug.dart';
import 'package:example/tree_sitter/dart_tree_sitter_highlighter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(EditorExampleApp(controller: AppAppearanceController()));
}

class EditorExampleApp extends StatelessWidget {
  const EditorExampleApp({required this.controller, super.key});

  final AppAppearanceController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, child) => MaterialApp(
      theme: controller.materialTheme,
      themeAnimationDuration: Duration.zero,
      home: AppAppearanceScope(
        controller: controller,
        child: const EditorBootstrapPage(),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
}

/// Прогрев language services, затем редактор.
class EditorBootstrapPage extends StatefulWidget {
  const EditorBootstrapPage({super.key});

  @override
  State<EditorBootstrapPage> createState() => _EditorBootstrapPageState();
}

class _EditorBootstrapPageState extends State<EditorBootstrapPage> {
  ExampleLanguageServices? _services;
  var _warmupPhase = 'language services…';
  String? _error;

  static const _sample = EditorDemoPage.sampleText;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final services = await ExampleLanguageServices.warmUp(
        initialText: _sample,
        onPhase: (phase) {
          if (!mounted) return;
          setState(() => _warmupPhase = phase);
        },
      );
      if (!mounted) {
        await services.dispose();
        return;
      }
      setState(() => _services = services);
    } on Object catch (e, st) {
      if (!mounted) return;
      setState(() => _error = '$e\n$st');
    }
  }

  @override
  void dispose() {
    unawaited(_services?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final err = _error;
    if (err != null) {
      return Scaffold(body: Center(child: Text('Warmup failed:\n$err')));
    }
    final services = _services;
    if (services == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_warmupPhase),
            ],
          ),
        ),
      );
    }
    return EditorDemoPage(
      services: services,
      appearanceController: AppAppearanceScope.of(context),
    );
  }
}

class EditorDemoPage extends StatefulWidget {
  const EditorDemoPage({
    required this.services,
    required this.appearanceController,
    super.key,
  });

  final ExampleLanguageServices services;
  final AppAppearanceController appearanceController;

  static const sampleText = '''
import 'dart:async';

void greet(String name, {int count = 1}) {
  greet(name, count: count);
}

void main() {
  greet("world", count: 2);
  // https://dart.dev
}
''';

  @override
  State<EditorDemoPage> createState() => _EditorDemoPageState();
}

class _EditorDemoPageState extends State<EditorDemoPage> with EditorHost {
  late final EditorController _controller;
  late final Stopwatch _sinceStart;
  String? _appliedAppearanceName;
  DartLanguageService? _languageService;
  DartLspOverlayController? _lspOverlays;

  DartSyntaxHighlighter? get _lspHighlighter => widget.services.lsp;
  DartTreeSitterSyntaxHighlighter? get _treeSitterHighlighter =>
      widget.services.treeSitter;

  String get _statusLine => widget.services.toString();

  String _styleDbg(String label, Object? layer, int callUs) {
    final kind = layer == null ? 'null' : layer.runtimeType;
    return '[+${_sinceStart.elapsedMilliseconds}ms] $label: $kind ($callUsµs)';
  }

  @override
  void initState() {
    super.initState();
    _sinceStart = Stopwatch()..start();
    // ignore: avoid_print (debug)
    print(
      '[+0ms] editor: open (warmup ${widget.services.sinceStart.elapsedMilliseconds}ms)',
    );

    final appearance = widget.appearanceController.appearance;
    _controller = EditorController(
      initialText: EditorDemoPage.sampleText,
      host: this,
      theme: appearance.theme,
    );
    _appliedAppearanceName = appearance.name;
    _applyEditorAppearance(appearance);

    final lsp = _lspHighlighter;
    if (lsp != null) {
      lsp.onDiagnostics = (diagnostics, analyzedText) {
        if (!mounted) return;
        final editorText = _controller.document.text;
        if (editorText != analyzedText) {
          lspDiagLog(
            'UI skip stale diagnostics: editor=${editorText.length} chars '
            'analyzed=${analyzedText.length} chars',
          );
          return;
        }
        lspDiagLog('UI setDiagnostics(${diagnostics.length})');
        _controller.setDiagnostics(diagnostics);
      };
      _controller
        ..setDiagnostics(lsp.diagnostics)
        ..setLanguageService(
          _languageService = DartLanguageService(lsp.client),
        );
      _lspOverlays = DartLspOverlayController(
        controller: _controller,
        languageService: _languageService!,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appearance = widget.appearanceController.appearance;
    if (_appliedAppearanceName == appearance.name) return;
    _appliedAppearanceName = appearance.name;
    _applyEditorAppearance(appearance);
  }

  void _applyEditorAppearance(DartEditorAppearance appearance) {
    _controller.updateTheme(appearance.theme);
    _treeSitterHighlighter?.setCaptureColors(
      appearance.treeSitterCaptureColors,
    );
    _controller.refreshStyleLayers();
    final lsp = _lspHighlighter;
    if (lsp == null) return;
    unawaited(_refreshLspColors(lsp, appearance.lspSemanticColors));
  }

  Future<void> _refreshLspColors(
    DartSyntaxHighlighter lsp,
    Map<String, Color> colors,
  ) async {
    await lsp.applySemanticTokenColors(
      colors,
      _controller.document.text,
      _controller.document.version,
    );
    if (!mounted) return;
    _controller.refreshStyleLayers();
  }

  @override
  void dispose() {
    _lspOverlays?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onOverlayMenu(String value) {
    final lsp = _lspOverlays;
    switch (value) {
      case 'completion':
        if (lsp != null) {
          unawaited(lsp.showCompletion());
        } else {
          EditorOverlayDemos.showCompletion(_controller);
        }
      case 'hover':
        if (lsp != null) {
          unawaited(lsp.showHover());
        } else {
          EditorOverlayDemos.showHover(_controller);
        }
      case 'signature':
        if (lsp != null) {
          unawaited(lsp.showSignatureHelp());
        } else {
          EditorOverlayDemos.showSignatureHelp(_controller);
        }
      case 'find':
        if (lsp != null) {
          lsp.showFindBar();
        } else {
          EditorOverlayDemos.showFindBar(_controller);
        }
      case 'hide':
        if (lsp != null) {
          lsp.hideAll();
        } else {
          EditorOverlayDemos.hideAll(_controller);
        }
    }
  }

  @override
  List<StyleLayer> styleLayersFor(
    int documentVersion, {
    ViewportStyleScope? viewport,
  }) {
    final layers = <StyleLayer>[];
    final tsSw = Stopwatch()..start();
    final treeSitter = _treeSitterHighlighter?.styleLayerFor(
      documentVersion,
      viewport: viewport,
    );
    // ignore: avoid_print (debug)
    print(_styleDbg('treeSitter', treeSitter, tsSw.elapsedMicroseconds));
    if (treeSitter != null) layers.add(treeSitter);
    final lspSw = Stopwatch()..start();
    final lsp = _lspHighlighter?.styleLayerFor(
      documentVersion,
      viewport: viewport,
    );
    // ignore: avoid_print (debug)
    print(_styleDbg('lsp', lsp, lspSw.elapsedMicroseconds));
    if (lsp != null) layers.add(lsp);
    return layers;
  }

  @override
  void onSelectionChanged(SelectionChange change) {
    selectionChangeLog(_controller.document, change);
  }

  @override
  String? get editorDocumentUri => _lspHighlighter?.client.documentUri;

  @override
  void onNavigate(EditorDocumentLocation location) {
    if (!mounted) return;
    final dest = Uri.tryParse(location.uri);
    if (dest != null && (dest.scheme == 'http' || dest.scheme == 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Веб-ссылка: ${location.uri}'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    final open = editorDocumentUri;
    if (open == null) return;
    if (Uri.parse(open) != Uri.parse(location.uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Внешний файл: ${location.uri}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void onDocumentChanged(DocumentChange change) {
    final doc = _controller.document;
    final lsp = _lspHighlighter;
    final ts = _treeSitterHighlighter;
    if (ts != null) {
      ts.apply(doc.text, doc.version);
      _controller.refreshStyleLayers();
    }
    highlightDebugLog(
      'onDocumentChanged doc.version=${doc.version} '
      'treeSitterVersion=${ts?.highlightVersion} '
      'lspVersion=${lsp?.tokensDocumentVersion} '
      'lag=${lsp?.versionLag(doc.version)} '
      'textLen=${doc.length}',
    );
    lspDiagLog('onDocumentChanged v${doc.version} (${doc.length} chars)');
    lsp?.scheduleRefresh(
      doc.version,
      change: change,
      currentDocumentText: () => _controller.document.text,
      currentDocumentVersion: () => _controller.document.version,
      onUpdated: (highlightedVersion) {
        if (!mounted) return;
        if (_controller.document.version != highlightedVersion) {
          highlightDebugLog(
            'refreshStyleLayers skip stale highlight=$highlightedVersion '
            'doc=${_controller.document.version}',
          );
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_controller.document.version != highlightedVersion) return;
          _controller.refreshStyleLayers();
        });
      },
    );
  }

  Object? _onShowCompletionInvoke(_ShowCompletionIntent intent) {
    final lsp = _lspOverlays;
    if (lsp != null) {
      unawaited(lsp.showCompletion());
    } else {
      EditorOverlayDemos.showCompletion(_controller);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appearance = widget.appearanceController.appearance;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('editor example'),
            Text(_statusLine, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Overlay demos',
            icon: const Icon(Icons.layers),
            onSelected: _onOverlayMenu,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'completion',
                child: ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: const Text('Completion'),
                  subtitle: Text(
                    _lspOverlays != null
                        ? 'Ctrl+Space (LSP)'
                        : 'Ctrl+Space (mock)',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'hover',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Hover'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'signature',
                child: ListTile(
                  leading: Icon(Icons.functions),
                  title: Text('Signature help'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'find',
                child: ListTile(
                  leading: Icon(Icons.search),
                  title: Text('Find bar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'hide',
                child: ListTile(
                  leading: Icon(Icons.layers_clear),
                  title: Text('Hide all overlays'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          PopupMenuButton<DartEditorAppearance>(
            tooltip: 'Цветовая схема',
            initialValue: appearance,
            onSelected: widget.appearanceController.setAppearance,
            itemBuilder: (context) => [
              for (final scheme in widget.appearanceController.catalog)
                PopupMenuItem(value: scheme, child: Text(scheme.name)),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.palette,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 4),
                  Text(appearance.name),
                ],
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, child) => IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _controller.canUndo ? _controller.undo : null,
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, child) => IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _controller.canRedo ? _controller.redo : null,
            ),
          ),
        ],
      ),
      body: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space, control: true):
              _ShowCompletionIntent(),
        },
        child: Actions(
          actions: {
            _ShowCompletionIntent: CallbackAction<_ShowCompletionIntent>(
              onInvoke: _onShowCompletionInvoke,
            ),
          },
          child: EditorView(
            controller: _controller,
            host: this,
            showGutter: true,
          ),
        ),
      ),
    );
  }
}

final class _ShowCompletionIntent extends Intent {
  const _ShowCompletionIntent();
}
