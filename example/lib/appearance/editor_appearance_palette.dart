import 'package:editor/editor.dart';
import 'package:flutter/material.dart';

/// Семантические роли подсветки (общие для tree-sitter и LSP).
final class EditorTokenPalette {
  const EditorTokenPalette({
    required this.keyword,
    required this.string,
    required this.comment,
    required this.type,
    required this.function,
    required this.variable,
    required this.parameter,
    required this.number,
    required this.boolean,
    required this.constant,
    required this.operator,
    required this.punctuation,
    required this.attribute,
    Color? label,
  }) : label = label ?? variable;

  final Color keyword;
  final Color string;
  final Color comment;
  final Color type;
  final Color function;
  final Color variable;
  final Color parameter;
  final Color number;
  final Color boolean;
  final Color constant;
  final Color operator;
  final Color punctuation;
  final Color attribute;
  final Color label;
}

/// Цвета «хрома» редактора (фон, gutter, выделение).
final class EditorChromePalette {
  const EditorChromePalette({
    required this.background,
    required this.foreground,
    required this.currentLine,
    required this.gutterBackground,
    required this.gutterText,
    required this.selection,
    required this.caret,
    required this.bracketMatch,
    required this.bracketMatchActive,
    required this.link,
    required this.preedit,
    required this.light,
  });

  final Color background;
  final Color foreground;
  final Color currentLine;
  final Color gutterBackground;
  final Color gutterText;
  final Color selection;
  final Color caret;
  final Color bracketMatch;
  final Color bracketMatchActive;
  final Color link;
  final Color preedit;
  final bool light;
}

Map<String, Color> treeSitterCaptureColors(EditorTokenPalette palette) => {
  'attribute': palette.attribute,
  'boolean': palette.boolean,
  'comment': palette.comment,
  'constant': palette.constant,
  'constant.null': palette.boolean,
  'function': palette.function,
  'identifier.constant': palette.constant,
  'identifier.parameter': palette.parameter,
  'keyword': palette.keyword,
  'number': palette.number,
  'operator': palette.operator,
  'property': palette.variable,
  'punctuation.bracket': palette.punctuation,
  'punctuation.delimiter': palette.punctuation,
  'punctuation.special': palette.keyword,
  'string': palette.string,
  'string.escape': palette.string,
  'type': palette.type,
  'type.builtin': palette.type,
  'variable': palette.variable,
  'variable.builtin': palette.keyword,
};

Map<String, Color> lspSemanticColors(EditorTokenPalette palette) => {
  'annotation': palette.attribute,
  'boolean': palette.boolean,
  'class': palette.type,
  'comment': palette.comment,
  'enum': palette.type,
  'enumMember': palette.constant,
  'keyword': palette.keyword,
  'label': palette.label,
  'method': palette.function,
  'namespace': palette.type,
  'parameter': palette.parameter,
  'property': palette.variable,
  'source': palette.string,
  'string': palette.string,
  'type': palette.type,
  'typeParameter': palette.type,
  'variable': palette.variable,
  'function': palette.function,
  'number': palette.number,
};

