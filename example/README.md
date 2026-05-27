# example

Демо-приложение для пакета [editor](../).

## Нативная часть (tree-sitter)

Перед запуском desktop-сборки с быстрой синтаксической подсветкой соберите нативные библиотеки:

```bash
cd native
make
make verify
```

**Полная инструкция:** [native/README.md](native/README.md) — требования, платформы, переменные окружения, устранение неполадок.

Кратко: в `native/out/<платформа>/` должны появиться `libtree-sitter.so` и `libtree_sitter_dart.so`. Без них example запустится, но первая волна подсветки (tree-sitter) будет отключена; LSP по-прежнему работает после старта language server.

## Проверка интеграции tree-sitter

### 1. Нативные библиотеки (без UI)

```bash
cd native && make && make verify
```

Ожидается: `OK: native libraries in …` и успешный `flutter test test/tree_sitter_native_test.dart`.

### 2. В приложении

```bash
flutter run -d linux
```

В AppBar строка статуса:

- `tree-sitter: on · LSP: …` — FFI и `highlights.scm` работают;
- `tree-sitter: off (build native/)` — соберите `native/` (см. [native/README.md](native/README.md)).

При `tree-sitter: on` подсветка появляется **сразу** при открытии и при каждом keystroke; через ~250 ms поверх неё доезжает LSP (semantic tokens, приоритет выше).

Код: `lib/tree_sitter/dart_tree_sitter_highlighter.dart` → `Parser` / `Query` из пакета `tree_sitter`; `lib/main.dart` отдаёт два слоя в `styleLayersFor`.

## Запуск

```bash
# из example/, после make в native/
flutter run -d linux
```

LSP (`dart language-server`) поднимается автоматически на **desktop**; на web/Android LSP обычно недоступен.

**Android (tree-sitter):** `cd native && make android` — см. [native/README.md](native/README.md#android).
