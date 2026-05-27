import 'package:editor/src/layout/glyph_cache.dart';
import 'package:editor/src/layout/line_layout.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/layers/base_style_layer.dart';
import 'package:editor/src/styling/style_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selection box top matches line block top in document space', () {
    final doc = Document.fromText('aaa\nbbb\nccc\n');
    final theme = EditorTheme.dark().copyWith(fontFamily: 'monospace', fontSize: 14);
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
    );

    final lineH = layout.lineHeightPx(theme.lineHeight);
    final line2Top =
        lineH * layout.visualLinesForDocumentLine(0).length +
        lineH * layout.visualLinesForDocumentLine(1).length;

    final boxes = layout.getBoxesForRange(
      Range(doc.lineStart(2), doc.lineStart(2) + 1),
      theme.lineHeight,
    );
    expect(boxes.first.top, line2Top);
  });
}
