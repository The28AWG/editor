import 'package:editor/src/model/buffer/piece_tree.dart';
import 'package:editor/src/model/text_code_units.dart';
import 'package:test/test.dart';

void main() {
  group('PieceTree', () {
    test('empty', () {
      final tree = PieceTree('');
      expect(tree.length, 0);
      expect(tree.text, '');
    });

    test('insert and delete', () {
      final tree = PieceTree('hello')..insert(5, ' world');
      expect(tree.text, 'hello world');
      tree.delete(5, 11);
      expect(tree.text, 'hello');
    });

    test('parity with String after random edits', () {
      var reference = 'The quick brown fox';
      final tree = PieceTree(reference)..insert(4, 'X');
      reference =
          '${sliceCodeUnits(reference, 0, 4)}X${sliceCodeUnits(reference, 4, reference.length)}';

      tree.delete(10, 16);
      reference =
          sliceCodeUnits(reference, 0, 10) +
          sliceCodeUnits(reference, 16, reference.length);

      tree.insert(0, '>>');
      reference = '>>$reference';

      expect(tree.text, reference);
    });
  });
}
