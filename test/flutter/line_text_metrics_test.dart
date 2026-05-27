import 'package:editor/src/layout/line_text_metrics.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LineTextMetrics', () {
    test('block height uses max ascent and descent across runs', () {
      const base = TextStyle(fontFamily: 'monospace', fontSize: 14);
      const large = TextStyle(fontFamily: 'monospace', fontSize: 22);

      final small = layoutRunPainter(text: 'Mg', style: base);
      final big = layoutRunPainter(text: 'Mg', style: large);

      final metrics = LineTextMetrics.fromPainters([small, big]);
      final smallOnly = LineTextMetrics.fromPainters([small]);
      final bigOnly = LineTextMetrics.fromPainters([big]);

      expect(metrics.blockHeight, greaterThan(smallOnly.blockHeight));
      expect(metrics.maxAscent, bigOnly.maxAscent);
      expect(metrics.maxDescent, bigOnly.maxDescent);
    });

    test('contentTop centers block in line cell', () {
      final theme = EditorTheme.dark().copyWith(fontSize: 14, lineHeight: 2);
      final metrics = LineTextMetrics.fromTheme(theme);
      const lineTop = 10.0;
      final top = metrics.contentTop(
        lineTop,
        theme.lineHeightPx,
        EditorLineVerticalAlign.center,
      );
      expect(top, greaterThan(lineTop));
      expect(top + metrics.blockHeight, lessThan(lineTop + theme.lineHeightPx));
    });
  });
}
