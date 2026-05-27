import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/selection/selection.dart';

/// Утилиты буфера обмена для [EditorController] и команд `paste` / `cut`.
///
/// ## Копирование
///
/// Каждое несхлопнутое выделение даёт фрагмент; фрагменты объединяются через `\n`
/// (как при нескольких курсорах в VS Code).
///
/// ## Вставка
///
/// Если в буфере столько же строк (по `\n` / `\r\n`), сколько кареток, каждая строка
/// вставляется в свою каретку. Иначе полный текст буфера вставляется в каждую позицию.
///
/// ## Пример
///
/// ```dart
/// pasteTextsForSelections('a\nb', 2); // ['a', 'b']
/// pasteTextsForSelections('hello', 2); // ['hello', 'hello']
/// ```

/// Переносить ли каретку на точку ПКМ/long-press перед контекстным меню.
///
/// Выделение сохраняется, если [click] внутри [primary.range]; иначе каретка
/// переносится (поведение как в VS Code).
bool shouldMoveCaretForPointerMenu(TextOffset click, Selection primary) =>
    primary.isCollapsed || !primary.range.contains(click);

/// Текст для [Clipboard] из текущих выделений (между фрагментами — `\n`).
String copyTextForSelections(Document doc, List<Selection> selections) {
  final parts = <String>[];
  for (final sel in selections) {
    if (!sel.isCollapsed) parts.add(doc.getText(sel.range));
  }
  return parts.join('\n');
}

/// Есть ли хотя бы одно несхлопнутое выделение.
bool hasCopyableSelection(List<Selection> selections) {
  for (final sel in selections) {
    if (!sel.isCollapsed) return true;
  }
  return false;
}

/// Разбивает вставляемый текст на строки (`\n` / `\r\n`).
List<String> splitPasteLines(String text) {
  if (text.isEmpty) return const [''];
  final normalized = text.replaceAll('\r\n', '\n');
  return normalized.split('\n');
}

/// Текст для каждого выделения при вставке (распределение по строкам как в VS Code).
List<String> pasteTextsForSelections(String clipboard, int selectionCount) {
  if (selectionCount <= 0) return const [];
  final lines = splitPasteLines(clipboard);
  if (lines.length == selectionCount) return lines;
  return List<String>.filled(selectionCount, clipboard);
}
