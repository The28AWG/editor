#!/usr/bin/env bash
# Сборка libtree-sitter.so и libtree_sitter_dart.so для Android (jniLibs).
# Требует: git, make, Android NDK (ANDROID_NDK_HOME или $ANDROID_HOME/ndk/*).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=load_versions.sh
source "$ROOT/scripts/load_versions.sh"
load_versions_inc "$ROOT/versions.inc"

THIRD_PARTY="$ROOT/third_party"
TREE_SITTER_DIR="$THIRD_PARTY/tree-sitter"
GRAMMAR_DIR="$THIRD_PARTY/tree-sitter-dart"
GRAMMAR_PARSER="$GRAMMAR_DIR/src/parser.c"
GRAMMAR_SCANNER="$GRAMMAR_DIR/src/scanner.c"
JNI_LIBS="$ROOT/out/jniLibs"

# API level (minSdk Flutter обычно 21+)
ANDROID_API="${ANDROID_API:-24}"

resolve_ndk() {
  if [[ -n "${ANDROID_NDK_HOME:-}" && -d "$ANDROID_NDK_HOME" ]]; then
    echo "$ANDROID_NDK_HOME"
    return
  fi
  if [[ -n "${ANDROID_NDK_ROOT:-}" && -d "$ANDROID_NDK_ROOT" ]]; then
    echo "$ANDROID_NDK_ROOT"
    return
  fi
  if [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME/ndk" ]]; then
    local latest
    latest="$(ls -d "$ANDROID_HOME/ndk/"* 2>/dev/null | sort -V | tail -1)"
    if [[ -n "$latest" && -d "$latest" ]]; then
      echo "$latest"
      return
    fi
  fi
  echo "ERROR: Android NDK not found." >&2
  echo "Set ANDROID_NDK_HOME or install NDK via Android Studio (SDK Manager)." >&2
  exit 1
}

ndk_prebuilt_host() {
  local ndk="$1"
  case "$(uname -s)" in
    Linux) echo "$ndk/toolchains/llvm/prebuilt/linux-x86_64" ;;
    Darwin)
      if [[ -d "$ndk/toolchains/llvm/prebuilt/darwin-arm64" ]]; then
        echo "$ndk/toolchains/llvm/prebuilt/darwin-arm64"
      else
        echo "$ndk/toolchains/llvm/prebuilt/darwin-x86_64"
      fi
      ;;
    *) echo "ERROR: Unsupported host for NDK cross-build: $(uname -s)" >&2; exit 1 ;;
  esac
}

have_tree_sitter_sources() {
  [[ -f "$TREE_SITTER_DIR/lib/include/tree_sitter/api.h" ]]
}

have_grammar_sources() {
  [[ -f "$GRAMMAR_PARSER" && -f "$GRAMMAR_SCANNER" ]]
}

ensure_deps() {
  mkdir -p "$THIRD_PARTY"
  if ! have_grammar_sources; then
    echo "==> Cloning tree-sitter-dart"
    rm -rf "$GRAMMAR_DIR"
    git clone --depth 1 --branch "$TREE_SITTER_DART_REF" \
      "$TREE_SITTER_DART_REPO" "$GRAMMAR_DIR" 2>/dev/null \
      || git clone --depth 1 "$TREE_SITTER_DART_REPO" "$GRAMMAR_DIR"
  fi
  if ! have_tree_sitter_sources; then
    echo "==> Cloning tree-sitter $TREE_SITTER_VERSION"
    rm -rf "$TREE_SITTER_DIR"
    git clone --depth 1 --branch "$TREE_SITTER_VERSION" \
      "$TREE_SITTER_REPO" "$TREE_SITTER_DIR"
  fi
  have_grammar_sources && have_tree_sitter_sources || {
    echo "ERROR: third_party incomplete — run: make deps" >&2
    exit 1
  }
  # Общие исходники с desktop `make`; .git удаляется для IDE — не клонируем заново.
  find "$THIRD_PARTY" -mindepth 1 -name .git -type d -exec rm -rf {} + 2>/dev/null || true
}

build_abi() {
  local abi="$1"
  local clang_triple="$2"
  local ndk="$3"
  local host_prebuilt="$4"
  local out="$JNI_LIBS/$abi"
  local clang="$host_prebuilt/bin/${clang_triple}${ANDROID_API}-clang"
  local ar="$host_prebuilt/bin/llvm-ar"

  if [[ ! -x "$clang" ]]; then
    echo "ERROR: Clang not found: $clang" >&2
    exit 1
  fi

  mkdir -p "$out"
  echo ""
  echo "==> Android $abi ($clang_triple)"

  echo "    tree-sitter core"
  make -C "$TREE_SITTER_DIR" clean >/dev/null 2>&1 || true
  make -C "$TREE_SITTER_DIR" CC="$clang" AR="$ar" CFLAGS="-std=c11 -O2 -fPIC"

  local core_so="$TREE_SITTER_DIR/libtree-sitter.so"
  if [[ ! -f "$core_so" ]]; then
    echo "ERROR: $core_so not produced" >&2
    exit 1
  fi
  cp "$core_so" "$out/libtree-sitter.so"

  echo "    tree-sitter-dart grammar"
  "$clang" -shared -fPIC -O2 -std=c11 \
    -I "$TREE_SITTER_DIR/lib/include" \
    -I "$GRAMMAR_DIR/src" \
    "$GRAMMAR_PARSER" "$GRAMMAR_SCANNER" \
    "$TREE_SITTER_DIR/libtree-sitter.a" \
    -o "$out/libtree_sitter_dart.so"

  nm -D "$out/libtree_sitter_dart.so" 2>/dev/null | grep -q tree_sitter_dart_external_scanner_create \
    || { echo "ERROR: scanner symbols missing in $out/libtree_sitter_dart.so" >&2; exit 1; }
  nm -D "$out/libtree_sitter_dart.so" 2>/dev/null | grep -q ' tree_sitter_dart$' \
    || { echo "ERROR: tree_sitter_dart symbol missing" >&2; exit 1; }

  echo "    OK: $out"
}

NDK="$(resolve_ndk)"
HOST_PREBUILT="$(ndk_prebuilt_host "$NDK")"
echo "NDK: $NDK"
echo "Host prebuilt: $HOST_PREBUILT"

ensure_deps

# arm64-v8a — телефоны; armeabi-v7a — старые ARM; x86_64 — эмулятор
build_abi "arm64-v8a" "aarch64-linux-android" "$NDK" "$HOST_PREBUILT"
build_abi "armeabi-v7a" "armv7a-linux-androideabi" "$NDK" "$HOST_PREBUILT"
build_abi "x86_64" "x86_64-linux-android" "$NDK" "$HOST_PREBUILT"

echo ""
echo "OK: Android jniLibs -> $JNI_LIBS"
echo "Next: cd example && flutter run -d <android-device>"
