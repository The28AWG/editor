import 'package:example/tree_sitter/tree_sitter_native_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_sitter/tree_sitter.dart';

/// FFI-проверка через Flutter test (совместимо с Dart 3.12; `dart run tool/…` — нет).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native libs load and parse Dart', () {
    if (kIsWeb) return;

    expect(
      TreeSitterNativeConfig.ensureConfigured(),
      isTrue,
      reason: 'Build native: cd example/native && make',
    );

    final parser = Parser(
      sharedLibrary: TreeSitterNativeConfig.dartGrammarLibraryPath,
      entryPoint: TreeSitterNativeConfig.dartGrammarEntryPoint,
    );
    final tree = parser.parse('void main() {}');
    expect(tree.root.hasError, isFalse);
    expect(tree.root.nodeType, isNotEmpty);
  });
}
