import 'package:editor/src/editing/clipboard_text.dart';
import 'package:editor/src/editing/commands/editor_command.dart';
import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/model/transaction.dart';
import 'package:editor/src/selection/selection.dart';

/// Вставляет [text] в каждое выделение, заменяя его диапазон.
///
/// При совпадении числа строк буфера и кареток каждая каретка получает свою строку.
final class PasteCommand implements EditorCommand {
  PasteCommand(this.text);

  final String text;

  @override
  String get name => 'paste';

  @override
  DocumentChange? execute(Transaction engine, EditorConfig config) {
    if (text.isEmpty) return null;

    final selections = engine.selection.selections;
    final texts = pasteTextsForSelections(text, selections.length);
    final items = <_PasteItem>[];
    for (var i = 0; i < selections.length; i++) {
      items.add(_PasteItem(i, selections[i], texts[i]));
    }
    items.sort((a, b) => b.selection.start.compareTo(a.selection.start));

    final edits = <TextEdit>[];
    final newSelections = List<Selection>.filled(
      selections.length,
      selections.first,
    );

    for (final item in items) {
      final range = item.selection.range;
      edits.add(TextEdit.replace(range, item.text));
      final caret = range.start + item.text.length;
      newSelections[item.index] = Selection(caret, caret);
    }

    engine.begin(TransactionMetadata(mergeKey: 'paste', label: name));
    for (final edit in edits) {
      engine.add(edit);
    }
    final change = engine.commit();
    if (change != null) {
      engine.selection = SelectionState(newSelections);
    }
    return change;
  }
}

/// Связка «исходный индекс каретки → правка», чтобы после сортировки по start
/// восстановить порядок [SelectionState.selections].
final class _PasteItem {
  const _PasteItem(this.index, this.selection, this.text);

  final int index;
  final Selection selection;
  final String text;
}
