# Сборка libtree-sitter и libtree_sitter_dart для example (Dart/Flutter).
#
# Использование:
#   make              # клонировать зависимости (при необходимости) и собрать
#   make verify       # собрать и проверить через dart
#   make clean        # удалить out/
#   make clean-all    # out/ + third_party/
#
# См. README.md — полная инструкция.

SHELL := /bin/bash
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
EXAMPLE_ROOT := $(abspath $(ROOT)/..)

include $(ROOT)/versions.mk

# --- платформа ---
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Linux)
  ifeq ($(UNAME_M),x86_64)
    PLATFORM := linux-x64
  else ifeq ($(UNAME_M),aarch64)
    PLATFORM := linux-arm64
  else
    $(error Unsupported Linux arch: $(UNAME_M). Add mapping in Makefile.)
  endif
  SOEXT := so
  SHARED_FLAGS := -shared -fPIC
  RPATH_FLAGS := -Wl,-rpath,'$$ORIGIN'
else ifeq ($(UNAME_S),Darwin)
  ifeq ($(UNAME_M),arm64)
    PLATFORM := macos-arm64
  else ifeq ($(UNAME_M),x86_64)
    PLATFORM := macos-x64
  else
    $(error Unsupported macOS arch: $(UNAME_M))
  endif
  SOEXT := dylib
  SHARED_FLAGS := -dynamiclib -fPIC
  RPATH_FLAGS := -Wl,-rpath,@loader_path
else
  $(error Unsupported OS: $(UNAME_S). See README.md for Windows notes.)
endif

CC ?= clang
ifeq ($(shell $(CC) --version 2>/dev/null | grep -c clang),0)
  CC := gcc
endif

OUT_DIR := $(ROOT)/out/$(PLATFORM)
THIRD_PARTY := $(ROOT)/third_party
TREE_SITTER_DIR := $(THIRD_PARTY)/tree-sitter
GRAMMAR_DIR := $(THIRD_PARTY)/tree-sitter-dart

LIB_TREE_SITTER := $(OUT_DIR)/libtree-sitter.$(SOEXT)
LIB_DART_GRAMMAR := $(OUT_DIR)/libtree_sitter_dart.$(SOEXT)
STAMP_TREE_SITTER := $(TREE_SITTER_DIR)/.built-$(PLATFORM)
STAMP_GRAMMAR := $(GRAMMAR_DIR)/.fetched-$(TREE_SITTER_DART_REF)

# Не использовать wildcard при чтении Makefile: third_party/ может ещё не
# существовать до `make deps`, и тогда scanner.c выпадет из сборки навсегда.
GRAMMAR_PARSER := $(GRAMMAR_DIR)/src/parser.c
GRAMMAR_SCANNER := $(GRAMMAR_DIR)/src/scanner.c

.PHONY: all android deps tree-sitter grammar dart-lib install-stamp verify clean clean-all \
        help sync-queries print-platform verify-android

.DEFAULT_GOAL := all

all: $(LIB_TREE_SITTER) $(LIB_DART_GRAMMAR)
	@echo ""
	@echo "OK: native libraries for $(PLATFORM)"
	@echo "  $(LIB_TREE_SITTER)"
	@echo "  $(LIB_DART_GRAMMAR)"
	@echo ""
	@echo "Next: cd $(EXAMPLE_ROOT) && make -C native verify"
	@echo "       flutter run -d linux   # после verify"

android:
	@bash "$(ROOT)/scripts/build_android.sh"

verify-android:
	@for abi in arm64-v8a armeabi-v7a x86_64; do \
		d="$(ROOT)/out/jniLibs/$$abi"; \
		test -f "$$d/libtree-sitter.so" && test -f "$$d/libtree_sitter_dart.so" \
			|| (echo "Missing $$d — run: make android" && exit 1); \
		nm -D "$$d/libtree_sitter_dart.so" | grep -q tree_sitter_dart_external_scanner_create \
			|| (echo "Bad $$d/libtree_sitter_dart.so" && exit 1); \
	done
	@echo "OK: Android jniLibs (arm64-v8a, armeabi-v7a, x86_64)"

