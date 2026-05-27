import 'dart:ui';

import 'package:editor/src/layout/glyph_cache.dart';
import 'package:editor/src/layout/line_layout.dart';
import 'package:editor/src/layout/line_text_metrics.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/layers/base_style_layer.dart';
import 'package:editor/src/styling/layers/syntax_style_layer.dart';
import 'package:editor/src/styling/style_resolver.dart';
import 'package:editor/src/styling/style_span.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hit-test on "name" matches click X with bold prefix drift', () {
    // "XXname" — первые два символа bold шире, чем в GlyphCache (regular).
    final doc = Document.fromText('XXname');
    final theme = EditorTheme.dark().copyWith(fontFamily: 'monospace', fontSize: 14);
    final resolver = StyleResolver(
      theme: theme,
      layers: [
        BaseStyleLayer(theme),
        SyntaxStyleLayer(
          spans: [
            StyleSpan(
              range: const Range(0, 2),
              fontWeight: FontWeight.bold,
              priority: 50,
            ),
          ],
        ),
      ],
    );
    final cache = GlyphCache(
      fontFamily: theme.fontFamily,
      fontSize: theme.fontSize,
    );
    final layout = LineLayout(
      document: doc,
      resolver: resolver,
      glyphCache: cache,
      theme: theme,
    );

    final styled = layoutRunPainter(
      text: 'XX',
      style: textStyleForResolvedStyle(
        resolver.resolveLineRuns(doc, 0).first.style,
      ),
    );
    final regular = layoutRunPainter(
      text: 'n',
      style: textStyleForResolvedStyle(
        resolver.resolveLineRuns(doc, 0)[1].style,
      ),
    );
    final xOnN = styled.width + regular.width * 0.25;

    final offset = layout.getOffsetAtPoint(0, xOnN);
    expect(offset, 2);

    final boxes = layout.getBoxesForRange(const Range(2, 3), theme.lineHeight);
    expect(boxes.first.left, styled.width);
  });
}
