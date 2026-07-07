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

final class _SelectionStep {
  const _SelectionStep(this.selection, this.label);

  final Selection selection;
  final String label;
}

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
  final List<_SelectionStep> _selectionStack = [];
  var _regionBlocksShown = false;

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

  String get _activeSelectionLevelLabel =>
      _selectionStack.isEmpty ? 'каретка' : _selectionStack.last.label;

  void _pushSelectionIfNeeded(Selection sel, String label) {
    if (_selectionStack.isEmpty) {
      _selectionStack.add(_SelectionStep(sel, label));
      return;
    }
    final last = _selectionStack.last.selection;
    if (last.start == sel.start && last.end == sel.end) return;
    _selectionStack.add(_SelectionStep(sel, label));
  }

  void _shrinkSelection() {
    final primary = _controller.selection.primary;
    if (_selectionStack.isEmpty) {
      _selectionStack
        ..clear()
        ..add(
          _SelectionStep(
            primary,
            primary.isCollapsed ? 'каретка' : 'пользовательское',
          ),
        );
      return;
    }
    // Если пользователь выделил мышью — синхронизируем стек с текущим состоянием.
    final top = _selectionStack.last.selection;
    if (top.start != primary.start || top.end != primary.end) {
      _selectionStack
        ..clear()
        ..add(
          _SelectionStep(
            primary,
            primary.isCollapsed ? 'каретка' : 'пользовательское',
          ),
        );
      return;
    }
    if (_selectionStack.length <= 1) return;
    _selectionStack.removeLast();
    _controller.setPrimarySelection(_selectionStack.last.selection);
  }

  void _toggleRegionBlocks() {
    setState(() => _regionBlocksShown = !_regionBlocksShown);
    if (!_regionBlocksShown) {
      _controller.setRegionBlocks(const []);
      return;
    }
    _controller.setRegionBlocks(_demoRegionBlocks());
  }

  /// Тестовые блоки поверх текущего сэмпла: многострочный + два блока на одной строке.
  List<EditorRegionBlock> _demoRegionBlocks() {
    final text = _controller.document.text;
    final blocks = <EditorRegionBlock>[];

    // 1) Многострочный блок вокруг тела функции greet {...}.
    final greetBody = _rangeBetween(text, 'greet(String name', '}');
    if (greetBody != null) {
      blocks.add(
        EditorRegionBlock(
          range: greetBody,
          borderColor: const Color(0xFF4C8BF5),
          fillColor: const Color(0x224C8BF5),
        ),
      );
    }

    // 1b) Ещё один многострочный блок вокруг main {...}.
    final mainBody = _rangeBetween(text, 'void main()', '}');
    if (mainBody != null) {
      blocks.add(
        EditorRegionBlock(
          range: mainBody,
          borderColor: const Color(0xFFB07DFF),
          fillColor: const Color(0x22B07DFF),
        ),
      );
    }

    // 2) Два независимых блока на одной строке: name и count в вызове greet.
    final callArgs = _rangeOf(text, 'greet(name, count: count)');
    if (callArgs != null) {
      final nameRange = _rangeOf(text, 'name', from: callArgs.start);
      if (nameRange != null) {
        blocks.add(
          EditorRegionBlock(
            range: nameRange,
            borderColor: const Color(0xFF34A853),
            fillColor: const Color(0x2234A853),
          ),
        );
      }
      final countRange = _rangeOf(text, 'count: count', from: callArgs.start);
      if (countRange != null) {
        blocks.add(
          EditorRegionBlock(
            range: countRange,
            borderColor: const Color(0xFFEA4335),
            fillColor: const Color(0x22EA4335),
          ),
        );
      }
    }

    return blocks;
  }

  Range? _rangeOf(String text, String needle, {int from = 0}) {
    final i = text.indexOf(needle, from);
    if (i < 0) return null;
    return Range(i, i + needle.length);
  }

  Range? _rangeBetween(String text, String startNeedle, String endNeedle) {
    final s = text.indexOf(startNeedle);
    if (s < 0) return null;
    final e = text.indexOf(endNeedle, s + startNeedle.length);
    if (e < 0) return null;
    return Range(s, e + endNeedle.length);
  }

  void _expandSelection() {
    final primary = _controller.selection.primary;
    if (_selectionStack.isEmpty) {
      _selectionStack.add(
        _SelectionStep(
          primary,
          primary.isCollapsed ? 'каретка' : 'пользовательское',
        ),
      );
    }
    // Если пользователь выделил мышью — сбрасываем стек и начинаем от текущего.
    final top = _selectionStack.last.selection;
    final base = (top.start == primary.start && top.end == primary.end)
        ? top
        : primary;
    if (base.start != top.start || base.end != top.end) {
      _selectionStack
        ..clear()
        ..add(
          _SelectionStep(
            base,
            base.isCollapsed ? 'каретка' : 'пользовательское',
          ),
        );
    }

    final next = _computeNextSelection(base);
    _pushSelectionIfNeeded(next.selection, next.label);
    _controller.setPrimarySelection(next.selection);
  }

  _SelectionStep _computeNextSelection(Selection current) {
    final text = _controller.document.text;
    final len = text.length;
    if (len == 0) return const _SelectionStep(Selection(0, 0), 'каретка');

    final start = current.start.clamp(0, len);
    final end = current.end.clamp(0, len);
    final head = current.head.clamp(0, len);

    // 1) Схлопнутое выделение -> слово (или 1 символ).
    if (start == end) {
      final word = wordRangeAt(text, head);
      if (word != null && word.end > word.start) {
        return _SelectionStep(Selection(word.start, word.end), 'слово');
      }
      final nextEnd = (head + 1).clamp(0, len);
      if (nextEnd == head) {
        return _SelectionStep(Selection(head, head), 'каретка');
      }
      return _SelectionStep(Selection(head, nextEnd), 'символ');
    }

    // 2) Попытка расширить до "скобки/кавычки вокруг" (если текущий селект внутри пары).
    final pair = _enclosingPairRange(text, start, end);
    if (pair != null) {
      final open = text.codeUnitAt(pair.start);
      final label = switch (open) {
        0x28 => 'скобки ()',
        0x5B => 'скобки []',
        0x7B => 'скобки {}',
        0x22 => 'кавычки ""',
        0x27 => "кавычки ''",
        _ => 'пара',
      };
      return _SelectionStep(Selection(pair.start, pair.end), label);
    }

    // 3) Строка целиком.
    final line = _lineRange(text, start, end);
    if (line != null &&
        (line.start != start || line.end != end) &&
        (line.end - line.start) >= (end - start)) {
      return _SelectionStep(Selection(line.start, line.end), 'строка');
    }

    // 4) Блок {...} (упрощённо).
    final block = _enclosingBraceBlock(text, start, end);
    if (block != null) {
      return _SelectionStep(Selection(block.start, block.end), 'блок {}');
    }

    // 5) Весь документ.
    return _SelectionStep(Selection(0, len), 'документ');
  }

  Range? _lineRange(String text, int selStart, int selEnd) {
    final len = text.length;
    if (len == 0) return null;

    var left = selStart.clamp(0, len);
    var right = selEnd.clamp(0, len);

    while (left > 0 && text.codeUnitAt(left - 1) != 0x0A) {
      left--;
    }
    while (right < len && text.codeUnitAt(right) != 0x0A) {
      right++;
    }
    return Range(left, right);
  }

  Range? _enclosingPairRange(String text, int selStart, int selEnd) {
    final len = text.length;
    if (len == 0) return null;

    // Приоритет: если уже выделили часть внутри (), [], {}, '' или "" — расширяем до пары.
    final pairs = <(int open, int close)>[
      (0x28, 0x29), // ()
      (0x5B, 0x5D), // []
      (0x7B, 0x7D), // {}
      (0x22, 0x22), // ""
      (0x27, 0x27), // ''
    ];

    for (final p in pairs) {
      final r = _enclosingPairRangeFor(text, selStart, selEnd, p.$1, p.$2);
      if (r != null) return r;
    }
    return null;
  }

  Range? _enclosingPairRangeFor(
    String text,
    int selStart,
    int selEnd,
    int open,
    int close,
  ) {
    final len = text.length;
    var left = selStart.clamp(0, len);
    // selEnd здесь нужен только для проверки попадания в диапазон.
    final right = selEnd.clamp(0, len);

    // Ищем ближайший open слева (до 2k символов, чтобы не лагало на огромных файлах).
    const maxScan = 2000;
    var scanned = 0;
    var openIndex = -1;
    while (left > 0 && scanned < maxScan) {
      left--;
      scanned++;
      if (text.codeUnitAt(left) == open) {
        openIndex = left;
        break;
      }
      // Упрощение: не перескакиваем через переводы строк для кавычек.
      if ((open == 0x22 || open == 0x27) && text.codeUnitAt(left) == 0x0A) {
        break;
      }
    }
    if (openIndex < 0) return null;

    // Ищем закрывающую справа.
    scanned = 0;
    var i = openIndex + 1;
    var depth = 0;
    while (i < len && scanned < maxScan) {
      final cu = text.codeUnitAt(i);
      scanned++;
      if (open != close) {
        if (cu == open) depth++;
        if (cu == close) {
          if (depth == 0) {
            final start = openIndex;
            final end = i + 1;
            if (start <= selStart && right <= end) return Range(start, end);
            return null;
          }
          depth--;
        }
      } else {
        if (cu == close) {
          final start = openIndex;
          final end = i + 1;
          if (start <= selStart && right <= end) return Range(start, end);
          return null;
        }
        if (cu == 0x0A) break;
      }
      i++;
    }
    return null;
  }

  Range? _enclosingBraceBlock(String text, int selStart, int selEnd) {
    final len = text.length;
    if (len == 0) return null;

    // Очень упрощённо: ищем '{' слева и подбираем ближайшую '}' справа с учётом глубины.
    const maxScan = 4000;
    var scanned = 0;
    var left = selStart.clamp(0, len);
    var openIndex = -1;
    while (left > 0 && scanned < maxScan) {
      left--;
      scanned++;
      if (text.codeUnitAt(left) == 0x7B) {
        openIndex = left;
        break;
      }
    }
    if (openIndex < 0) return null;

    scanned = 0;
    var i = openIndex + 1;
    var depth = 0;
    while (i < len && scanned < maxScan) {
      final cu = text.codeUnitAt(i);
      scanned++;
      if (cu == 0x7B) depth++;
      if (cu == 0x7D) {
        if (depth == 0) {
          final start = openIndex;
          final end = i + 1;
          if (start <= selStart && selEnd <= end) return Range(start, end);
          return null;
        }
        depth--;
      }
      i++;
    }
    return null;
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
          ListenableBuilder(
            listenable: _controller,
            builder: (context, child) => IconButton(
              tooltip: 'Сузить выделение',
              icon: const Icon(Icons.unfold_less),
              onPressed: _selectionStack.length > 1 ? _shrinkSelection : null,
            ),
          ),
          IconButton(
            tooltip: 'Расширить выделение',
            icon: const Icon(Icons.unfold_more),
            onPressed: _expandSelection,
          ),
          IconButton(
            tooltip: _regionBlocksShown
                ? 'Скрыть блоки-рамки'
                : 'Показать блоки-рамки',
            isSelected: _regionBlocksShown,
            icon: const Icon(Icons.crop_free),
            onPressed: _toggleRegionBlocks,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, child) => Text(
                  _activeSelectionLevelLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          ),
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
