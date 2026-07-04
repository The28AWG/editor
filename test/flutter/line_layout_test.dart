import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/layout/glyph_cache.dart';
import 'package:editor/src/layout/line_layout.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/layers/base_style_layer.dart';
import 'package:editor/src/styling/style_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LineLayout', () {
    test('hit-test offset in monospace line', () {
      final doc = Document.fromText('abcdef');
      final theme = const EditorTheme.dark().copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
      );
      final resolver = StyleResolver(
        theme: theme,
        layers: [BaseStyleLayer(theme)],
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

      final cw = cache.charWidth('a'.codeUnitAt(0));
      expect(layout.getOffsetAtPoint(0, cw * 2.25), 2);
      expect(layout.getOffsetAtPoint(0, cw * 2.75), 3);
    });

    test('collapsed range produces caret box', () {
      final doc = Document.fromText('ab');
      final theme = const EditorTheme.dark().copyWith(
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
      );

      final boxes = layout.getBoxesForRange(
        const Range(1, 1),
        theme.lineHeight,
      );
      expect(boxes, isNotEmpty);
      expect(boxes.first.left, boxes.first.right);
    });

    test('click past line text stays before newline', () {
      final doc = Document.fromText('ab\ncd\n');
      final theme = const EditorTheme.dark().copyWith(
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
      );

      final offset = layout.getOffsetAtPoint(0, 10000);
      expect(offset, doc.lineContentEnd(0));
      expect(doc.positionAt(offset).line, 0);
    });

    test('inlay hint shifts layout X after anchor', () {
      final doc = Document.fromText('foo(bar)');
      final theme = const EditorTheme.dark().copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
      );
      final resolver = StyleResolver(
        theme: theme,
        layers: [BaseStyleLayer(theme)],
      );
      final cache = GlyphCache(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
      );
      final hint = EditorInlayHint(
        anchorOffset: 4,
        label: 'name:',
        paddingLeft: 4,
      );
      final layout = LineLayout(
        document: doc,
        resolver: resolver,
        glyphCache: cache,
        theme: theme,
        inlays: [hint],
      );
      final visuals = layout.visualLinesForDocumentLine(0);
      final metrics = layout.inlayMetrics!;
      final xBefore = metrics.layoutX(0, visuals.first, 4);
      final xAfter = metrics.layoutX(0, visuals.first, 5);
      expect(xAfter - xBefore, greaterThan(cache.charWidth('('.codeUnitAt(0))));
    });
  });

  group('LineLayout block tops', () {
    LineLayout buildLayout(Document doc, EditorTheme theme) {
      final resolver = StyleResolver(
        theme: theme,
        layers: [BaseStyleLayer(theme)],
      );
      return LineLayout(
        document: doc,
        resolver: resolver,
        glyphCache: GlyphCache(
          fontFamily: theme.fontFamily,
          fontSize: theme.fontSize,
        ),
        theme: theme,
      );
    }

    test('totalHeight equals sum of block heights via prefix sums', () {
      final doc = Document.fromText('a\nb\nc\nd\ne');
      final theme = EditorTheme.dark().copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
      );
      final layout = buildLayout(doc, theme);
      final lineH = layout.lineHeightPx(theme.lineHeight);
      expect(layout.totalHeight(doc.lineCount, theme.lineHeight), lineH * 5);
    });

    test(
      'getBoxesForRange returns deep-line top in O(1) after totalHeight',
      () {
        // Если у строки 999 top = 999 * lineH, значит префикс-сумма работает.
        final lines = List<String>.generate(1000, (i) => 'x$i').join('\n');
        final doc = Document.fromText(lines);
        final theme = EditorTheme.dark().copyWith(
          fontFamily: 'monospace',
          fontSize: 14,
        );
        final layout = buildLayout(doc, theme);
        final lineH = layout.lineHeightPx(theme.lineHeight);
        layout.totalHeight(doc.lineCount, theme.lineHeight);
        final start = doc.lineStart(999);
        final boxes = layout.getBoxesForRange(
          Range(start, start),
          theme.lineHeight,
        );
        expect(boxes, isNotEmpty);
        expect(boxes.first.top, closeTo(lineH * 999, 0.001));
      },
    );

    test('lineIndexForDocumentY uses binary search on prefix sums', () {
      final lines = List<String>.generate(100, (i) => 'l$i').join('\n');
      final doc = Document.fromText(lines);
      final theme = EditorTheme.dark().copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
      );
      final layout = buildLayout(doc, theme);
      final lineH = layout.lineHeightPx(theme.lineHeight);
      expect(layout.lineIndexForDocumentY(0, theme.lineHeight), 0);
      expect(
        layout.lineIndexForDocumentY(lineH * 50 + 1, theme.lineHeight),
        50,
      );
      expect(
        layout.lineIndexForDocumentY(lineH * 99 + lineH - 1, theme.lineHeight),
        99,
      );
      expect(layout.lineIndexForDocumentY(lineH * 1000, theme.lineHeight), 99);
    });

    test('lineIndexAfterDocumentY is exclusive upper bound', () {
      final lines = List<String>.generate(10, (i) => 'l$i').join('\n');
      final doc = Document.fromText(lines);
      final theme = EditorTheme.dark().copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
      );
      final layout = buildLayout(doc, theme);
      final lineH = layout.lineHeightPx(theme.lineHeight);
      expect(layout.lineIndexAfterDocumentY(-1, theme.lineHeight), 0);
      expect(layout.lineIndexAfterDocumentY(0, theme.lineHeight), 1);
      expect(
        layout.lineIndexAfterDocumentY(lineH * 4 + 1, theme.lineHeight),
        5,
      );
      expect(layout.lineIndexAfterDocumentY(lineH * 100, theme.lineHeight), 10);
    });

    test('invalidateHeightCache(fromLine) re-uses prefix until fromLine', () {
      final lines = List<String>.generate(10, (i) => 'l$i').join('\n');
      final doc = Document.fromText(lines);
      final theme = EditorTheme.dark().copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
      );
      final layout = buildLayout(doc, theme);
      final lineH = layout.lineHeightPx(theme.lineHeight);
      layout
        ..totalHeight(doc.lineCount, theme.lineHeight)
        ..invalidateHeightCache(fromLine: 5);
      expect(
        layout.totalHeight(doc.lineCount, theme.lineHeight),
        closeTo(lineH * 10, 0.001),
      );
    });

    test('truncateToLineCount trims prefix sums', () {
      final lines = List<String>.generate(10, (i) => 'l$i').join('\n');
      final doc = Document.fromText(lines);
      final theme = EditorTheme.dark().copyWith(
        fontFamily: 'monospace',
        fontSize: 14,
      );
      final layout = buildLayout(doc, theme);
      final lineH = layout.lineHeightPx(theme.lineHeight);
      layout
        ..totalHeight(doc.lineCount, theme.lineHeight)
        ..truncateToLineCount(4);
      expect(
        layout.totalHeight(4, theme.lineHeight),
        closeTo(lineH * 4, 0.001),
      );
    });
  });

  group('LineLayout attributed cache', () {
    test('attributedRunsForLine returns identical list on hit', () {
      final doc = Document.fromText('hello\nworld');
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
      );
      final first = layout.attributedRunsForLine(0);
      final second = layout.attributedRunsForLine(0);
      expect(identical(first, second), isTrue);
    });

    test('invalidate(fromLine) drops attributed cache from that line', () {
      final doc = Document.fromText('a\nb\nc');
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
      );
      final line0 = layout.attributedRunsForLine(0);
      final line1 = layout.attributedRunsForLine(1);
      layout.invalidate(fromLine: 1);
      expect(identical(layout.attributedRunsForLine(0), line0), isTrue);
      expect(identical(layout.attributedRunsForLine(1), line1), isFalse);
    });

    test('invalidateMaxWidthCache skips when max line outside edit range', () {
      final doc = Document.fromText('hi\n${'w' * 60}');
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
      );
      final before = layout.maxLinePaintWidth();
      layout.invalidateMaxWidthCache(fromLine: 0, toLine: 0);
      final after = layout.maxLinePaintWidth();
      expect(after, before);
    });

    test('updateResolver drops the entire attributed cache', () {
      final doc = Document.fromText('foo');
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
      );
      final beforeRuns = layout.attributedRunsForLine(0);
      final beforeVisual = layout.visualLinesForDocumentLine(0).first;
      final next = StyleResolver(theme: theme, layers: [BaseStyleLayer(theme)]);
      layout.updateResolver(next);
      final afterRuns = layout.attributedRunsForLine(0);
      final afterVisual = layout.visualLinesForDocumentLine(0).first;
      expect(identical(beforeRuns, afterRuns), isFalse);
      expect(identical(beforeVisual, afterVisual), isFalse);
    });
  });
}
