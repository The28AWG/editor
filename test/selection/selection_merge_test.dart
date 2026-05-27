import 'package:editor/src/selection/selection.dart';
import 'package:editor/src/selection/selection_merge.dart';
import 'package:test/test.dart';

void main() {
  group('selectionsShouldMerge', () {
    test('collapsed at same offset', () {
      expect(
        selectionsShouldMerge(const Selection(5, 5), const Selection(5, 5)),
        isTrue,
      );
    });

    test('collapsed at different offsets', () {
      expect(
        selectionsShouldMerge(const Selection(5, 5), const Selection(6, 6)),
        isFalse,
      );
    });

    test('collapsed caret inside range', () {
      expect(
        selectionsShouldMerge(const Selection(7, 7), const Selection(5, 10)),
        isTrue,
      );
    });

    test('collapsed caret on range end', () {
      expect(
        selectionsShouldMerge(const Selection(10, 10), const Selection(5, 10)),
        isTrue,
      );
    });

    test('touching ranges', () {
      expect(
        selectionsShouldMerge(const Selection(5, 10), const Selection(10, 15)),
        isTrue,
      );
    });
  });

  group('mergeOverlappingSelections', () {
    test('deduplicates collapsed carets at same offset', () {
      expect(
        mergeOverlappingSelections([
          const Selection(5, 5),
          const Selection(5, 5),
          const Selection(5, 5),
        ]),
        [const Selection(5, 5)],
      );
    });

    test('merges extending selection with collapsed caret at boundary', () {
      expect(
        mergeOverlappingSelections([
          const Selection(10, 5),
          const Selection(5, 5),
        ]),
        [const Selection(10, 5)],
      );
    });

    test('merges extending selection with caret at other end', () {
      expect(
        mergeOverlappingSelections([
          const Selection(5, 5),
          const Selection(5, 10),
        ]),
        [const Selection(5, 10)],
      );
    });

    test('keeps disjoint selections', () {
      expect(
        mergeOverlappingSelections([
          const Selection(1, 1),
          const Selection(5, 5),
          const Selection(9, 9),
        ]),
        [const Selection(1, 1), const Selection(5, 5), const Selection(9, 9)],
      );
    });

    test('preserves primary group order', () {
      expect(
        mergeOverlappingSelections([
          const Selection(10, 10),
          const Selection(2, 2),
          const Selection(10, 5),
        ]),
        [const Selection(10, 5), const Selection(2, 2)],
      );
    });
  });
}
