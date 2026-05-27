import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tree_sitter/tree_sitter.dart';

/// Пути к нативным библиотекам из [example/native](../native/README.md).
final class TreeSitterNativeConfig {
  TreeSitterNativeConfig._();

  static bool _configured = false;
  static String? _dartGrammarLibraryPath;

  /// `true`, если найдены обе библиотеки и FFI сконфигурирован.
  static bool get isAvailable => _configured;

  /// Путь к `libtree_sitter_dart.so` / `.dylib` для [Parser].
  static String get dartGrammarLibraryPath {
    final path = _dartGrammarLibraryPath;
    if (path == null) {
      throw StateError(
        'Tree-sitter native libraries are not configured. '
        'Build them: cd example/native && make && make verify',
      );
    }
    return path;
  }

  /// Символ входа грамматики (см. [native/versions.mk](../native/versions.mk)).
  static const dartGrammarEntryPoint = 'tree_sitter_dart';

  /// Корень пакета `example` (для `native/queries/highlights.scm`).
  static String? get examplePackageRoot => _findExampleRoot();

  /// Имена soname в APK (`jniLibs`); на Android [DynamicLibrary.open] ищет их в каталоге приложения.
  static const androidCoreLib = 'libtree-sitter.so';
  static const androidDartGrammarLib = 'libtree_sitter_dart.so';

  /// Настраивает [TreeSitterConfig] и путь к грамматике. Безопасно вызывать повторно.
  static bool ensureConfigured() {
    if (_configured) return true;

    if (Platform.isAndroid) {
      return _configureAndroid();
    }

    final dir = resolveNativeDirectory();
    if (dir == null) return false;

    final core = _libraryFile(dir, 'libtree-sitter');
    final dart = _libraryFile(dir, 'libtree_sitter_dart');
    if (!File(core).existsSync() || !File(dart).existsSync()) return false;

    TreeSitterConfig.setLibraryPath(core);
    _dartGrammarLibraryPath = dart;
    _configured = true;
    return true;
  }

  static bool _configureAndroid() {
    final bundleLib = _flutterBundleLibDir();
    if (bundleLib != null) {
      final core = _libraryFile(bundleLib, 'libtree-sitter');
      final dart = _libraryFile(bundleLib, 'libtree_sitter_dart');
      if (File(core).existsSync() && File(dart).existsSync()) {
        try {
          DynamicLibrary.open(core);
          DynamicLibrary.open(dart);
          TreeSitterConfig.setLibraryPath(core);
          _dartGrammarLibraryPath = dart;
          _configured = true;
          return true;
        } on Object catch (e, st) {
          debugPrint(
            'TreeSitterNativeConfig: load from $bundleLib failed: $e\n$st',
          );
        }
      }
    }

    final devDir = _androidDevNativeDirectory();
    if (devDir != null) {
      final core = _libraryFile(devDir, 'libtree-sitter');
      final dart = _libraryFile(devDir, 'libtree_sitter_dart');
      if (File(core).existsSync() && File(dart).existsSync()) {
        try {
          DynamicLibrary.open(core);
          DynamicLibrary.open(dart);
          TreeSitterConfig.setLibraryPath(core);
          _dartGrammarLibraryPath = dart;
          _configured = true;
          return true;
        } on Object catch (e, st) {
          debugPrint(
            'TreeSitterNativeConfig: load from dev $devDir failed: $e\n$st',
          );
        }
      }
    }

    try {
      DynamicLibrary.open(androidCoreLib);
      DynamicLibrary.open(androidDartGrammarLib);
      TreeSitterConfig.setLibraryPath(androidCoreLib);
      _dartGrammarLibraryPath = androidDartGrammarLib;
      _configured = true;
      return true;
    } on Object catch (e, st) {
      debugPrint(
        'TreeSitterNativeConfig: Android soname load failed (bundleLib=$bundleLib): $e\n$st',
      );
      return false;
    }
  }

