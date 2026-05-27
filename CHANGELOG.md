## 0.0.1

* Добавлена архитектурная документация: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
* Реализованы этапы 1–10 плана: piece tree, Document, EditEngine, undo/redo, selection, команды, StyleResolver, LineLayout (word wrap), EditorView, viewport/scroll, multi-cursor (Alt+click), IME preedit, gutter, inlay API.
* Тесты: `test/model`, `test/editing`, `test/flutter`.
* Пример: `example/` с подсветкой через `DecorationStyleLayer`.
