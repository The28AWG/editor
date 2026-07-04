import 'package:example/lsp/lsp_snippet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('snippetToPlainText', () {
    test('removes tab stops but keeps parentheses', () {
      expect(snippetToPlainText(r'greet($1)'), 'greet()');
      expect(snippetToPlainText('main()'), 'main()');
    });

    test('expands placeholders', () {
      expect(snippetToPlainText(r'print(${1:object})'), 'print(object)');
      expect(snippetToPlainText(r'Future<${1:}>'), 'Future<>');
      expect(
        snippetToPlainText(r'String.fromCharCode(${0:charCode})'),
        'String.fromCharCode(charCode)',
      );
    });
  });
}