help:
	@echo "Targets:"
	@echo "  make              Build libtree-sitter + libtree_sitter_dart -> native/out/<platform>/"
	@echo "  make android      Cross-build for Android -> native/out/jniLibs/<abi>/"
	@echo "  make verify-android  Check jniLibs without device"
	@echo "  make deps         Clone tree-sitter and tree-sitter-dart only"
	@echo "  make verify       Build + flutter test (host Linux/macOS)"
	@echo "  make print-platform"
	@echo "  make sync-queries Copy highlights.scm from cloned grammar (after deps)"
	@echo "  make clean        Remove native/out/"
	@echo "  make clean-all    Remove out/ and third_party/"
	@echo ""
	@echo "Platform: $(PLATFORM) (detected $(UNAME_S) $(UNAME_M))"
	@echo "Compiler: $(CC)"

print-platform:
	@echo $(PLATFORM)

deps: $(STAMP_GRAMMAR)

# --- tree-sitter core ---
$(STAMP_TREE_SITTER): $(STAMP_GRAMMAR)
	@test -d "$(TREE_SITTER_DIR)" || (echo "Run: make deps" && exit 1)
	@echo "==> Building tree-sitter $(TREE_SITTER_VERSION) for $(PLATFORM)"
	$(MAKE) -C "$(TREE_SITTER_DIR)" \
		CC="$(CC)" \
		CFLAGS="-std=c11 -O2 -fPIC" \
		AR="ar"
	@touch "$(STAMP_TREE_SITTER)"

$(LIB_TREE_SITTER): $(STAMP_TREE_SITTER)
	@mkdir -p "$(OUT_DIR)"
	@# Предпочитаем .so/.dylib из корня репозитория tree-sitter (как в Makefile пакета tree_sitter).
	@if [ -f "$(TREE_SITTER_DIR)/libtree-sitter.$(SOEXT)" ]; then \
		cp "$(TREE_SITTER_DIR)/libtree-sitter.$(SOEXT)" "$@"; \
	elif [ -f "$(TREE_SITTER_DIR)/lib/libtree-sitter.$(SOEXT)" ]; then \
		cp "$(TREE_SITTER_DIR)/lib/libtree-sitter.$(SOEXT)" "$@"; \
	else \
		echo "Building libtree-sitter.$(SOEXT) from libtree-sitter.a"; \
		$(CC) $(SHARED_FLAGS) $(RPATH_FLAGS) \
			-o "$@" \
			-L "$(TREE_SITTER_DIR)" -Wl,--whole-archive -ltree-sitter -Wl,--no-whole-archive \
			|| $(CC) $(SHARED_FLAGS) -o "$@" "$(TREE_SITTER_DIR)/libtree-sitter.a"; \
	fi
	@test -f "$@" || (echo "Failed to produce $@" && exit 1)

