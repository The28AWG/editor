import 'package:editor/editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Расчёт ширины списка completion для overlay example.
abstract final class CompletionOverlayLayout {
  CompletionOverlayLayout._();

  static const minListWidth = 160.0;
  static const maxListWidth = 420.0;
  static const maxListHeight = 280.0;

  /// Политика layout для списка completion (без фиксированной preferredWidth).
  static const listPolicy = EditorOverlayLayoutPolicy(
    minWidth: minListWidth,
    maxWidth: maxListWidth,
    maxHeight: maxListHeight,
  );

  /// Ширина [ListTile]: padding + leading + gap + самая длинная строка.
  static double listWidth(
    BuildContext context, {
    required List<String> labels,
    List<String?>? details,
  }) {
    final theme = Theme.of(context);
    final titleStyle = CompletionOverlayStyle.label(theme);
    final subtitleStyle = CompletionOverlayStyle.detail(theme);
    const chrome = 88.0;

    var textWidth = 0.0;
    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      var line = _textWidth(label, titleStyle);
      if (details != null && i < details.length) {
        final detail = details[i];
        if (detail != null && detail.isNotEmpty) {
          final detailW = _textWidth(detail, subtitleStyle);
          if (detailW > line) line = detailW;
        }
      }
      if (line > textWidth) textWidth = line;
    }

    return (textWidth + chrome).clamp(minListWidth, maxListWidth);
  }

  static double listWidthFromCompletionItems(
    BuildContext context,
    List<EditorCompletionItem> items,
  ) {
    final labels = <String>[];
    final details = <String?>[];
    for (final item in items) {
      labels.add(item.label);
      details.add(item.detail);
    }
    return listWidth(context, labels: labels, details: details);
  }

  static double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }
}

/// Общий визуальный стиль списка completion и панели documentation.
abstract final class CompletionOverlayStyle {
  CompletionOverlayStyle._();

  static Color background(ColorScheme scheme) => scheme.surfaceContainerHighest;

  static TextStyle label(ThemeData theme) =>
      theme.textTheme.bodyMedium ?? const TextStyle();

  static TextStyle detail(ThemeData theme) =>
      (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
        fontFamily: 'monospace',
      );

  static TextStyle documentation(ThemeData theme) =>
      detail(theme).copyWith(height: 1.4);

  static const headerPadding = EdgeInsets.fromLTRB(12, 8, 12, 4);
  static const bodyPadding = EdgeInsets.all(12);

  /// Стрелки, Enter и Tab для cooperative completion; остальное — [KeyEventResult.ignored].
  static KeyEventResult listNavigationKey(
    KeyEvent event, {
    required int itemCount,
    required ValueNotifier<int> selection,
    VoidCallback? onAccept,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (itemCount == 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      if (onAccept == null) return KeyEventResult.ignored;
      onAccept();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      final next = (selection.value - 1).clamp(0, itemCount - 1);
      if (next != selection.value) selection.value = next;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = (selection.value + 1).clamp(0, itemCount - 1);
      if (next != selection.value) selection.value = next;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
