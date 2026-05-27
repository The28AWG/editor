import 'package:editor/src/editing/commands/editor_command.dart';
import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/selection/selection.dart';

/// Заменяет каждое выделение на `\n` (LF). Автоотступ не выполняется.
///
/// Для мультикурсора каждая каретка/выделение получает отдельную вставку LF;
/// порядок правок — от конца документа (см. [TypeCharacterCommand]).
final class InsertNewlineCommand implements EditorCommand {
  @override
  String get name => 'insertNewline';

  @override
  /// См. [InsertNewlineCommand].
  DocumentChange? execute(Transaction engine, EditorConfig config) {
    const nl = '\n';
    final edits = <TextEdit>[];
    final newSelections = <Selection>[];

    final sorted = List<Selection>.of(engine.selection.selections)
      ..sort((a, b) => b.start.compareTo(a.start));

    for (final sel in sorted) {
      edits.add(TextEdit.replace(sel.range, nl));
      newSelections.add(
        Selection(sel.start + nl.length, sel.start + nl.length),
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
