import 'package:editor/src/layout/glyph_cache.dart';
import 'package:editor/src/layout/line_layout.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/layers/base_style_layer.dart';
import 'package:editor/src/styling/style_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lineIndexForDocumentY accounts for wrapped visual lines', () {
    final text = 'word ' * 30;
    final doc = Document.fromText('$text\nshort\n');
    final theme = EditorTheme.dark().copyWith(
      fontFamily: 'monospace',
      fontSize: 14,
    );
    final resolver = StyleResolver(
      theme: theme,
      layers: [BaseStyleLayer(theme)],
    );
    final layout = LineLayout(
      document: doc,
      resolver: resolver,
      glyphCache: GlyphCache(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
      ),
      theme: theme,
      wrapWidth: 120,
    );

    final lineH = layout.lineHeightPx(theme.lineHeight);
    final visuals0 = layout.visualLinesForDocumentLine(0);
    expect(visuals0.length, greaterThan(1));

    final block0 = lineH * visuals0.length;
    expect(layout.lineIndexForDocumentY(0, theme.lineHeight), 0);
    expect(layout.lineIndexForDocumentY(block0 - 1, theme.lineHeight), 0);
    expect(layout.lineIndexForDocumentY(block0, theme.lineHeight), 1);
    expect(
      layout.lineIndexForDocumentY(block0 + lineH * 0.5, theme.lineHeight),
      1,
    );
  });
}