  /// `native/out/jniLibs/<abi>/` при разработке (опционально).
  static String? _androidDevNativeDirectory() {
    final root = _findExampleRoot();
    if (root == null) return null;
    final jniRoot = Directory('$root/native/out/jniLibs');
    if (!jniRoot.existsSync()) return null;

    final abi = Platform.environment['TREE_SITTER_ANDROID_ABI'];
    if (abi != null && abi.isNotEmpty) {
      final dir = Directory('${jniRoot.path}/$abi');
      return dir.existsSync() ? dir.absolute.path : null;
    }

    for (final name in ['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
      final dir = Directory('${jniRoot.path}/$name');
      if (!dir.existsSync()) continue;
      final core = _libraryFile(dir.path, 'libtree-sitter');
      if (File(core).existsSync()) return dir.absolute.path;
    }
    return null;
  }

  /// Каталог `native/out/<platform>` или `lib/` в Flutter bundle.
  static String? resolveNativeDirectory() {
    final fromEnv = Platform.environment['TREE_SITTER_NATIVE_DIR'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final dir = Directory(fromEnv).absolute.path;
      if (Directory(dir).existsSync()) return dir;
    }

    final bundleLib = _flutterBundleLibDir();
    if (bundleLib != null) {
      final core = _libraryFile(bundleLib, 'libtree-sitter');
      if (File(core).existsSync()) return bundleLib;
    }

    final exampleRoot = _findExampleRoot();
    if (exampleRoot == null) return null;

    final outRoot = Directory('$exampleRoot/native/out');
    if (!outRoot.existsSync()) return null;

    final platform = _platformDirectoryName();
    if (platform != null) {
      final preferred = Directory('${outRoot.path}/$platform');
      if (preferred.existsSync()) return preferred.absolute.path;
    }

    for (final entry in outRoot.listSync()) {
      if (entry is Directory) {
        final core = _libraryFile(entry.path, 'libtree-sitter');
        if (File(core).existsSync()) return entry.absolute.path;
      }
    }
    return null;
  }

  static String? _flutterBundleLibDir() {
    final executable = Platform.resolvedExecutable;
    final file = File(executable);
    if (!file.existsSync()) return null;
    final parent = file.parent;

    // Linux desktop bundle: .../bundle/example + lib/
    final nested = Directory('${parent.path}/lib');
    if (nested.existsSync()) {
      final core = _libraryFile(nested.path, 'libtree-sitter');
      if (File(core).existsSync()) return nested.absolute.path;
    }

    // Android/iOS: libtree-*.so рядом с libapp.so (lib/arm64-v8a/)
    final core = _libraryFile(parent.path, 'libtree-sitter');
    if (File(core).existsSync()) return parent.absolute.path;

    return null;
  }

  static String? _findExampleRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 12; i++) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) {
        final name = _packageName('${dir.path}/pubspec.yaml');
        if (name == 'example') return dir.absolute.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  static String? _packageName(String pubspecPath) {
    for (final line in File(pubspecPath).readAsLinesSync()) {
      final t = line.trim();
      if (t.startsWith('name:')) {
        return t.characters.getRange(5).toString().trim();
      }
    }
    return null;
  }

  static String? _platformDirectoryName() {
    final fromEnv = Platform.environment['TREE_SITTER_PLATFORM'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

    if (Platform.isAndroid) return null;

    if (!Platform.isLinux && !Platform.isMacOS) return null;

    try {
      final result = Process.runSync('uname', ['-m']);
      final arch = result.stdout.toString().trim();
      if (Platform.isLinux) {
        return arch == 'aarch64' || arch == 'arm64'
            ? 'linux-arm64'
            : 'linux-x64';
      }
      return arch == 'arm64' ? 'macos-arm64' : 'macos-x64';
    } on Object {
      return Platform.isLinux ? 'linux-x64' : 'macos-arm64';
    }
  }

  static String _libraryFile(String dir, String baseName) {
    if (Platform.isWindows) {
      return '$dir/$baseName.dll';
    }
    if (Platform.isMacOS) {
      return '$dir/$baseName.dylib';
    }
    return '$dir/$baseName.so';
  }
}
