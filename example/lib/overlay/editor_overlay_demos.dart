import 'dart:async';

import 'package:editor/editor.dart';
import 'package:example/overlay/completion_overlay_layout.dart';
import 'package:flutter/material.dart';

/// Демонстрационные overlay для example-приложения.
///
/// Показывает типичные сценарии IDE: completion + documentation,
/// hover, signature help и sticky find bar.
abstract final class EditorOverlayDemos {
  EditorOverlayDemos._();

  static final _completionSelection = ValueNotifier(0);
  static final _filteredCompletionItems =
      ValueNotifier<List<_DemoCompletionItem>>([]);

  static EditorController? _completionController;
  static int? _lastTypedCompletionVersion;
  static Timer? _typingCompletionTimer;

  static const _allCompletionItems = [
    _DemoCompletionItem(
      label: 'greet',
      detail: '(String name, {int count})',
      kind: Icons.functions,
      documentation: '''
```dart
void greet(String name, {int count = 1})
```

Печатает приветствие [name] [count] раз.

Параметр [count] по умолчанию равен 1.
''',
    ),
    _DemoCompletionItem(
      label: 'main',
      detail: '()',
      kind: Icons.play_arrow,
      documentation: 'Точка входа программы.',
    ),
    _DemoCompletionItem(
      label: 'Future',
      detail: '<T>',
      kind: Icons.class_,
      documentation:
          'Представляет результат асинхронной операции, доступный в будущем.',
    ),
    _DemoCompletionItem(
      label: 'async',
      detail: '',
      kind: Icons.bolt,
      documentation: 'Модификатор для функций и методов с `await`.',
    ),
  ];

