import 'dart:io';

import 'package:example/tree_sitter/tree_sitter_native_config.dart';
import 'package:tree_sitter/tree_sitter.dart';

/// Проверка FFI после `make` в example/native.
///
/// Предпочтительно: `make verify` (shell + `flutter test`).
/// `dart run tool/verify_tree_sitter_native.dart` на Dart 3.12+ может падать
/// в компиляторе FFI пакета `tree_sitter` — используйте `make verify-dart` только
/// если знаете, что ваш SDK это переваривает.
void main() {
  if (Platform.isWindows) {
    stderr.writeln('Windows: используйте WSL2 или см. native/README.md');
    exit(1);
  }

  final dir = TreeSitterNativeConfig.resolveNativeDirectory();
  stdout.writeln('Resolved native dir: ${dir ?? "(not found)"}');

  if (!TreeSitterNativeConfig.ensureConfigured()) {
    stderr
      ..writeln('')
      ..writeln('Tree-sitter libraries not found.')
      ..writeln('Build: cd example/native && make')
      ..writeln('Or set TREE_SITTER_NATIVE_DIR to native/out/<platform>');
    exit(1);
  }

  final core = TreeSitterNativeConfig.resolveNativeDirectory();
  final grammar = TreeSitterNativeConfig.dartGrammarLibraryPath;
  stdout
    ..writeln('  libtree-sitter: $core')
    ..writeln('  grammar: $grammar');

  final parser = Parser(
    sharedLibrary: grammar,
    entryPoint: TreeSitterNativeConfig.dartGrammarEntryPoint,
  );

  const sample = '''
void main() {
  final x = 1;
}
''';

  final tree = parser.parse(sample);
  final rootType = tree.root.nodeType;
  if (tree.root.hasError) {
    stderr.writeln('Parse tree has errors (grammar may be mismatched).');
    exit(2);
  }

  stdout.writeln('OK: tree-sitter Dart grammar loaded (root: $rootType)');
}