EditorTheme editorThemeFromChrome(EditorChromePalette chrome) {
  if (chrome.light) {
    return EditorTheme(
      backgroundColor: chrome.background,
      currentLineColor: chrome.currentLine,
      defaultColor: chrome.foreground,
      fontFamily: 'monospace',
      fontSize: 16,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
      lineHeight: 1.2,
      lineVerticalAlign: EditorLineVerticalAlign.center,
      selectionColor: chrome.selection,
      caretColor: chrome.caret,
      occurrenceHighlightColor: Color.lerp(chrome.selection, chrome.link, 0.4)!,
      bracketMatchColor: chrome.bracketMatch,
      bracketMatchActiveColor: chrome.bracketMatchActive,
      linkedEditingHighlightColor: Color.lerp(
        chrome.link,
        chrome.background,
        0.75,
      )!,
      navigationLinkColor: chrome.link,
      preeditBackgroundColor: chrome.preedit,
      gutterBackgroundColor: chrome.gutterBackground,
      gutterTextColor: chrome.gutterText,
      diagnosticErrorColor: const Color(0xFFE51400),
      diagnosticWarningColor: const Color(0xFFBF8803),
      diagnosticInfoColor: const Color(0xFF1A85FF),
      diagnosticHintColor: const Color(0xFF6C6C6C),
      diagnosticErrorInlineColor: const Color(0x99E51400),
      diagnosticWarningInlineColor: const Color(0x99BF8803),
      diagnosticInfoInlineColor: const Color(0x991A85FF),
      diagnosticHintInlineColor: const Color(0x996C6C6C),
      diagnosticErrorLineColor: const Color(0x22E51400),
      inlayHintTypeColor: const Color(0x99757575),
      inlayHintParameterColor: const Color(0x99757575),
      inlayHintOtherColor: const Color(0x99757575),
    );
  }

  return EditorTheme(
    backgroundColor: chrome.background,
    currentLineColor: chrome.currentLine,
    defaultColor: chrome.foreground,
    fontFamily: 'monospace',
    fontSize: 16,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.normal,
    lineHeight: 1.2,
    lineVerticalAlign: EditorLineVerticalAlign.center,
    selectionColor: chrome.selection,
    caretColor: chrome.caret,
    occurrenceHighlightColor: Color.lerp(chrome.selection, chrome.link, 0.35)!,
    bracketMatchColor: chrome.bracketMatch,
    bracketMatchActiveColor: chrome.bracketMatchActive,
    linkedEditingHighlightColor: Color.lerp(
      chrome.link,
      chrome.background,
      0.65,
    )!,
    navigationLinkColor: chrome.link,
    preeditBackgroundColor: chrome.preedit,
    gutterBackgroundColor: chrome.gutterBackground,
    gutterTextColor: chrome.gutterText,
    diagnosticErrorColor: const Color(0xFFF48771),
    diagnosticWarningColor: const Color(0xFFCCA700),
    diagnosticInfoColor: const Color(0xFF75BEFF),
    diagnosticHintColor: const Color(0xFF858585),
    diagnosticErrorInlineColor: const Color(0x99F48771),
    diagnosticWarningInlineColor: const Color(0x99CCA700),
    diagnosticInfoInlineColor: const Color(0x9975BEFF),
    diagnosticHintInlineColor: const Color(0x99858585),
    diagnosticErrorLineColor: const Color(0x22F48771),
    inlayHintTypeColor: const Color(0x99808080),
    inlayHintParameterColor: const Color(0x99808080),
    inlayHintOtherColor: const Color(0x99808080),
  );
}

/// Material [ThemeData], согласованный с [EditorChromePalette] редактора.
///
/// Полное совпадение с IDE невозможно (у Material свои роли), но фон, AppBar,
/// акценты и текст выводятся из той же палитры, что и [editorThemeFromChrome].
ThemeData materialThemeFromChrome(EditorChromePalette chrome) {
  final brightness = chrome.light ? Brightness.light : Brightness.dark;
  final onPrimary = chrome.light ? const Color(0xFFFFFFFF) : chrome.background;
  final error = chrome.light
      ? const Color(0xFFE51400)
      : const Color(0xFFF48771);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: chrome.link,
    onPrimary: onPrimary,
    secondary: chrome.gutterText,
    onSecondary: chrome.foreground,
    surface: chrome.background,
    onSurface: chrome.foreground,
    onSurfaceVariant: chrome.gutterText,
    surfaceContainerHighest: chrome.currentLine,
    outline: chrome.bracketMatchActive,
    outlineVariant: chrome.bracketMatch,
    error: error,
    onError: const Color(0xFFFFFFFF),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: chrome.background,
    canvasColor: chrome.background,
    dividerColor: chrome.bracketMatch,
    iconTheme: IconThemeData(color: chrome.foreground),
    appBarTheme: AppBarTheme(
      backgroundColor: chrome.gutterBackground,
      foregroundColor: chrome.foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: chrome.gutterBackground,
      textStyle: TextStyle(color: chrome.foreground),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: chrome.gutterBackground,
      contentTextStyle: TextStyle(color: chrome.foreground),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: chrome.link),
    textTheme:
        (chrome.light
                ? Typography.material2021(platform: TargetPlatform.linux).black
                : Typography.material2021(platform: TargetPlatform.linux).white)
            .apply(
              bodyColor: chrome.foreground,
              displayColor: chrome.foreground,
            ),
  );
}
