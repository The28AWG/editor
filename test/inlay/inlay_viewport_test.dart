import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/inlay/inlay_viewport.dart';
import 'package:editor/src/layout/viewport.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inlay viewport', () {
    late Document doc;

    setUp(() {
      final lines = List<String>.generate(200, (i) => 'line $i\n');
      doc = Document.fromText(lines.join());
    });

    ViewportStyleScope scopeAtScrollTop() {
      final vp = ViewportState(
        firstVisibleLine: 0,
        viewportHeight: 400,
        overscanLines: 3,
      );
      return ViewportStyleScope.fromViewport(
        document: doc,
        viewport: vp,
        lineHeightPx: 20,
      );
    }

    test('inlayHintsInViewport keeps only scroll window anchors', () {
      final scope = scopeAtScrollTop();
      final hints = [
        const EditorInlayHint(anchorOffset: 0, label: 'a'),
        EditorInlayHint(anchorOffset: doc.lineStart(50), label: 'far'),
      ];
      final visible = inlayHintsInViewport(hints, scope);
      expect(visible, hasLength(1));
      expect(visible.first.label, 'a');
    });

    test('inlayHintFetchRange merges caret strip when caret off screen', () {
      final vp = ViewportState(
        firstVisibleLine: 0,
        viewportHeight: 400,
        overscanLines: 3,
      );
      final scope = ViewportStyleScope.fromViewport(
        document: doc,
        viewport: vp,
        lineHeightPx: 20,
        caretLine: 150,
      );
      expect(scope.caretSearchRange, isNotNull);
      final fetch = inlayHintFetchRange(scope);
      final caretStart = doc.lineStart(150);
      expect(fetch.start, lessThanOrEqualTo(caretStart));
      expect(fetch.end, greaterThan(caretStart));
      expect(fetch.start, lessThanOrEqualTo(scope.documentRange.start));
    });

    test('filterInlayHintsForRange drops out-of-range anchors', () {
      const range = Range(10, 100);
      final hints = [
        const EditorInlayHint(anchorOffset: 5, label: 'before'),
        const EditorInlayHint(anchorOffset: 50, label: 'inside'),
        const EditorInlayHint(anchorOffset: 100, label: 'atEnd'),
      ];
      final filtered = filterInlayHintsForRange(hints, range);
      expect(filtered.map((h) => h.label), ['inside']);
    });
  });
}
