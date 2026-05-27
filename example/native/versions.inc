# Общие пины (синтаксис Make). Bash: scripts/load_versions.sh

# >=0.25 — tree-sitter-dart master (LANGUAGE_VERSION 15)
TREE_SITTER_VERSION ?= v0.25.6
TREE_SITTER_REPO ?= https://github.com/tree-sitter/tree-sitter.git

TREE_SITTER_DART_REPO ?= https://github.com/UserNobody14/tree-sitter-dart.git
TREE_SITTER_DART_REF ?= master
TREE_SITTER_DART_ENTRY ?= tree_sitter_dart
