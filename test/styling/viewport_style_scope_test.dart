import 'package:editor/src/layout/viewport.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ViewportStyleScope.fromViewport', () {
    late Document doc;
    const viewportH = 400.0;
    const lineHeightPx = 20.0;

    setUp(() {
      final lines = List<String>.generate(200, (i) => 'line $i\n');
      doc = Document.fromText(lines.join());
    });

    test('caret outside scroll keeps scroll window and caretSearchRange', () {
      final vp = ViewportState(
        firstVisibleLine: 0,
        viewportHeight: viewportH,
        overscanLines: 3,
      );
      final scope = ViewportStyleScope.fromViewport(
        document: doc,
        viewport: vp,
        lineHeightPx: lineHeightPx,
        caretLine: 150,
      );
      expect(scope.firstLine, 0);
      expect(scope.lastLineExclusive, lessThan(30));
      expect(scope.caretSearchRange, isNotNull);
      final caretStart = doc.lineStart(150);
      expect(scope.caretSearchRange!.start, lessThanOrEqualTo(caretStart));
      expect(scope.caretSearchRange!.end, greaterThan(caretStart));
      expect(scope.documentRange.start, 0);
    });

    test('caret inside scroll uses scroll window', () {
      final vp = ViewportState(
        firstVisibleLine: 140,
        viewportHeight: viewportH,
        overscanLines: 3,
      );
      final scope = ViewportStyleScope.fromViewport(
        document: doc,
        viewport: vp,
        lineHeightPx: lineHeightPx,
        caretLine: 150,
      );
      expect(scope.firstLine, 137);
      expect(scope.lastLineExclusive, greaterThan(150));
      expect(scope.caretSearchRange, isNull);
      expect(scope.lastLineExclusive, lessThanOrEqualTo(doc.lineCount));
      expect(
        scope.lastLineExclusive - scope.firstLine,
        lessThanOrEqualTo(kMaxStyleViewportLines),
      );
    });

    test(
      'lineHeightPx not factor: scroll at top stays at top with caret at EOF',
      () {
        final lines = List<String>.generate(1600, (i) => 'x' * 40 + '\n');
        final big = Document.fromText(lines.join());
        final vp = ViewportState(
          firstVisibleLine: 0,
          viewportHeight: 600,
          overscanLines: 3,
        );
        final scope = ViewportStyleScope.fromViewport(
          document: big,
          viewport: vp,
          lineHeightPx: 19.2,
          caretLine: 1599,
        );
        expect(scope.documentRange.start, 0);
        expect(scope.lastLineExclusive, lessThan(80));
        expect(scope.caretSearchRange, isNotNull);
      },
    );
  });
}
