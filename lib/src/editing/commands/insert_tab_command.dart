import 'package:editor/src/editing/commands/editor_command.dart';
import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/selection/selection.dart';

/// Вставляет [EditorConfig.tabText] в каждую каретку/выделение.
///
/// Заменяет выделенный диапазон (если есть) и ставит каретку после вставленного таба.
/// Правки применяются от большего [Selection.start] к меньшему.
final class InsertTabCommand implements EditorCommand {
  @override
  String get name => 'insertTab';

  @override
  /// См. [InsertTabCommand].
  DocumentChange? execute(Transaction engine, EditorConfig config) {
    final tab = config.tabText;
    final edits = <TextEdit>[];
    final newSelections = <Selection>[];

    final sorted = List<Selection>.of(engine.selection.selections)
      ..sort((a, b) => b.start.compareTo(a.start));

    for (final sel in sorted) {
      edits.add(TextEdit.replace(sel.range, tab));
      newSelections.add(
        Selection(sel.start + tab.length, sel.start + tab.length),
      );
    }

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
