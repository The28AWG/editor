import 'dart:ui';

import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/layers/pending_shifted_syntax_layer.dart';
import 'package:editor/src/styling/style_span.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StyleSpan span(int start, int end, [Color color = const Color(0xFFFF0000)]) =>
      StyleSpan(range: Range(start, end), color: color, priority: 0);

  DocumentChange change(
    int start, {
    int removed = 0,
    String inserted = '',
    int firstLine = 0,
    int lastLine = 0,
  }) => DocumentChange(
    range: Range(start, start + removed),
    oldVersion: 0,
    newVersion: 1,
    affectedLineRange: const Range(0, 0),
    affectedFirstLine: firstLine,
    affectedLastLine: lastLine,
    insertedText: inserted,
    removedLength: removed,
  );

  group('PendingShiftedSyntaxLayer', () {
    test('empty pending behaves like a plain syntax layer', () {
      final layer = PendingShiftedSyntaxLayer(
        sortedBase: [span(0, 5), span(10, 20)],
        pending: const [],
        documentVersion: 1,
      );
      final out = layer.spansForRange(const Range(0, 100)).toList();
      expect(out.length, 2);
      expect(out.first.range, const Range(0, 5));
      expect(out[1].range, const Range(10, 20));
      expect(out.first.priority, 50);
    });

    test('shifts spans after a single insert', () {
      // insert "xxx" at 10 → spans at [10,20) shift to [13,23).
      final layer = PendingShiftedSyntaxLayer(
        sortedBase: [span(0, 5), span(10, 20)],
        pending: [change(10, inserted: 'xxx')],
        documentVersion: 1,
      );
      final out = layer.spansForRange(const Range(0, 100)).toList();
      expect(out.length, 2);
      expect(out.first.range, const Range(0, 5));
      expect(out[1].range, const Range(13, 23));
    });

    test('clip drops spans at and after clipBefore', () {
      final layer = PendingShiftedSyntaxLayer(
        sortedBase: [span(0, 5), span(20, 30)],
        pending: const [],
        documentVersion: 1,
        clipBefore: 10,
      );
      final out = layer.spansForRange(const Range(0, 100)).toList();
      expect(out.length, 1);
      expect(out.single.range, const Range(0, 5));
    });

    test('clip truncates span crossing the threshold', () {
      final layer = PendingShiftedSyntaxLayer(
        sortedBase: [span(5, 15)],
        pending: const [],
        documentVersion: 1,
        clipBefore: 10,
      );
      final out = layer.spansForRange(const Range(0, 100)).toList();
      expect(out.single.range, const Range(5, 10));
    });

    test('binary search picks only spans intersecting requested range', () {
      // Construct 1000 spans of width 5 with 10-char cadence; query a window
      // of width 5 that hits a single span at i=500 → [5000, 5005).
      final base = List<StyleSpan>.generate(
        1000,
        (i) => span(i * 10, i * 10 + 5),
      );
      final layer = PendingShiftedSyntaxLayer(
        sortedBase: base,
        pending: const [],
        documentVersion: 1,
      );
      final out = layer.spansForRange(const Range(4998, 5008)).toList();
      expect(out.length, 1);
      expect(out.single.range, const Range(5000, 5005));
    });

    test('shifted spans intersect requested range correctly', () {
      // Base: span at [100, 110). Pending: insert 5 at 50 → shifted span [105, 115).
      // Query [110, 200) → expect a single span [110, 115).
      final layer = PendingShiftedSyntaxLayer(
        sortedBase: [span(100, 110)],
        pending: [change(50, inserted: 'abcde')],
        documentVersion: 1,
      );
      final out = layer.spansForRange(const Range(110, 200)).toList();
      expect(out.single.range, const Range(110, 115));
    });

    test('inserted region returns no spans (gap in snapshot)', () {
      // Base: spans at [0,5) and [10,15). Pending: insert "ZZZZZ" at 5 →
      // shifted [10,15). Query [5,10) (inserted region) → no spans
      // (in snapshot coords, the inverse range is [5,5) = empty).
      final layer = PendingShiftedSyntaxLayer(
        sortedBase: [span(0, 5), span(10, 15)],
        pending: [change(5, inserted: 'ZZZZZ')],
        documentVersion: 1,
      );
      final out = layer.spansForRange(const Range(5, 10)).toList();
      expect(out, isEmpty);
    });

    test('multiple pending edits compose correctly', () {
      // Base: span [200, 220).
      // pending: insert 3 at 50; insert 7 at 100 (in post-1 coords).
      // Original 200 → post-1: 200+3 = 203 → post-2 (edit at 100): 203+7 = 210.
      // Original 220 → 230.
      // Query [0, 1000) → span at [210, 230).
      final layer = PendingShiftedSyntaxLayer(
        sortedBase: [span(200, 220)],
        pending: [
          change(50, inserted: 'abc'),
          change(100, inserted: 'XXXXXXX'),
        ],
        documentVersion: 1,
      );
      final out = layer.spansForRange(const Range(0, 1000)).toList();
      expect(out.single.range, const Range(210, 230));
    });

    test('viewport hint limits span scan window', () {
      final base = List<StyleSpan>.generate(
        1000,
        (i) => span(i * 20, i * 20 + 5),
      );
      final layer =
          PendingShiftedSyntaxLayer(
            sortedBase: base,
            pending: const [],
            documentVersion: 1,
          )..syncFrom(
            sortedBase: base,
            pending: const [],
            documentVersion: 1,
            clipBefore: null,
            viewport: const ViewportStyleScope(
              firstLine: 0,
              lastLineExclusive: 5,
              documentRange: Range(400, 500),
            ),
          );
      final bounds = layer.spanSearchBounds!;
      expect(bounds.hi - bounds.lo, lessThan(80));
      expect(0, lessThan(bounds.lo));
    });

    test('no allocations of full span list (smoke: large file, small query)', () {
      // 3000 base spans (covers ~60KB-equivalent file); pending of 7 inserts at
      // offset 3000; query a single 80-char line near the caret. Verify the layer
      // returns only the locally affected spans rather than projecting all 3000.
      final base = List<StyleSpan>.generate(
        3000,
        (i) => span(i * 20, i * 20 + 8),
      );
      final pending = [
        for (var i = 0; i < 7; i++) change(i + 3000, inserted: 'a'),
      ];
      final layer = PendingShiftedSyntaxLayer(
        sortedBase: base,
        pending: pending,
        documentVersion: 1,
      );
      final out = layer.spansForRange(const Range(3000, 3080)).toList();
      // ~4 spans (80 chars / 20-char cadence). Acceptably small relative to 3000.
      expect(out.length, lessThan(8));
      for (final s in out) {
        expect(s.range.start, greaterThanOrEqualTo(3000));
        expect(s.range.end, lessThanOrEqualTo(3080));
      }
    });
  });
}
