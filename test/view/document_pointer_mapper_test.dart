import 'package:editor/src/layout/glyph_cache.dart';
import 'package:editor/src/layout/line_layout.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/layers/base_style_layer.dart';
import 'package:editor/src/styling/style_resolver.dart';
import 'package:editor/src/view/pointer/document_pointer_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentPointerMapper', () {
    late DocumentPointerMapper mapper;

    setUp(() {
      final doc = Document.fromText('abcdef\n');
      final theme = EditorTheme.dark().copyWith(fontFamily: 'monospace', fontSize: 14);
      final resolver = StyleResolver(
        theme: theme,
        layers: [BaseStyleLayer(theme)],
      );
      mapper = DocumentPointerMapper(
        lineLayout: LineLayout(
          document: doc,
          resolver: resolver,
          glyphCache: GlyphCache(
            fontFamily: theme.fontFamily,
            fontSize: theme.fontSize,
          ),
          theme: theme,
        ),
        document: doc,
        theme: theme,
        gutterWidth: 0,
      );
    });

    test('negative Y maps to first line not document end', () {
      final offset = mapper.surfaceLocalToOffset(const Offset(4, -2));
      expect(offset, isNotNull);
      expect(mapper.document.positionAt(offset!).line, 0);
      expect(offset, lessThan(mapper.document.length));
    });
  });
}
