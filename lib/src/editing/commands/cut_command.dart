import 'package:editor/src/editing/commands/editor_command.dart';
import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/selection/selection.dart';

/// Удаляет только несхлопнутые выделения (после копирования в буфер).
///
/// Схлопнутые каретки не трогаются — вырезание ожидает предварительный [EditorController.copy].
/// Порядок правок: от конца документа к началу (мультикурсор).
final class CutCommand implements EditorCommand {
  @override
  String get name => 'cut';

  @override
  DocumentChange? execute(Transaction engine, EditorConfig config) {
    final edits = <TextEdit>[];
    final newSelections = <Selection>[];

    // От конца документа: смещения в TextEdit.delete остаются валидными.
    final sorted = List<Selection>.of(engine.selection.selections)
      ..sort((a, b) => b.start.compareTo(a.start));

    for (final sel in sorted) {
      if (!sel.isCollapsed) {
        edits.add(TextEdit.delete(sel.range));
        newSelections.add(Selection(sel.start, sel.start));
      } else {
        newSelections.add(sel);
      }
    }

    if (edits.isEmpty) return null;

    engine.begin();
    for (final edit in edits) {
      engine.add(edit);
    }
    final change = engine.commit();
    if (change != null) {
      engine.selection = SelectionState(newSelections.reversed.toList());
    }
    return change;
  }
}
