import 'dart:ui';

import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/style_span.dart';
import 'package:editor/src/styling/style_span_mask.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('revertPendingChangesForUndo', () {
    test('pops insert entries matching undo length', () {
      final pending = <DocumentChange>[
        const DocumentChange(
          range: Range(5, 5),
          oldVersion: 0,
          newVersion: 1,
          affectedLineRange: Range(0, 0),
          affectedFirstLine: 0,
          affectedLastLine: 0,
          insertedText: 'a',
          removedLength: 0,
        ),
        const DocumentChange(
          range: Range(6, 6),
          oldVersion: 1,
          newVersion: 2,
          affectedLineRange: Range(0, 0),
          affectedFirstLine: 0,
          affectedLastLine: 0,
          insertedText: 'b',
          removedLength: 0,
        ),
      ];
      const undo = DocumentChange(
        range: Range(5, 7),
        oldVersion: 2,
        newVersion: 3,
        affectedLineRange: Range(0, 0),
        affectedFirstLine: 0,
        affectedLastLine: 0,
        insertedText: '',
        removedLength: 2,
      );
      revertPendingChangesForUndo(pending, undo);
      expect(pending, isEmpty);
    });
  });

  group('clipStyleSpansBefore', () {
    test('drops spans at and after offset', () {
      const spans = [
        StyleSpan(range: Range(0, 5), color: Color(0xFFFF0000), priority: 50),
        StyleSpan(range: Range(20, 30), color: Color(0xFF00FF00), priority: 50),
      ];
      final out = clipStyleSpansBefore(spans, 10);
      expect(out.length, 1);
      expect(out.first.range, const Range(0, 5));
    });

    test('trims span crossing offset', () {
      const spans = [
        StyleSpan(range: Range(5, 15), color: Color(0xFF0000FF), priority: 50),
      ];
      final out = clipStyleSpansBefore(spans, 10);
      expect(out.single.range, const Range(5, 10));
    });
  });

  group('shiftStyleSpansForChange', () {
    test('shifts spans after pure insert', () {
      const spans = [
        StyleSpan(range: Range(20, 30), color: Color(0xFF00FF00), priority: 50),
      ];
      const change = DocumentChange(
        range: Range(10, 10),
        oldVersion: 0,
        newVersion: 1,
        affectedLineRange: Range(0, 0),
        affectedFirstLine: 0,
        affectedLastLine: 0,
        insertedText: 'abcde',
        removedLength: 0,
      );
      final out = shiftStyleSpansForChange(spans, change);
      expect(out.length, 1);
      expect(out.first.range, const Range(25, 35));
    });

    test('keeps prefix and shifts suffix across replace', () {
      const spans = [
        StyleSpan(range: Range(0, 100), color: Color(0xFFFF0000), priority: 50),
      ];
      const change = DocumentChange(
        range: Range(50, 60),
        oldVersion: 0,
        newVersion: 1,
        affectedLineRange: Range(0, 0),
        affectedFirstLine: 0,
        affectedLastLine: 0,
        insertedText: 'abc',
        removedLength: 10,
      );
      final out = shiftStyleSpansForChange(spans, change);
      expect(out.length, 2);
      expect(out.first.range, const Range(0, 50));
      expect(out[1].range, const Range(53, 93));
    });
  });

  group('styleSpansAfterPendingChanges', () {
    test('shifts tail and leaves insert uncolored', () {
      const spans = [
        StyleSpan(range: Range(0, 5), color: Color(0xFFFF0000), priority: 50),
        StyleSpan(range: Range(20, 30), color: Color(0xFF00FF00), priority: 50),
      ];
      const change = DocumentChange(
        range: Range(10, 10),
        oldVersion: 0,
        newVersion: 1,
        affectedLineRange: Range(0, 0),
        affectedFirstLine: 0,
        affectedLastLine: 0,
        insertedText: 'xx',
        removedLength: 0,
      );
      final out = styleSpansAfterPendingChanges(spans, [change]);
      expect(out.length, 2);
      expect(out.first.range, const Range(0, 5));
      expect(out[1].range, const Range(22, 32));
      for (final span in out) {
        expect(span.range.start >= 10 && span.range.end <= 12, isFalse);
      }
    });
  });

  group('mergeStyleSpansForRange', () {
    test('replaces overlapping spans and keeps outside', () {
      const sorted = [
        StyleSpan(range: Range(0, 10), color: Color(0xFFFF0000), priority: 50),
        StyleSpan(range: Range(20, 30), color: Color(0xFF00FF00), priority: 50),
      ];
      const patch = [
        StyleSpan(range: Range(5, 8), color: Color(0xFF0000FF), priority: 50),
      ];
      final out = mergeStyleSpansForRange(sorted, patch, const Range(5, 25));
      expect(out.length, 3);
      expect(out.first.range, const Range(0, 5));
      expect(out[1].range, const Range(5, 8));
      expect(out[1].color, const Color(0xFF0000FF));
      expect(out[2].range, const Range(25, 30));
    });
  });

  group('styleSpansExcludingSortedRange', () {
    test('splits span around mask', () {
      const span = StyleSpan(
        range: Range(0, 10),
        color: Color(0xFFFF0000),
        priority: 50,
      );
      final out = styleSpansExcludingRanges([span], [const Range(3, 6)]);
      expect(out.length, 2);
      expect(out.first.range, const Range(0, 3));
      expect(out[1].range, const Range(6, 10));
    });
  });

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

  group('projectOffsetForward', () {
    test('offset before edit start is unchanged', () {
      expect(projectOffsetForward(50, change(100, inserted: 'abc')), 50);
    });

    test('offset at edit start is unchanged (insertion point invariant)', () {
      expect(projectOffsetForward(100, change(100, inserted: 'abc')), 100);
    });

    test('offset after pure insert shifts by inserted length', () {
      expect(projectOffsetForward(150, change(100, inserted: 'abcde')), 155);
    });

    test('offset after delete shifts left by removed length', () {
      expect(projectOffsetForward(150, change(100, removed: 5)), 145);
    });

    test('offset inside removed range is clamped to edit start', () {
      expect(projectOffsetForward(103, change(100, removed: 5)), 100);
    });

    test('replace shifts trailing offsets by net delta', () {
      // remove 5 chars at 100, insert 2 → delta = -3.
      expect(
        projectOffsetForward(150, change(100, removed: 5, inserted: 'AB')),
        147,
      );
    });
  });

  group('projectOffsetBackward', () {
    test('offset before edit start is unchanged', () {
      expect(projectOffsetBackward(50, change(100, inserted: 'abc')), 50);
    });

    test('offset at edit start is unchanged', () {
      expect(projectOffsetBackward(100, change(100, inserted: 'abc')), 100);
    });

    test('offset after pure insert reverses inserted shift', () {
      expect(projectOffsetBackward(155, change(100, inserted: 'abcde')), 150);
    });

    test('offset after delete reverses removed shift', () {
      expect(projectOffsetBackward(145, change(100, removed: 5)), 150);
    });

    test('offset inside inserted region is clamped to edit start', () {
      // insert "abcde" at 100 → 100..105 inclusive is "new" text.
      // Backward proj of 103 should collapse to 100 (nothing in old coords).
      expect(projectOffsetBackward(103, change(100, inserted: 'abcde')), 100);
    });

    test('replace roundtrips via forward then backward', () {
      final c = change(100, removed: 5, inserted: 'XY');
      for (final p in [50, 100, 102, 110, 200]) {
        final round = projectOffsetBackward(projectOffsetForward(p, c), c);
        if (p < 100 || p >= 105) {
          expect(round, p, reason: 'roundtrip outside edit for p=$p');
        }
      }
    });
  });

  group('projectOffsetForwardChain / projectOffsetBackwardChain', () {
    test('chain forward then backward returns same offset outside edits', () {
      final pending = [
        change(50, inserted: 'ab'),
        change(200, removed: 3, inserted: 'XY'),
        change(1000, inserted: 'q'),
      ];
      // Offset 10 — before all edits.
      expect(projectOffsetForwardChain(10, pending), 10);
      expect(projectOffsetBackwardChain(10, pending), 10);
      // Offset 5000 — after all edits. delta = +2 -1 +1 = +2.
      expect(projectOffsetForwardChain(5000, pending), 5002);
      expect(projectOffsetBackwardChain(5002, pending), 5000);
    });

    test('offset between two edits shifts only by earlier edit', () {
      final pending = [
        change(50, inserted: 'ab'), // +2
        change(200, inserted: 'cd'), // +2 in post-1 coords (so original 198)
      ];
      // Original offset 100 (between edits in original coords).
      // After edit 1: 100 + 2 = 102 (in post-1 coords).
      // After edit 2 (at 200 in post-1 coords): 102 < 200 → unchanged.
      expect(projectOffsetForwardChain(100, pending), 102);
      // Backward roundtrip.
      expect(projectOffsetBackwardChain(102, pending), 100);
    });
  });

  group('leftmostPendingStartInCurrentCoords', () {
    test('null when pending journal is empty', () {
      expect(leftmostPendingStartInCurrentCoords(const []), isNull);
    });

    test('single change keeps its own start', () {
      final pending = [change(50, inserted: 'x')];
      expect(leftmostPendingStartInCurrentCoords(pending), 50);
    });

    test('monotonic forward edits use first change start', () {
      // 1) insert "ab" at 50 → coord shifts by +2 after that.
      // 2) insert "cd" at 100 (in post-1 coords).
      // Leftmost in current coords = 50 (unchanged by edit at 100).
      final pending = [change(50, inserted: 'ab'), change(100, inserted: 'cd')];
      expect(leftmostPendingStartInCurrentCoords(pending), 50);
    });

    test('non-monotonic edits: later edit to the left wins', () {
      // 1) insert "AB" at 5000 → second is in post-1 coords.
      // 2) insert "xyz" at 100 (well left of 5000).
      // First change start in current coords:
      //   5000 → projectForward through change(100, "xyz") → 5000 (since 5000 > 100, shift +3).
      //   = 5003.
      // Second change start in current coords: 100 (no later edits).
      // Min = 100.
      final pending = [
        change(5000, inserted: 'AB'),
        change(100, inserted: 'xyz'),
      ];
      expect(leftmostPendingStartInCurrentCoords(pending), 100);
    });

    test('deletion in pending shifts earlier starts left', () {
      // 1) insert "ZZ" at 1000.
      // 2) delete 10 at offset 500 (in post-1 coords).
      // First change start in current coords:
      //   1000 (post-0 coords) → projectForward through delete(500, 10) → 1000 - 10 = 990.
      // Second change start: 500.
      // Min = 500.
      final pending = [change(1000, inserted: 'ZZ'), change(500, removed: 10)];
      expect(leftmostPendingStartInCurrentCoords(pending), 500);
    });

    test('replace at the same location does not move anchor left', () {
      // 1) insert "ab" at 100.
      // 2) replace at 102 (in post-1 coords) with 1 char removed and "Z" inserted.
      // First start in current coords: 100 (unchanged by edit at 102 because 100 < 102).
      // Second start: 102. Min = 100.
      final pending = [
        change(100, inserted: 'ab'),
        change(102, removed: 1, inserted: 'Z'),
      ];
      expect(leftmostPendingStartInCurrentCoords(pending), 100);
    });
  });

  group('coalesceAdjacentPendingInserts', () {
    test('merges consecutive single-char inserts', () {
      final pending = [
        change(3303, inserted: 'a'),
        change(3304, inserted: 'b'),
        change(3305, inserted: 'c'),
      ];
      expect(coalesceAdjacentPendingInserts(pending), isTrue);
      expect(pending.length, 1);
      expect(pending.single.range.start, 3303);
      expect(pending.single.insertedText, 'abc');
    });

    test('does not merge across delete', () {
      final pending = [change(10, inserted: 'x'), change(10, removed: 1)];
      expect(coalesceAdjacentPendingInserts(pending), isFalse);
      expect(pending.length, 2);
    });

    test('does not merge non-adjacent inserts', () {
      final pending = [change(10, inserted: 'ab'), change(20, inserted: 'c')];
      expect(coalesceAdjacentPendingInserts(pending), isFalse);
      expect(pending.length, 2);
    });
  });

  group('shouldClipStaleTail', () {
    test('empty pending journal does not require clip', () {
      expect(shouldClipStaleTail(const []), isFalse);
    });

    test('single-character insert in one line does not require clip', () {
      final c = change(100, inserted: 'x');
      expect(shouldClipStaleTail([c]), isFalse);
    });

    test('backspace of a single char in one line does not require clip', () {
      final c = change(100, removed: 1);
      expect(shouldClipStaleTail([c]), isFalse);
    });

    test(
      'several single-char inserts on the same line do not require clip',
      () {
        final pending = [
          change(100, inserted: 'a'),
          change(101, inserted: 'b'),
          change(102, inserted: 'c'),
        ];
        expect(shouldClipStaleTail(pending), isFalse);
      },
    );

    test('newline insert triggers clip', () {
      final c = change(100, inserted: '\n');
      expect(shouldClipStaleTail([c]), isTrue);
    });

    test('newline somewhere in inserted block triggers clip', () {
      final c = change(100, inserted: 'foo\nbar');
      expect(shouldClipStaleTail([c]), isTrue);
    });

    test('large paste triggers clip', () {
      final c = change(0, inserted: 'A' * 5000);
      expect(shouldClipStaleTail([c]), isTrue);
    });

    test('large deletion triggers clip', () {
      final c = change(0, removed: 200);
      expect(shouldClipStaleTail([c]), isTrue);
    });

    test(
      'multi-line affected range triggers clip even without newline insert',
      () {
        // Deletion of "\n" merges two lines: affectedFirstLine != affectedLastLine.
        final c = change(50, removed: 1, firstLine: 3, lastLine: 4);
        expect(shouldClipStaleTail([c]), isTrue);
      },
    );

    test('any single triggering edit in pending forces clip', () {
      final pending = [
        change(100, inserted: 'a'),
        change(101, inserted: '\n'),
        change(102, inserted: 'b'),
      ];
      expect(shouldClipStaleTail(pending), isTrue);
    });
  });
}
