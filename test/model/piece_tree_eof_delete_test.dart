import 'package:editor/src/model/buffer/piece_tree.dart';
import 'package:test/test.dart';

void main() {
  test('delete after one EOF insert', () {
    const prefix = 'ab';
    final tree = PieceTree(prefix)
      ..insert(2, 'f')
      ..delete(2, 3);
    expect(tree.text, prefix);
  });

  test('delete after two EOF inserts', () {
    const prefix = 'ab';
    final tree = PieceTree(prefix)
      ..insert(2, 'f')
      ..insert(3, 'f')
      ..delete(2, 4);
    expect(tree.text, prefix);
  });

  test('delete after three EOF inserts removes all appended chars', () {
    const prefix = 'void main() {\n  print(1);\n';
    final tree = PieceTree(prefix);
    var o = prefix.length;
    tree.insert(o, 'f');
    o++;
    tree.insert(o, 'f');
    o++;
    tree.insert(o, 'f');
    expect(tree.text, '${prefix}fff');
    final end = tree.length;
    tree.delete(prefix.length, end);
    expect(tree.text, prefix);
  });
}
