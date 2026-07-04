import 'package:example/lsp/lsp_completion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('completionListFromLsp', () {
    test('parses textEdit snippet into plain insert text', () {
      const text = 'void main() {\n  gre\n}';
      const offset = 17;
      final store = <String, Map<String, dynamic>>{};
      final list = completionListFromLsp(text, offset, {
        'isIncomplete': false,
        'items': [
          {
            'label': 'greet',
            'detail': '(String name, {int count})',
            'insertText': 'greet(\$1)',
            'insertTextFormat': 2,
            'textEdit': {
              'newText': 'greet(\$1)',
              'range': {
                'start': {'line': 1, 'character': 2},
                'end': {'line': 1, 'character': 5},
              },
            },
          },
        ],
      }, store);

      expect(list, isNotNull);
      final item = list!.items.single;
      expect(item.textEdit?.text, 'greet()');
      expect(
        completionApplyEdit(item: item, fallbackRange: list.replaceRange).text,
        'greet()',
      );
    });

    test('falls back to detail parentheses when insert text is missing', () {
      const text = 'gre';
      final store = <String, Map<String, dynamic>>{};
      final list = completionListFromLsp(text, 3, {
        'items': [
          {'label': 'greet', 'detail': '(String name)'},
        ],
      }, store);

      final item = list!.items.single;
      expect(
        completionApplyEdit(item: item, fallbackRange: list.replaceRange).text,
        'greet()',
      );
    });
  });
}
