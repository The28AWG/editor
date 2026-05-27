# Changelog

Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/).

## [0.0.1] — 2026-05-27

Первый публичный снимок: библиотека встраиваемого редактора и демо-приложение.

### Библиотека `editor`

- **Модель текста:** `Document` на piece tree, инкрементальный `LineIndex`, координаты в UTF-16 (`TextOffset`, `Position`, `Range`, `TextAffinity`).
- **Редактирование:** `Transaction`, undo/redo, multi-cursor, встроенные команды и расширяемый реестр через `EditorActionId` / `EditorController.perform`.
- **Стилизация:** `StyleResolver` и слои `Base`, `Syntax`, `Decoration`, `Transient`; viewport-aware запрос стилей; `PendingShiftedSyntaxLayer` при правках без полной перетокенизации.
- **Отрисовка и layout:** `EditorView`, word wrap, `GlyphCache`, gutter, каретка (`EditorCaretTheme`, мигание), прокрутка viewport.
- **Подсветка и диагностика:** `EditorDiagnostic`, подчёркивания и inline-метки, bracket matcher, подсветка слова/скобок у каретки.
- **Inlay hints:** API типов, метрик раскладки и отрисовки в строке.
- **Интеграция с хостом:** `EditorHost` (слои стилей, колбэки), `EditorLanguageService` (document highlights, inlay, ссылки), контекстное меню и переназначение клавиш, навигация по `EditorDocumentLocation` (Ctrl+клик).

### Демо `example/`

- Двухволновая подсветка Dart: **tree-sitter** (нативные `libtree-sitter` / `libtree_sitter_dart`, `highlights.scm`) и **LSP** (semantic tokens, diagnostics; semantic — full refresh).
- Переключаемые темы редактора (`DartEditorAppearance`, палитры токенов).
- Нативная сборка: `example/native/` (Makefile, Linux/macOS/Android), инструкции в [example/native/README.md](example/native/README.md).

### Документация и тесты

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — слои, потоки данных, публичные контракты, статус реализации.
- [README.md](README.md) — быстрый старт, действия, клавиши.
- ~200 тестов: `flutter test` (model, editing, styling, layout, view, highlight, inlay, navigation); в example — декодер semantic tokens и проверка native libs.

### Не входит в 0.0.1

- LSP semantic tokens range/delta (в example только full).
- Minimap, blame, injection grammars — зона хоста или последующих версий.
- Атрибутированный текст внутри `Document` (стили только через слои).
