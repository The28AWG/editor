import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';
import 'package:test/test.dart';

void main() {
  group('caret highlights after document shrink', () {
    test('undo with stale style viewport does not throw', () {
      final c = EditorController(initialText: 'x' * 163)
        ..apply([TextEdit.insert(163, 'xxx')]);
      expect(c.document.length, 166);
      c.updateStyleViewport(
        const ViewportStyleScope(
          firstLine: 0,
          lastLineExclusive: 10,
          documentRange: Range(0, 166),
        ),
        notify: false,
      );
      expect(() => c.undo(), returnsNormally);
      expect(c.document.length, 163);
    });

    test('getText clamps range past document end', () {
      final doc = Document.fromText('abc');
      expect(doc.getText(const Range(0, 100)), 'abc');
    });
  });
}
