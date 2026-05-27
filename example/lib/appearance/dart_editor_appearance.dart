import 'dart:ui';

import 'package:editor/editor.dart';
import 'package:example/appearance/editor_appearance_palette.dart' as palette;

/// Оформление Dart-редактора в example: [EditorTheme] + палитры токенов хоста.
///
/// Пакет `editor` не знает имён tree-sitter capture, LSP semantic types и языка.
/// Для другого языка заведите свой пресет с другими ключами в maps.
final class DartEditorAppearance {
  const DartEditorAppearance({
    required this.name,
    required this.chrome,
    required this.theme,
    required this.treeSitterCaptureColors,
    required this.lspSemanticColors,
  });

  /// Собирает appearance из палитр хрома и токенов.
  DartEditorAppearance._fromPalettes({
    required String name,
    required palette.EditorChromePalette chrome,
    required palette.EditorTokenPalette tokens,
  }) : this(
         name: name,
         chrome: chrome,
         theme: palette.editorThemeFromChrome(chrome),
         treeSitterCaptureColors: palette.treeSitterCaptureColors(tokens),
         lspSemanticColors: palette.lspSemanticColors(tokens),
       );

  /// Человекочитаемое имя цветовой схемы.
  final String name;

  /// Палитра хрома (фон, gutter) — источник для [EditorTheme] и Material [ThemeData].
  final palette.EditorChromePalette chrome;

  /// Тема поверхности редактора (фон, gutter, каретка, диагностики).
  final EditorTheme theme;

  /// Цвета capture из `native/queries/highlights.scm` для Dart tree-sitter.
  final Map<String, Color> treeSitterCaptureColors;

  /// Цвета LSP semantic token types (legend Dart analysis server).
  final Map<String, Color> lspSemanticColors;

  /// VS Code Dark+ (классическая тёмная тема Visual Studio Code).
  static final vscodeDark = DartEditorAppearance._fromPalettes(
    name: 'VS Code Dark+',
    chrome: const palette.EditorChromePalette(
      background: Color(0xFF1E1E1E),
      foreground: Color(0xFFD4D4D4),
      currentLine: Color(0xFF2A2A2A),
      gutterBackground: Color(0xFF252526),
      gutterText: Color(0xFF858585),
      selection: Color(0x4033B3FF),
      caret: Color(0xFFD4D4D4),
      bracketMatch: Color(0xFF3A3A3A),
      bracketMatchActive: Color(0xFF555555),
      link: Color(0xFF4EC9B0),
      preedit: Color(0x80FFFFFF),
      light: false,
    ),
    tokens: const palette.EditorTokenPalette(
      keyword: Color(0xFF569CD6),
      string: Color(0xFFCE9178),
      comment: Color(0xFF608B4E),
      type: Color(0xFF4EC9B0),
      function: Color(0xFFDCDCAA),
      variable: Color(0xFF9CDCFE),
      parameter: Color(0xFF9CDCFE),
      number: Color(0xFFB5CEA8),
      boolean: Color(0xFF569CD6),
      constant: Color(0xFFDCDCAA),
      operator: Color(0xFFD4D4D4),
      punctuation: Color(0xFFD4D4D4),
      attribute: Color(0xFF4EC9B0),
      label: Color(0xFFC8C8C8),
    ),
  );

  /// VS Code Light+.
  static final vscodeLight = DartEditorAppearance._fromPalettes(
    name: 'VS Code Light+',
    chrome: const palette.EditorChromePalette(
      background: Color(0xFFFFFFFF),
      foreground: Color(0xFF000000),
      currentLine: Color(0xFFF3F3F3),
      gutterBackground: Color(0xFFF3F3F3),
      gutterText: Color(0xFF237893),
      selection: Color(0x400099FF),
      caret: Color(0xFF000000),
      bracketMatch: Color(0xFFE0E0E0),
      bracketMatchActive: Color(0xFFC8C8C8),
      link: Color(0xFF098658),
      preedit: Color(0x80000000),
      light: true,
    ),
    tokens: const palette.EditorTokenPalette(
      keyword: Color(0xFF0000FF),
      string: Color(0xFFA31515),
      comment: Color(0xFF008000),
      type: Color(0xFF267F99),
      function: Color(0xFF795E26),
      variable: Color(0xFF001080),
      parameter: Color(0xFF001080),
      number: Color(0xFF098658),
      boolean: Color(0xFF0000FF),
      constant: Color(0xFF795E26),
      operator: Color(0xFF000000),
      punctuation: Color(0xFF000000),
      attribute: Color(0xFF267F99),
    ),
  );

