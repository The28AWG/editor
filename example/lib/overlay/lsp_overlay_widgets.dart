import 'package:editor/editor.dart';
import 'package:example/overlay/completion_overlay_layout.dart';
import 'package:flutter/material.dart';

/// Виджеты overlay, отображающие данные [EditorLanguageService].
abstract final class LspOverlayWidgets {
  LspOverlayWidgets._();

  static Widget completionList({
    required List<EditorCompletionItem> items,
    required ValueNotifier<int> selection,
    required ValueChanged<EditorCompletionItem> onAccept,
  }) => ValueListenableBuilder<int>(
    valueListenable: selection,
    builder: (context, selected, _) {
      final theme = Theme.of(context);
      final width = CompletionOverlayLayout.listWidthFromCompletionItems(
        context,
        items,
      );
      return SizedBox(
        width: width,
        child: Material(
          color: CompletionOverlayStyle.background(theme.colorScheme),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                dense: true,
                selected: index == selected,
                leading: Icon(_iconForLabel(item.label), size: 18),
                title: Text(
                  item.label,
                  style: CompletionOverlayStyle.label(theme),
                ),
                subtitle: item.detail == null
                    ? null
                    : Text(
                        item.detail!,
                        style: CompletionOverlayStyle.detail(theme),
                      ),
                onTap: () => onAccept(item),
                onFocusChange: (focused) {
                  if (focused) selection.value = index;
                },
              );
            },
          ),
        ),
      );
    },
  );

  static Widget completionDetails({
    required List<EditorCompletionItem> items,
    required ValueNotifier<int> selection,
    required ValueChanged<Size> onResize,
  }) => ValueListenableBuilder<int>(
    valueListenable: selection,
    builder: (context, selected, _) {
      final theme = Theme.of(context);
      final item = items[selected.clamp(0, items.length - 1)];
      final doc = item.documentation ?? item.detail ?? 'No documentation';
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
              _CompletionDetailsHeader(
                icon: _iconForLabel(item.label),
                label: item.label,
                detail: item.detail,
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

  static Widget hoverPanel(EditorHover hover) => Builder(
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ColoredBox(
          color: theme.colorScheme.inverseSurface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              hover.contents,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onInverseSurface,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ),
      );
    },
  );

  static Widget signatureHelpPanel({
    required EditorSignatureHelp help,
    required ValueNotifier<int> activeSignature,
    required ValueNotifier<int?> activeParameter,
  }) => ValueListenableBuilder<int>(
    valueListenable: activeSignature,
    builder: (context, sigIndex, _) => ValueListenableBuilder<int?>(
      valueListenable: activeParameter,
      builder: (context, paramIndex, _) {
        final theme = Theme.of(context);
        final sig =
            help.signatures[sigIndex.clamp(0, help.signatures.length - 1)];
        final activeParam = paramIndex ?? help.activeParameter ?? 0;
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
                  if (help.signatures.length > 1)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 18),
                          onPressed: sigIndex > 0
                              ? () => activeSignature.value = sigIndex - 1
                              : null,
                        ),
                        Text(
                          '${sigIndex + 1} / ${help.signatures.length}',
                          style: theme.textTheme.labelSmall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          onPressed: sigIndex < help.signatures.length - 1
                              ? () => activeSignature.value = sigIndex + 1
                              : null,
                        ),
                      ],
                    ),
                  _SignatureLabel(
                    label: sig.label,
                    activeParameter: activeParam,
                  ),
                  if (sig.documentation != null) ...[
                    const SizedBox(height: 6),
                    Text(sig.documentation!, style: theme.textTheme.labelSmall),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  static IconData _iconForLabel(String label) {
    if (label.startsWith('.')) return Icons.more_horiz;
    if (label.contains('(')) return Icons.functions;
    return Icons.code;
  }
}

/// Шапка documentation pane в том же виде, что строка [ListTile] в списке.
final class _CompletionDetailsHeader extends StatelessWidget {
  const _CompletionDetailsHeader({
    required this.icon,
    required this.label,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
            Icon(icon, size: 18),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: CompletionOverlayStyle.label(theme)),
                  if (detail != null && detail!.isNotEmpty)
                    Text(detail!, style: CompletionOverlayStyle.detail(theme)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SignatureLabel extends StatelessWidget {
  const _SignatureLabel({required this.label, required this.activeParameter});

  final String label;
  final int activeParameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <InlineSpan>[];
    var param = 0;
    var inParams = false;
    for (final ch in label.split('')) {
      if (ch == '(') {
        inParams = true;
        param = 0;
      } else if (ch == ',' && inParams) {
        param++;
      }
      final isActive =
          inParams && param == activeParameter && ch != '(' && ch != ')';
      spans.add(
        TextSpan(
          text: ch,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: theme.textTheme.bodySmall?.fontSize,
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
