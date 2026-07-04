import 'dart:ui';

import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/layers/base_style_layer.dart';
import 'package:editor/src/styling/layers/decoration_style_layer.dart';
import 'package:editor/src/styling/style_resolver.dart';
import 'package:editor/src/styling/style_span.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StyleResolver', () {
    test('decoration overrides base color', () {
      final doc = Document.fromText('hello world');
      final theme = EditorTheme.dark().copyWith(
        defaultColor: const Color(0xFFFFFFFF),
      );
      final resolver = StyleResolver(
        theme: theme,
        layers: [
          BaseStyleLayer(theme),
          DecorationStyleLayer(
            spans: [
              StyleSpan(
                range: const Range(6, 11),
                color: const Color(0xFFFF0000),
                priority: 100,
              ),
            ],
          ),
        ],
      );

      final runs = resolver.resolveLineRuns(doc, 0);
      var foundRed = false;
      for (final run in runs) {
        if (run.text.contains('world') &&
            run.style.color == const Color(0xFFFF0000)) {
          foundRed = true;
        }
      }
      expect(foundRed, isTrue);
    });

    test('wrong span 15-20 styles only " prin" not prinnt', () {
      const text = 'void main() {\n  prinnt("hello");\n}\n';
      final doc = Document.fromText(text);
      final resolver = StyleResolver(
        theme: const EditorTheme.dark(),
        layers: [
          BaseStyleLayer(const EditorTheme.dark()),
          DecorationStyleLayer(
            spans: [
              StyleSpan(
                range: const Range(15, 20),
                fontStyle: FontStyle.italic,
                priority: 100,
              ),
            ],
          ),
        ],
      );
      final runs = resolver.resolveLineRuns(doc, 1);
      final styled = runs.where((r) => r.style.fontStyle == FontStyle.italic);
      expect(styled.length, 1);
      expect(styled.first.text, ' prin');
    });

    test('span 16-22 keeps full prinnt in one italic run', () {
      const text = 'void main() {\n  prinnt("hello");\n}\n';
      final doc = Document.fromText(text);
      final resolver = StyleResolver(
        theme: const EditorTheme.dark(),
        layers: [
          BaseStyleLayer(const EditorTheme.dark()),
          DecorationStyleLayer(
            spans: [
              StyleSpan(
                range: const Range(16, 22),
                fontStyle: FontStyle.italic,
                priority: 100,
              ),
            ],
          ),
        ],
      );
      final runs = resolver.resolveLineRuns(doc, 1);
      final styled = runs.where((r) => r.style.fontStyle == FontStyle.italic);
      expect(styled.length, 1);
      expect(styled.first.text, 'prinnt');
    });

    test('null span field does not erase', () {
      final doc = Document.fromText('x');
      final theme = const EditorTheme.dark();
      final resolver = StyleResolver(
        theme: theme,
        layers: [
          BaseStyleLayer(theme),
          DecorationStyleLayer(
            spans: [
              const StyleSpan(
                range: Range(0, 1),
                underline: true,
                priority: 10,
              ),
            ],
          ),
        ],
      );
      final runs = resolver.resolveLineRuns(doc, 0);
      expect(runs.first.style.underline, isTrue);
      expect(runs.first.style.color, theme.defaultColor);
    });
  });
}
