import 'package:editor/src/model/buffer/line_index.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:test/test.dart';

void main() {
  group('LineIndex.applyEdit', () {
    test('applyEdit matches full rebuild', () {
      final hundredLines = List.generate(100, (i) => 'line$i').join('\n');
      final cases =
          <
            (
              String before,
              int start,
              int removed,
              String inserted,
              String after,
            )
          >[
            ('aa\nbb\ncc', 2, 0, '\nX', 'aa\nX\nbb\ncc'),
            ('aa\nbb', 2, 1, ' ', 'aa bb'),
            (
              hundredLines,
              hundredLines.length,
              0,
              '\nnew',
              '$hundredLines\nnew',
            ),
            ('a\nb', 1, 0, '\r\nc', 'a\r\nc\nb'),
          ];

      for (final (before, start, removed, inserted, after) in cases) {
        final index = LineIndex.fromText(before)
          ..apply(start, removed, inserted);
        final rebuilt = LineIndex.fromText(after);
        expect(index.lineCount, rebuilt.lineCount, reason: after);
        for (var line = 0; line < rebuilt.lineCount; line++) {
          expect(
            index.lineStart(line),
            rebuilt.lineStart(line),
            reason: '$after line $line',
          );
        }
      }
    });
  });

  group('LineIndex vs Document.apply', () {
    test('random edits match full rebuild', () {
      var text = 'void main() {\n  print(1);\n}\n';
      var doc = Document.fromText(text);

      for (var step = 0; step < 50; step++) {
        final offset = step % doc.length;
        final edit = step.isEven
            ? TextEdit.insert(offset, 'x')
            : TextEdit.delete(
                Range(offset, offset + 1 < doc.length ? offset + 1 : offset),
              );
        if (edit.range.length == 0 && edit.text.isEmpty) continue;

        doc.apply([edit]);
        text = doc.text;
        final direct = LineIndex.fromText(text);
        for (var line = 0; line < direct.lineCount; line++) {
          expect(doc.lineStart(line), direct.lineStart(line));
        }
      }
    });
  });

  group('LineIndex.positionAt', () {
    test('binary search on many lines', () {
      final text = List.generate(5000, (i) => 'L$i').join('\n');
      final index = LineIndex.fromText(text);
      expect(index.positionAt(0, text.length), const Position(0, 0));
      final mid = text.indexOf('L2500');
      expect(index.positionAt(mid, text.length).line, 2500);
    });
  });
}
