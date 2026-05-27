import 'dart:ui';

import 'package:editor/editor.dart';
import 'package:example/lsp/semantic_tokens_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes relative semantic token data', () {
    const text = 'void main() {}\n';
    const data = [
      0, 0, 4, 11, 0, // void — keyword index 11 in probe legend? use mock
    ];
    final decoder = SemanticTokensDecoder(
      tokenTypes: [
        'annotation',
        'class',
        'comment',
        'method',
        'variable',
        'parameter',
        'enum',
        'enumMember',
        'type',
        'source',
        'property',
        'keyword',
      ],
      tokenModifiers: const [],
      colorsByType: const {'keyword': Color(0xFF569CD6)},
    );
    final spans = decoder.decode(text, data);
    expect(spans.length, 1);
    expect(spans.first.range, const Range(0, 4));
    expect(spans.first.color, const Color(0xFF569CD6));
  });

  test('applies tokenModifiers bitmask', () {
    const text = 'oldName\n';
    const data = [
      0, 0, 7, 1, 2, // variable + deprecated (bit 1)
    ];
    final decoder = SemanticTokensDecoder(
      tokenTypes: ['keyword', 'variable'],
      tokenModifiers: const ['static', 'deprecated'],
      colorsByType: const {'variable': Color(0xFF9CDCFE)},
    );
    final spans = decoder.decode(text, data);
    expect(spans.length, 1);
    expect(spans.first.fontStyle, isNull);
    expect(spans.first.color, isNot(const Color(0xFF9CDCFE)));
  });

  test('static modifier sets italic', () {
    const text = 'count\n';
    const data = [
      0, 0, 5, 1, 1, // variable index 1 + static (bit 0)
    ];
    final decoder = SemanticTokensDecoder(
      tokenTypes: ['keyword', 'variable'],
      tokenModifiers: const ['static', 'deprecated'],
      colorsByType: const {'variable': Color(0xFF9CDCFE)},
    );
    final spans = decoder.decode(text, data);
    expect(spans.first.fontStyle, FontStyle.italic);
    expect(spans.first.color, const Color(0xFF9CDCFE));
  });
}
