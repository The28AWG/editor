import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/layers/syntax_style_layer.dart';
import 'package:editor/src/styling/sorted_style_spans.dart';
import 'package:editor/src/styling/style_span.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('spanSearchBoundsForRange', () {
    test('empty overlap uses adjacent span index', () {
      final spans = [
        StyleSpan(range: const Range(0, 100), color: Colors.red),
        StyleSpan(range: const Range(200, 300), color: Colors.blue),
      ];
      final b = spanSearchBoundsForRange(spans, const Range(500, 600));
      expect(b.lo, 1);
      expect(b.hi, 2);
    });

    test('merge keeps scroll when caret slice empty', () {
      final spans = List<StyleSpan>.generate(
        10,
        (i) =>
            StyleSpan(range: Range(i * 100, i * 100 + 50), color: Colors.red),
      );
      final scroll = spanSearchBoundsForRange(spans, const Range(0, 80));
      final tail = spanSearchBoundsForRange(spans, const Range(950, 1000));
      final merged = mergeSpanSearchBounds(scroll, tail);
      expect(merged.lo, 0);
      expect(merged.hi, greaterThan(0));
    });
  });

  group('SyntaxStyleLayer.setSpanSearchBoundsFromViewport', () {
    test('tail viewport with no tokens uses tight bounds', () {
      final spans = List<StyleSpan>.generate(
        100,
        (i) => StyleSpan(range: Range(i * 10, i * 10 + 5), color: Colors.red),
      );
      final layer = SyntaxStyleLayer(spans: spans, alreadySorted: true)
        ..setSpanSearchBoundsFromViewport(
          const ViewportStyleScope(
            firstLine: 0,
            lastLineExclusive: 1,
            documentRange: Range(995, 1000),
          ),
        );
      final b = layer.spanSearchBounds!;
      expect(b.lo, 99);
      expect(b.hi, 100);
    });

    test('viewport with off-screen caret merges scroll and caret bounds', () {
      final spans = List<StyleSpan>.generate(
        200,
        (i) => StyleSpan(range: Range(i * 10, i * 10 + 8), color: Colors.red),
      );
      final layer = SyntaxStyleLayer(spans: spans, alreadySorted: true)
        ..setSpanSearchBoundsFromViewport(
          const ViewportStyleScope(
            firstLine: 0,
            lastLineExclusive: 5,
            documentRange: Range(0, 50),
            caretSearchRange: Range(1500, 1600),
          ),
        );
      final b = layer.spanSearchBounds!;
      expect(b.lo, 0);
      expect(b.hi, greaterThan(150));
      expect(b.hi, lessThan(200));
    });
  });
}
