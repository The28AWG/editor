import 'dart:async';

import 'package:editor/editor.dart';
import 'package:example/lsp/lsp_completion.dart';
import 'package:example/lsp/lsp_debug.dart';
import 'package:example/overlay/completion_overlay_layout.dart';
import 'package:example/overlay/editor_overlay_demos.dart';
import 'package:example/overlay/lsp_overlay_widgets.dart';
import 'package:flutter/material.dart';

/// Показывает LSP-driven overlay (completion, hover, signature) через [EditorOverlayCoordinator].
final class DartLspOverlayController {
  DartLspOverlayController({
    required this.controller,
    required this.languageService,
  }) {
    controller.addListener(_onControllerChanged);
  }

  final EditorController controller;
  final EditorOverlayLanguageService languageService;

  int _completionGen = 0;
  int _hoverGen = 0;
  int _signatureGen = 0;
  int? _lastTypedCompletionVersion;
  Timer? _typingCompletionTimer;

  final completionSelection = ValueNotifier(0);
  final completionItems = ValueNotifier<List<EditorCompletionItem>>([]);
  final signatureIndex = ValueNotifier(0);
  final signatureParam = ValueNotifier<int?>(null);

  Range? _completionReplaceRange;

  bool get hasLsp => true;

  Future<void> showCompletion({
    EditorCompletionTrigger trigger = EditorCompletionTrigger.invoked,
    String? triggerCharacter,
  }) async {
    final gen = ++_completionGen;
    final alreadyOpen = controller.overlays.sessions.any(
      (s) => s.id == 'lsp-completion',
    );
    final text = controller.document.text;
    final version = controller.document.version;
    final offset = controller.selection.primary.head;

    final list = await languageService.completions(
      text: text,
      documentVersion: version,
      offset: offset,
      trigger: trigger,
      triggerCharacter: triggerCharacter,
    );

    if (gen != _completionGen) return;
    if (list == null || list.items.isEmpty) {
      lspDiagLog('completion: empty at offset $offset');
      if (alreadyOpen) controller.overlays.hide('lsp-completion');
      return;
    }

    completionSelection.removeListener(_onCompletionSelectionChanged);

    _completionReplaceRange = list.replaceRange;
    completionItems.value = list.items;

    final selectedIndex = alreadyOpen
        ? completionSelection.value.clamp(0, list.items.length - 1)
        : 0;
    completionSelection.value = selectedIndex;
    unawaited(_resolveCompletionAt(selectedIndex, version, gen));

    controller.overlays.show(
      EditorOverlayDescriptor(
        id: 'lsp-completion',
        kind: EditorOverlayKind.completion,
        priority: 100,
        keyboardPolicy: EditorOverlayKeyboardPolicy.cooperative,
        onKeyEvent: _onCompletionKey,
        anchor: EditorCaretOverlayAnchor(replaceRange: list.replaceRange),
        layout: CompletionOverlayLayout.listPolicy,
        dismissPolicy: const EditorOverlayDismissPolicy(
          scroll: false,
          trackAnchorOnScroll: true,
          selectionChange: false,
        ),
        builder: (context, session) => ListenableBuilder(
          listenable: Listenable.merge([completionItems, completionSelection]),
          builder: (context, _) => LspOverlayWidgets.completionList(
            items: completionItems.value,
            selection: completionSelection,
            onAccept: (item) => _acceptCompletion(item),
          ),
        ),
        children: [
          EditorOverlayDescriptor(
            id: 'lsp-completion-details',
            kind: EditorOverlayKind.completion,
            priority: 101,
            anchor: const EditorViewportOverlayAnchor(),
            layout: const EditorOverlayLayoutPolicy(
              placement: EditorOverlayPlacement.besideEnd,
              childAlign: EditorOverlayChildAlign.start,
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
                completionItems,
                completionSelection,
              ]),
              builder: (context, _) => LspOverlayWidgets.completionDetails(
                items: completionItems.value,
                selection: completionSelection,
                onResize: session.resize,
              ),
            ),
          ),
        ],
      ),
    );

    completionSelection.addListener(_onCompletionSelectionChanged);
  }

  KeyEventResult _onCompletionKey(KeyEvent event) {
    final items = completionItems.value;
    return CompletionOverlayStyle.listNavigationKey(
      event,
      itemCount: items.length,
      selection: completionSelection,
      onAccept: items.isEmpty
          ? null
          : () => _acceptCompletion(items[completionSelection.value]),
    );
  }

  void _onControllerChanged() {
    if (!controller.overlays.sessions.any((s) => s.id == 'lsp-completion')) {
      return;
    }
    final version = controller.document.version;
    if (_lastTypedCompletionVersion == version) return;
    _lastTypedCompletionVersion = version;
    _typingCompletionTimer?.cancel();
    _typingCompletionTimer = Timer(const Duration(milliseconds: 200), () {
      unawaited(showCompletion(trigger: EditorCompletionTrigger.incomplete));
    });
  }

  void _onCompletionSelectionChanged() {
    if (!controller.overlays.sessions.any((s) => s.id == 'lsp-completion')) {
      completionSelection.removeListener(_onCompletionSelectionChanged);
      return;
    }
    final index = completionSelection.value;
    final version = controller.document.version;
    final gen = _completionGen;
    unawaited(_resolveCompletionAt(index, version, gen));
  }

  Future<void> _resolveCompletionAt(int index, int version, int gen) async {
    final items = completionItems.value;
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    if (!item.needsResolve) return;

    final resolved = await languageService.resolveCompletionItem(
      text: controller.document.text,
      documentVersion: version,
      item: item,
    );
    if (gen != _completionGen) return;
    if (resolved == null) return;

    final next = List<EditorCompletionItem>.of(items);
    next[index] = resolved;
    completionItems.value = next;
  }

  void _acceptCompletion(EditorCompletionItem item) {
    completionSelection.removeListener(_onCompletionSelectionChanged);
    final range = _completionReplaceRange;
    if (range != null) {
      controller.apply([completionApplyEdit(item: item, fallbackRange: range)]);
    }
    controller.overlays.hide('lsp-completion');
  }

  Future<void> showHover() async {
    final gen = ++_hoverGen;
    final text = controller.document.text;
    final version = controller.document.version;
    final offset = controller.selection.primary.head;
    final word = wordRangeAt(text, offset);
    if (word == null) return;

    final hover = await languageService.hover(
      text: text,
      documentVersion: version,
      offset: offset,
    );
    if (gen != _hoverGen) return;
    if (hover == null) {
      lspDiagLog('hover: null at $offset');
      return;
    }

    final anchorRange = hover.range ?? word;
    controller.overlays.show(
      EditorOverlayDescriptor(
        id: 'lsp-hover',
        kind: EditorOverlayKind.hover,
        priority: 50,
        anchor: EditorRangeOverlayAnchor(anchorRange),
        layout: const EditorOverlayLayoutPolicy(
          maxWidth: 480,
          preferredWidth: 400,
        ),
        dismissPolicy: const EditorOverlayDismissPolicy(
          selectionChange: true,
          trackAnchorOnScroll: true,
          scroll: false,
        ),
        builder: (context, session) => LspOverlayWidgets.hoverPanel(hover),
      ),
    );
  }

  Future<void> showSignatureHelp() async {
    final gen = ++_signatureGen;
    final text = controller.document.text;
    final version = controller.document.version;
    final offset = controller.selection.primary.head;

    final help = await languageService.signatureHelp(
      text: text,
      documentVersion: version,
      offset: offset,
    );
    if (gen != _signatureGen) return;
    if (help == null) {
      lspDiagLog('signatureHelp: null at $offset');
      return;
    }

    signatureIndex.value = help.activeSignature;
    signatureParam.value = help.activeParameter;

    controller.overlays.show(
      EditorOverlayDescriptor(
        id: 'lsp-signature',
        kind: EditorOverlayKind.signature,
        priority: 80,
        capturesKeyboard: true,
        anchor: const EditorCaretOverlayAnchor(),
        layout: const EditorOverlayLayoutPolicy(
          placement: EditorOverlayPlacement.above,
          maxWidth: 520,
        ),
        dismissPolicy: const EditorOverlayDismissPolicy(
          scroll: false,
          trackAnchorOnScroll: true,
        ),
        builder: (context, session) => LspOverlayWidgets.signatureHelpPanel(
          help: help,
          activeSignature: signatureIndex,
          activeParameter: signatureParam,
        ),
      ),
    );
  }

  void showFindBar() => EditorOverlayDemos.showFindBar(controller);

  void hideAll() {
    completionSelection.removeListener(_onCompletionSelectionChanged);
    controller.overlays.hideAll();
  }

  void dispose() {
    _typingCompletionTimer?.cancel();
    controller.removeListener(_onControllerChanged);
    completionSelection
      ..removeListener(_onCompletionSelectionChanged)
      ..dispose();
    completionItems.dispose();
    signatureIndex.dispose();
    signatureParam.dispose();
  }
}
