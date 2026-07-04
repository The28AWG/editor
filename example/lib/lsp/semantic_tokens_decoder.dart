import 'dart:ui';

import 'package:editor/editor.dart';

/// Decodes LSP `semanticTokens/full` `data` into [StyleSpan]s.
final class SemanticTokensDecoder {
  SemanticTokensDecoder({
    required this.tokenTypes,
    required this.tokenModifiers,
    required this.colorsByType,
    this.priority = 50,
  });

  final List<String> tokenTypes;
  final List<String> tokenModifiers;
  final Map<String, Color> colorsByType;
  final int priority;

  SemanticTokensDecoder copyWith({
    List<String>? tokenTypes,
    List<String>? tokenModifiers,
    Map<String, Color>? colorsByType,
    int? priority,
  }) => SemanticTokensDecoder(
    tokenTypes: tokenTypes ?? this.tokenTypes,
    tokenModifiers: tokenModifiers ?? this.tokenModifiers,
    colorsByType: colorsByType ?? this.colorsByType,
    priority: priority ?? this.priority,
  );

  List<StyleSpan> decode(String text, List<int> data) {
    if (data.isEmpty) return const [];

    final lineStarts = _lineStartOffsets(text);
    final spans = <StyleSpan>[];

    var line = 0;
    var char = 0;

    for (var i = 0; i + 4 < data.length; i += 5) {
      final deltaLine = data[i];
      final deltaStart = data[i + 1];
      final length = data[i + 2];
      final typeIndex = data[i + 3];
      final modifierMask = data[i + 4];

      line += deltaLine;
      char = deltaLine == 0 ? char + deltaStart : deltaStart;

      if (line < 0 || line >= lineStarts.length || length <= 0) continue;
      if (typeIndex < 0 || typeIndex >= tokenTypes.length) continue;

      final start = lineStarts[line] + char;
      final end = start + length;
      if (start < 0 || end > text.length || start >= end) continue;

      final typeName = tokenTypes[typeIndex];
      final color = colorsByType[typeName];
      if (color == null) continue;

      final activeModifiers = _activeModifiers(modifierMask);
      final modifierStyle = _styleFromModifiers(color, activeModifiers);

      spans.add(
        StyleSpan(
          range: Range(start, end),
          color: modifierStyle.color ?? color,
          fontWeight: modifierStyle.fontWeight,
          fontStyle: modifierStyle.fontStyle,
          priority: priority,
        ),
      );
    }

    return spans;
  }

  List<String> _activeModifiers(int bitmask) {
    if (bitmask == 0 || tokenModifiers.isEmpty) return const [];

    final active = <String>[];
    for (var i = 0; i < tokenModifiers.length; i++) {
      if (bitmask & (1 << i) != 0) active.add(tokenModifiers[i]);
    }
    return active;
  }

  /// VS Code Dark+–like mapping for standard LSP semantic token modifiers.
  static _ModifierStyle _styleFromModifiers(
    Color base,
    List<String> modifiers,
  ) {
    if (modifiers.isEmpty) return const _ModifierStyle();

    Color? color;
    FontWeight? fontWeight;
    FontStyle? fontStyle;

    for (final name in modifiers) {
      switch (name) {
        case 'deprecated':
          color = Color.lerp(color ?? base, const Color(0xFF808080), 0.65);
        case 'modification':
          fontWeight = FontWeight.bold;
        case 'static':
        case 'abstract':
        case 'async':
        case 'defaultLibrary':
          fontStyle = FontStyle.italic;
        case 'readonly':
          color ??= Color.lerp(base, const Color(0xFF4FC9B0), 0.35);
      }
    }

    return _ModifierStyle(
      color: color != null && color != base ? color : null,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
    );
  }

  static List<int> _lineStartOffsets(String text) {
    final starts = <int>[0];
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) starts.add(i + 1);
    }
    return starts;
  }
}

final class _ModifierStyle {
  const _ModifierStyle({this.color, this.fontWeight, this.fontStyle});

  final Color? color;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
}