  /// Dracula — популярная тёмная тема с розово-фиолетовыми акцентами.
  static final dracula = DartEditorAppearance._fromPalettes(
    name: 'Dracula',
    chrome: const palette.EditorChromePalette(
      background: Color(0xFF282A36),
      foreground: Color(0xFFF8F8F2),
      currentLine: Color(0xFF313340),
      gutterBackground: Color(0xFF282A36),
      gutterText: Color(0xFF6272A4),
      selection: Color(0x6644475A),
      caret: Color(0xFFF8F8F2),
      bracketMatch: Color(0xFF44475A),
      bracketMatchActive: Color(0xFF6272A4),
      link: Color(0xFF8BE9FD),
      preedit: Color(0x80FFFFFF),
      light: false,
    ),
    tokens: const palette.EditorTokenPalette(
      keyword: Color(0xFFFF79C6),
      string: Color(0xFFF1FA8C),
      comment: Color(0xFF6272A4),
      type: Color(0xFF8BE9FD),
      function: Color(0xFF50FA7B),
      variable: Color(0xFFF8F8F2),
      parameter: Color(0xFFFFB86C),
      number: Color(0xFFBD93F9),
      boolean: Color(0xFFBD93F9),
      constant: Color(0xFFBD93F9),
      operator: Color(0xFFFF79C6),
      punctuation: Color(0xFFF8F8F2),
      attribute: Color(0xFF8BE9FD),
    ),
  );

  /// Monokai — классика из Sublime Text (тёплый тёмный фон).
  static final monokai = DartEditorAppearance._fromPalettes(
    name: 'Monokai',
    chrome: const palette.EditorChromePalette(
      background: Color(0xFF272822),
      foreground: Color(0xFFF8F8F2),
      currentLine: Color(0xFF3E3D32),
      gutterBackground: Color(0xFF272822),
      gutterText: Color(0xFF75715E),
      selection: Color(0x6649453E),
      caret: Color(0xFFF8F8F2),
      bracketMatch: Color(0xFF49483E),
      bracketMatchActive: Color(0xFF75715E),
      link: Color(0xFF66D9EF),
      preedit: Color(0x80FFFFFF),
      light: false,
    ),
    tokens: const palette.EditorTokenPalette(
      keyword: Color(0xFFF92672),
      string: Color(0xFFE6DB74),
      comment: Color(0xFF75715E),
      type: Color(0xFF66D9EF),
      function: Color(0xFFA6E22E),
      variable: Color(0xFFF8F8F2),
      parameter: Color(0xFFFD971F),
      number: Color(0xFFAE81FF),
      boolean: Color(0xFFAE81FF),
      constant: Color(0xFFAE81FF),
      operator: Color(0xFFF92672),
      punctuation: Color(0xFFF8F8F2),
      attribute: Color(0xFF66D9EF),
    ),
  );

  /// One Dark — тема редактора Atom.
  static final oneDark = DartEditorAppearance._fromPalettes(
    name: 'One Dark',
    chrome: const palette.EditorChromePalette(
      background: Color(0xFF282C34),
      foreground: Color(0xFFABB2BF),
      currentLine: Color(0xFF2C313C),
      gutterBackground: Color(0xFF282C34),
      gutterText: Color(0xFF636D83),
      selection: Color(0x663E4451),
      caret: Color(0xFF528BFF),
      bracketMatch: Color(0xFF3E4451),
      bracketMatchActive: Color(0xFF636D83),
      link: Color(0xFF61AFEF),
      preedit: Color(0x80FFFFFF),
      light: false,
    ),
    tokens: const palette.EditorTokenPalette(
      keyword: Color(0xFFC678DD),
      string: Color(0xFF98C379),
      comment: Color(0xFF5C6370),
      type: Color(0xFFE5C07B),
      function: Color(0xFF61AFEF),
      variable: Color(0xFFE06C75),
      parameter: Color(0xFFD19A66),
      number: Color(0xFFD19A66),
      boolean: Color(0xFFD19A66),
      constant: Color(0xFFD19A66),
      operator: Color(0xFFABB2BF),
      punctuation: Color(0xFFABB2BF),
      attribute: Color(0xFFE5C07B),
    ),
  );

  /// Gruvbox Dark — приглушённая палитра с тёплыми оттенами.
  static final gruvboxDark = DartEditorAppearance._fromPalettes(
    name: 'Gruvbox Dark',
    chrome: const palette.EditorChromePalette(
      background: Color(0xFF282828),
      foreground: Color(0xFFEBDBB2),
      currentLine: Color(0xFF32302F),
      gutterBackground: Color(0xFF282828),
      gutterText: Color(0xFF928374),
      selection: Color(0x66504945),
      caret: Color(0xFFEBDBB2),
      bracketMatch: Color(0xFF3C3836),
      bracketMatchActive: Color(0xFF504945),
      link: Color(0xFF83A598),
      preedit: Color(0x80FFFFFF),
      light: false,
    ),
    tokens: const palette.EditorTokenPalette(
      keyword: Color(0xFFFB4934),
      string: Color(0xFFB8BB26),
      comment: Color(0xFF928374),
      type: Color(0xFFFABD2F),
      function: Color(0xFFB8BB26),
      variable: Color(0xFFEBDBB2),
      parameter: Color(0xFF83A598),
      number: Color(0xFFD3869B),
      boolean: Color(0xFFFE8019),
      constant: Color(0xFFD3869B),
      operator: Color(0xFFEBDBB2),
      punctuation: Color(0xFFEBDBB2),
      attribute: Color(0xFFFABD2F),
    ),
  );

