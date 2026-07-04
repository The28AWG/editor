import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/inlay/inlay_layout_metrics.dart';
import 'package:editor/src/layout/glyph_cache.dart';
import 'package:editor/src/layout/line_layout.dart';
import 'package:editor/src/layout/styled_run_layout.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/layers/base_style_layer.dart';
import 'package:editor/src/styling/style_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'offsetAtLayoutX after inlay maps click on following word correctly',
    () {
      const line = '  greet(name, count: count);';
      final doc = Document.fromText('void f() {\n$line\n}');
      const lineIndex = 1;
      final lineStart = doc.lineStart(lineIndex);
      final nameStart = lineStart + line.indexOf('name');
      final countStart = lineStart + line.indexOf('count');

      final theme = EditorTheme.dark().copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
      );
      final resolver = StyleResolver(
        theme: theme,
        layers: [BaseStyleLayer(theme)],
      );
      final glyphCache = GlyphCache(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
      );
      final styled = StyledRunLayout(
        document: doc,
        runsForLine: (lineIndex) => resolver.resolveLineRuns(doc, lineIndex),
      );
      final inlays = [
        EditorInlayHint(
          anchorOffset: nameStart,
          label: 'name:',
          kind: EditorInlayHintKind.parameter,
        ),
      ];
      final metrics = InlayLayoutMetrics(
        glyphCache: glyphCache,
        theme: theme,
        inlays: inlays,
        styledLayout: styled,
      );

      final layout = LineLayout(
        document: doc,
        resolver: resolver,
        glyphCache: glyphCache,
        theme: theme,
        inlays: inlays,
      );
      final visual = layout.visualLinesForDocumentLine(lineIndex).single;

      final nameLayoutX = metrics.layoutX(lineIndex, visual, nameStart);
      final countLayoutX = metrics.layoutX(lineIndex, visual, countStart);
      expect(countLayoutX, greaterThan(nameLayoutX));

      final clickOnName = nameLayoutX + 2;
      final offset = metrics.offsetAtLayoutX(lineIndex, visual, clickOnName);

      expect(offset, greaterThanOrEqualTo(nameStart));
      expect(offset, lessThan(countStart));
    },
  );
}