  /// Autocomplete у каретки с documentation pane справа.
  static void showCompletion(EditorController controller) {
    _ensureCompletionListener(controller);

    final text = controller.document.text;
    final head = controller.selection.primary.head;
    final replaceRange = wordRangeAt(text, head) ?? Range(head, head);
    final filtered = _filterCompletionItems(text, head);
    if (filtered.isEmpty) {
      _hideDemoCompletion(controller);
      return;
    }

    _filteredCompletionItems.value = filtered;

    final alreadyOpen = controller.overlays.sessions.any(
      (s) => s.id == 'demo-completion',
    );
    if (!alreadyOpen) {
      _completionSelection.value = 0;
    } else {
      final max = filtered.length - 1;
      if (_completionSelection.value > max) {
        _completionSelection.value = max;
      }
    }

    controller.overlays.show(
      EditorOverlayDescriptor(
        id: 'demo-completion',
        kind: EditorOverlayKind.completion,
        priority: 100,
        keyboardPolicy: EditorOverlayKeyboardPolicy.cooperative,
        onKeyEvent: _onDemoCompletionKey,
        anchor: EditorCaretOverlayAnchor(replaceRange: replaceRange),
        layout: CompletionOverlayLayout.listPolicy,
        dismissPolicy: const EditorOverlayDismissPolicy(
          scroll: false,
          trackAnchorOnScroll: true,
          selectionChange: false,
        ),
        builder: (context, session) => ListenableBuilder(
          listenable: Listenable.merge([
            _filteredCompletionItems,
            _completionSelection,
          ]),
          builder: (context, _) => _CompletionListDemo(
            items: _filteredCompletionItems.value,
            selection: _completionSelection,
            onSelect: (item) => _acceptDemoCompletion(controller, item),
          ),
        ),
        children: [
          EditorOverlayDescriptor(
            id: 'demo-completion-details',
            kind: EditorOverlayKind.completion,
            priority: 101,
            anchor: const EditorViewportOverlayAnchor(),
            layout: const EditorOverlayLayoutPolicy(
              placement: EditorOverlayPlacement.besideEnd,
              childAlign: EditorOverlayChildAlign.start,
              clampToViewport: false,
              resizable: true,
              draggable: true,
              dragHandle: EditorOverlayDragHandle.custom,
              preferredWidth: 320,
              preferredHeight: 200,
              maxWidth: 480,
              maxHeight: 360,
              minWidth: 200,
              minHeight: 120,
            ),
            dismissPolicy: const EditorOverlayDismissPolicy(
              scroll: false,
              documentChange: false,
              selectionChange: false,
              exclusiveWithinKind: false,
            ),
            builder: (context, session) => ListenableBuilder(
              listenable: Listenable.merge([
                _filteredCompletionItems,
                _completionSelection,
              ]),
              builder: (context, _) => _CompletionDetailsDemo(
                items: _filteredCompletionItems.value,
                selection: _completionSelection,
                onResize: session.resize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hover над словом под кареткой.
  static void showHover(EditorController controller) {
    final text = controller.document.text;
    final head = controller.selection.primary.head;
    final word = wordRangeAt(text, head);
    if (word == null) return;

    controller.overlays.show(
      EditorOverlayDescriptor(
        id: 'demo-hover',
        kind: EditorOverlayKind.hover,
        priority: 50,
        anchor: EditorRangeOverlayAnchor(word),
        layout: const EditorOverlayLayoutPolicy(
          maxWidth: 420,
          preferredWidth: 360,
        ),
        dismissPolicy: const EditorOverlayDismissPolicy(
          selectionChange: true,
          trackAnchorOnScroll: true,
          scroll: false,
        ),
        builder: (context, session) => const _HoverDemoPanel(),
      ),
    );
  }

  /// Signature help внутри вызова функции.
  static void showSignatureHelp(EditorController controller) {
    controller.overlays.show(
      EditorOverlayDescriptor(
        id: 'demo-signature',
        kind: EditorOverlayKind.signature,
        priority: 80,
        capturesKeyboard: true,
        anchor: const EditorCaretOverlayAnchor(),
        layout: const EditorOverlayLayoutPolicy(
          placement: EditorOverlayPlacement.above,
          maxWidth: 480,
        ),
        dismissPolicy: const EditorOverlayDismissPolicy(
          scroll: false,
          trackAnchorOnScroll: true,
        ),
        builder: (context, session) => const _SignatureHelpDemo(),
      ),
    );
  }

  /// Sticky find bar у верхнего края viewport.
  static void showFindBar(EditorController controller) {
    controller.overlays.show(
      EditorOverlayDescriptor(
        id: 'demo-find',
        kind: EditorOverlayKind.sticky,
        priority: 200,
        capturesKeyboard: true,
        anchor: const EditorViewportOverlayAnchor(
          edge: EditorViewportEdge.top,
          margin: EdgeInsets.only(left: 8, top: 8, right: 8),
        ),
        layout: const EditorOverlayLayoutPolicy(
          placement: EditorOverlayPlacement.below,
          preferredWidth: 360,
          preferredHeight: 40,
          maxHeight: 48,
        ),
        dismissPolicy: const EditorOverlayDismissPolicy(
          outsidePointerDown: false,
          scroll: false,
          documentChange: false,
          selectionChange: false,
        ),
        builder: (context, session) => _FindBarDemo(onClose: session.hide),
      ),
    );
  }

  static void hideAll(EditorController controller) {
    _detachCompletionListener();
    controller.overlays.hideAll();
  }

  static void _ensureCompletionListener(EditorController controller) {
    if (_completionController == controller) return;
    _completionController?.removeListener(_onDemoCompletionControllerChanged);
    _completionController = controller;
    controller.addListener(_onDemoCompletionControllerChanged);
  }

  static void _onDemoCompletionControllerChanged() {
    final controller = _completionController;
    if (controller == null) return;
    if (!controller.overlays.sessions.any((s) => s.id == 'demo-completion')) {
      _detachCompletionListener();
      return;
    }
    final version = controller.document.version;
    if (_lastTypedCompletionVersion == version) return;
    _lastTypedCompletionVersion = version;
    _typingCompletionTimer?.cancel();
    _typingCompletionTimer = Timer(const Duration(milliseconds: 200), () {
      showCompletion(controller);
    });
  }

  static void _detachCompletionListener() {
    _typingCompletionTimer?.cancel();
    _completionController?.removeListener(_onDemoCompletionControllerChanged);
    _completionController = null;
    _lastTypedCompletionVersion = null;
  }

  static List<_DemoCompletionItem> _filterCompletionItems(
    String text,
    int head,
  ) {
    final range = wordRangeAt(text, head) ?? Range(head, head);
    final prefix = text.characters
        .getRange(range.start, range.end)
        .toString()
        .toLowerCase();
    if (prefix.isEmpty) {
      return List<_DemoCompletionItem>.of(_allCompletionItems);
    }

    final result = <_DemoCompletionItem>[];
    for (final item in _allCompletionItems) {
      if (item.label.toLowerCase().startsWith(prefix)) {
        result.add(item);
      }
    }
    return result;
  }

  static void _acceptDemoCompletion(
    EditorController controller,
    _DemoCompletionItem item,
  ) {
    final text = controller.document.text;
    final head = controller.selection.primary.head;
    final replaceRange = wordRangeAt(text, head) ?? Range(head, head);
    controller.apply([TextEdit.replace(replaceRange, item.insertedText)]);
    _hideDemoCompletion(controller);
  }

  static void _hideDemoCompletion(EditorController controller) {
    _detachCompletionListener();
    controller.overlays.hide('demo-completion');
  }

  static KeyEventResult _onDemoCompletionKey(KeyEvent event) {
    final controller = _completionController;
    if (controller == null) return KeyEventResult.ignored;
    final items = _filteredCompletionItems.value;
    return CompletionOverlayStyle.listNavigationKey(
      event,
      itemCount: items.length,
      selection: _completionSelection,
      onAccept: items.isEmpty
          ? null
          : () => _acceptDemoCompletion(
              controller,
              items[_completionSelection.value],
            ),
    );
  }
}

final class _DemoCompletionItem {
  const _DemoCompletionItem({
    required this.label,
    required this.detail,
    required this.kind,
    required this.documentation,
  });

  final String label;
  final String detail;
  final IconData kind;
  final String documentation;

  /// Текст вставки по [detail]: `greet` + `(…)` → `greet()`, `<T>` → `Future<>`.
  String get insertedText {
    if (detail.startsWith('(')) return '$label()';
    if (detail.startsWith('<')) return '$label<>';
    return label;
  }
}

final class _CompletionListDemo extends StatelessWidget {
  const _CompletionListDemo({
    required this.items,
    required this.selection,
    required this.onSelect,
  });

  final List<_DemoCompletionItem> items;
  final ValueNotifier<int> selection;
  final ValueChanged<_DemoCompletionItem> onSelect;

  void _onItemFocusChange(int index, bool focused) {
    if (focused) selection.value = index;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = CompletionOverlayLayout.listWidth(
      context,
      labels: [for (final item in items) item.label],
      details: [for (final item in items) item.detail],
    );
    return SizedBox(
      width: width,
      child: Material(
        color: CompletionOverlayStyle.background(theme.colorScheme),
        child: ValueListenableBuilder<int>(
          valueListenable: selection,
          builder: (context, selected, _) => ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                dense: true,
                selected: index == selected,
                leading: Icon(item.kind, size: 18),
                title: Text(
                  item.label,
                  style: CompletionOverlayStyle.label(theme),
                ),
                subtitle: item.detail.isEmpty
                    ? null
                    : Text(
                        item.detail,
                        style: CompletionOverlayStyle.detail(theme),
                      ),
                onTap: () => onSelect(item),
                onFocusChange: (focused) => _onItemFocusChange(index, focused),
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _CompletionDetailsDemo extends StatelessWidget {
  const _CompletionDetailsDemo({
    required this.items,
    required this.selection,
    required this.onResize,
  });

  final List<_DemoCompletionItem> items;
  final ValueNotifier<int> selection;
  final ValueChanged<Size> onResize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: selection,
      builder: (context, selected, _) {
        final doc = items[selected].documentation;
        return EditorResizablePanel(
          initialSize: const Size(320, 200),
          minSize: const Size(200, 120),
          maxSize: const Size(480, 360),
          onResize: onResize,
          child: Material(
            color: CompletionOverlayStyle.background(theme.colorScheme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: CompletionOverlayStyle.headerPadding,
                  child: EditorOverlayPanelDragHandle(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.drag_indicator,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Icon(items[selected].kind, size: 18),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[selected].label,
                                style: CompletionOverlayStyle.label(theme),
                              ),
                              if (items[selected].detail.isNotEmpty)
                                Text(
                                  items[selected].detail,
                                  style: CompletionOverlayStyle.detail(theme),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: CompletionOverlayStyle.bodyPadding,
                    child: SelectableText(
                      doc,
                      style: CompletionOverlayStyle.documentation(theme),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _HoverDemoPanel extends StatelessWidget {
  const _HoverDemoPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ColoredBox(
        color: theme.colorScheme.inverseSurface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onInverseSurface,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'void greet(String name, {int count = 1})',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
                SizedBox(height: 8),
                Text('Печатает приветствие. Параметр count по умолчанию 1.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _SignatureHelpDemo extends StatefulWidget {
  const _SignatureHelpDemo();

  @override
  State<_SignatureHelpDemo> createState() => _SignatureHelpDemoState();
}

final class _SignatureHelpDemoState extends State<_SignatureHelpDemo> {
  var _overload = 0;
  static const _activeParam = 1;

  static const _signatures = [
    'greet(String name, {int count = 1})',
    'greet(String name, [int count = 1])',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sig = _signatures[_overload];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    onPressed: _overload > 0
                        ? () => setState(() => _overload--)
                        : null,
                  ),
                  Text(
                    '${_overload + 1} / ${_signatures.length}',
                    style: theme.textTheme.labelSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    onPressed: _overload < _signatures.length - 1
                        ? () => setState(() => _overload++)
                        : null,
                  ),
                ],
              ),
              _SignatureLine(signature: sig, activeParameter: _activeParam),
              const SizedBox(height: 6),
              Text(
                'Стрелки ←→ — перегрузка, ↑↓ — активный параметр',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SignatureLine extends StatelessWidget {
  const _SignatureLine({
    required this.signature,
    required this.activeParameter,
  });

  final String signature;
  final int activeParameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <InlineSpan>[];
    var param = 0;
    for (final ch in signature.split('')) {
      if (ch == ',' || ch == '(') {
        if (ch == ',') param++;
      }
      final isActive = param == activeParameter && ch != '(' && ch != ')';
      spans.add(
        TextSpan(
          text: ch,
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: isActive ? FontWeight.bold : null,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
            backgroundColor: isActive
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : null,
          ),
        ),
      );
    }
    return Text.rich(TextSpan(children: spans));
  }
}

final class _FindBarDemo extends StatelessWidget {
  const _FindBarDemo({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Find…',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }
}