  /// Solarized Dark — Ethan Schoonover, сбалансированная тёмная палитра.
  static final solarizedDark = DartEditorAppearance._fromPalettes(
    name: 'Solarized Dark',
    chrome: const palette.EditorChromePalette(
      background: Color(0xFF002B36),
      foreground: Color(0xFF839496),
      currentLine: Color(0xFF073642),
      gutterBackground: Color(0xFF002B36),
      gutterText: Color(0xFF586E75),
      selection: Color(0x66073642),
      caret: Color(0xFF839496),
      bracketMatch: Color(0xFF073642),
      bracketMatchActive: Color(0xFF586E75),
      link: Color(0xFF2AA198),
      preedit: Color(0x80FFFFFF),
      light: false,
    ),
    tokens: const palette.EditorTokenPalette(
      keyword: Color(0xFF859900),
      string: Color(0xFF2AA198),
      comment: Color(0xFF586E75),
      type: Color(0xFFB58900),
      function: Color(0xFF268BD2),
      variable: Color(0xFF839496),
      parameter: Color(0xFF839496),
      number: Color(0xFFD33682),
      boolean: Color(0xFF268BD2),
      constant: Color(0xFFCB4B16),
      operator: Color(0xFF839496),
      punctuation: Color(0xFF839496),
      attribute: Color(0xFFB58900),
    ),
  );

  /// Solarized Light.
  static final solarizedLight = DartEditorAppearance._fromPalettes(
    name: 'Solarized Light',
    chrome: const palette.EditorChromePalette(
      background: Color(0xFFFDF6E3),
      foreground: Color(0xFF657B83),
      currentLine: Color(0xFFEEE8D5),
      gutterBackground: Color(0xFFFDF6E3),
      gutterText: Color(0xFF93A1A1),
      selection: Color(0x66073642),
      caret: Color(0xFF657B83),
      bracketMatch: Color(0xFFEEE8D5),
      bracketMatchActive: Color(0xFF93A1A1),
      link: Color(0xFF2AA198),
      preedit: Color(0x80000000),
      light: true,
    ),
    tokens: const palette.EditorTokenPalette(
      keyword: Color(0xFF859900),
      string: Color(0xFF2AA198),
      comment: Color(0xFF93A1A1),
      type: Color(0xFFB58900),
      function: Color(0xFF268BD2),
      variable: Color(0xFF657B83),
      parameter: Color(0xFF657B83),
      number: Color(0xFFD33682),
      boolean: Color(0xFF268BD2),
      constant: Color(0xFFCB4B16),
      operator: Color(0xFF657B83),
      punctuation: Color(0xFF657B83),
      attribute: Color(0xFFB58900),
    ),
  );

  /// Nord — холодная сине-серая палитра.
  static final nord = DartEditorAppearance._fromPalettes(
    name: 'Nord',
    chrome: const palette.EditorChromePalette(
      background: Color(0xFF2E3440),
      foreground: Color(0xFFD8DEE9),
      currentLine: Color(0xFF3B4252),
      gutterBackground: Color(0xFF2E3440),
      gutterText: Color(0xFF616E88),
      selection: Color(0x6643475E),
      caret: Color(0xFFD8DEE9),
      bracketMatch: Color(0xFF434C5E),
      bracketMatchActive: Color(0xFF616E88),
      link: Color(0xFF88C0D0),
      preedit: Color(0x80FFFFFF),
      light: false,
    ),
    tokens: const palette.EditorTokenPalette(
      keyword: Color(0xFF81A1C1),
      string: Color(0xFFA3BE8C),
      comment: Color(0xFF616E88),
      type: Color(0xFF8FBCBB),
      function: Color(0xFF88C0D0),
      variable: Color(0xFFD8DEE9),
      parameter: Color(0xFFD8DEE9),
      number: Color(0xFFB48EAD),
      boolean: Color(0xFF81A1C1),
      constant: Color(0xFFEBCB8B),
      operator: Color(0xFF81A1C1),
      punctuation: Color(0xFFECEFF4),
      attribute: Color(0xFF8FBCBB),
    ),
  );

  /// Все встроенные схемы для выбора в UI.
  static final catalog = [
    vscodeDark,
    vscodeLight,
    dracula,
    monokai,
    oneDark,
    gruvboxDark,
    solarizedDark,
    solarizedLight,
    nord,
  ];
}