# --- tree-sitter-dart grammar ---
$(STAMP_GRAMMAR):
	@mkdir -p "$(THIRD_PARTY)"
	@if [ ! -f "$(GRAMMAR_PARSER)" ] || [ ! -f "$(GRAMMAR_SCANNER)" ]; then \
		echo "==> Cloning tree-sitter-dart ($(TREE_SITTER_DART_REF))"; \
		rm -rf "$(GRAMMAR_DIR)"; \
		git clone --depth 1 --branch "$(TREE_SITTER_DART_REF)" \
			"$(TREE_SITTER_DART_REPO)" "$(GRAMMAR_DIR)" 2>/dev/null \
		|| git clone --depth 1 "$(TREE_SITTER_DART_REPO)" "$(GRAMMAR_DIR)"; \
	fi
	@if [ ! -f "$(TREE_SITTER_DIR)/lib/include/tree_sitter/api.h" ]; then \
		echo "==> Cloning tree-sitter $(TREE_SITTER_VERSION)"; \
		rm -rf "$(TREE_SITTER_DIR)"; \
		git clone --depth 1 --branch "$(TREE_SITTER_VERSION)" \
			"$(TREE_SITTER_REPO)" "$(TREE_SITTER_DIR)"; \
	fi
	@test -f "$(GRAMMAR_PARSER)" || ( \
		echo "Missing $(GRAMMAR_PARSER) — install Node.js and run:"; \
		echo "  cd $(GRAMMAR_DIR) && npx tree-sitter generate"; \
		exit 1)
	@test -f "$(GRAMMAR_SCANNER)" || ( \
		echo "Missing $(GRAMMAR_SCANNER) (external scanner required for Dart grammar)"; \
		exit 1)
	@echo "==> Removing nested .git under third_party (IDE must not treat clones as repos)"
	@find "$(THIRD_PARTY)" -mindepth 1 -name .git -type d -exec rm -rf {} + 2>/dev/null || true
	@touch "$(STAMP_GRAMMAR)"

$(LIB_DART_GRAMMAR): $(LIB_TREE_SITTER) $(GRAMMAR_PARSER) $(GRAMMAR_SCANNER) $(STAMP_GRAMMAR)
	@mkdir -p "$(OUT_DIR)"
	@echo "==> Building libtree_sitter_dart.$(SOEXT) (entry: $(TREE_SITTER_DART_ENTRY), with scanner.c)"
	$(CC) $(SHARED_FLAGS) $(RPATH_FLAGS) -O2 -std=c11 \
		-I "$(TREE_SITTER_DIR)/lib/include" \
		-I "$(GRAMMAR_DIR)/src" \
		"$(GRAMMAR_PARSER)" "$(GRAMMAR_SCANNER)" \
		"$(TREE_SITTER_DIR)/libtree-sitter.a" \
		-o "$@"
	@test -f "$@" || (echo "Failed to build $@" && exit 1)
	@nm -D "$@" 2>/dev/null | grep -q 'tree_sitter_dart_external_scanner_create' \
		|| (echo "ERROR: $@ missing external scanner symbols — rebuild after: make clean && make" && exit 1)

sync-queries: $(STAMP_GRAMMAR)
	@test -f "$(GRAMMAR_DIR)/queries/highlights.scm" || (echo "Clone grammar first: make deps" && exit 1)
	cp "$(GRAMMAR_DIR)/queries/highlights.scm" "$(ROOT)/queries/highlights.scm"
	@echo "Synced queries/highlights.scm from $(GRAMMAR_DIR)"

verify: all
	@bash "$(ROOT)/scripts/verify_native_libs.sh" "$(OUT_DIR)"
	@echo ""
	@echo "==> FFI smoke test (flutter test; dart run падает на Dart 3.12 + tree_sitter)"
	@cd "$(EXAMPLE_ROOT)" && \
		TREE_SITTER_NATIVE_DIR="$(OUT_DIR)" \
		LD_LIBRARY_PATH="$(OUT_DIR)$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}" \
		flutter test test/tree_sitter_native_test.dart

.PHONY: verify-native verify-dart
verify-native: all
	@bash "$(ROOT)/scripts/verify_native_libs.sh" "$(OUT_DIR)"

# Только если нужен Dart FFI без Flutter: на SDK 3.12+ может падать (см. README).
verify-dart: all
	@export TREE_SITTER_NATIVE_DIR="$(OUT_DIR)" && \
		cd "$(EXAMPLE_ROOT)" && dart run tool/verify_tree_sitter_native.dart

clean:
	rm -rf "$(ROOT)/out"
	@echo "Removed native/out/"

clean-all: clean
	rm -rf "$(THIRD_PARTY)"
	@echo "Removed third_party/ and out/"
