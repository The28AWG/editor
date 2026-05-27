#!/usr/bin/env bash
# Проверка собранных .so без `dart run` (на Dart 3.12 `dart run` падает на FFI в tree_sitter).
set -euo pipefail

OUT_DIR="${1:?usage: verify_native_libs.sh <native/out/platform>}"

core="$OUT_DIR/libtree-sitter.so"
dart="$OUT_DIR/libtree_sitter_dart.so"

for f in "$core" "$dart"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing: $f" >&2
    exit 1
  fi
done

for sym in tree_sitter_dart tree_sitter_dart_external_scanner_create; do
  if ! nm -D "$dart" 2>/dev/null | grep -q " $sym"; then
    echo "Symbol not found in $dart: $sym" >&2
    echo "Rebuild: make clean && make" >&2
    exit 1
  fi
done

echo "OK: native libraries in $OUT_DIR"
echo "  $core"
echo "  $dart"
echo "  symbols: tree_sitter_dart, tree_sitter_dart_external_scanner_create"
