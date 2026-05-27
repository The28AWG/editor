import 'package:editor/src/editing/commands/editor_command.dart';
import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/selection/selection.dart';

/// Удаляет выделение или одну кодовую единицу после каждой схлопнутой каретки.
///
/// Каретки на [Document.length] не дают правки для этой каретки.
final class DeleteCommand implements EditorCommand {
  @override
  String get name => 'delete';

  @override
  /// См. [DeleteCommand].
  DocumentChange? execute(Transaction engine, EditorConfig config) {
    final doc = engine.document;
    final edits = <TextEdit>[];
    final newSelections = <Selection>[];

    // См. [BackspaceCommand]: обратный порядок start и dedup кареток внутри выделений.
    final sorted = List<Selection>.of(engine.selection.selections)
      ..sort((a, b) => b.start.compareTo(a.start));

    final expandedRanges = <Range>[
      for (final sel in sorted)
        if (!sel.isCollapsed) sel.range,
    ];

    for (final sel in sorted) {
      if (!sel.isCollapsed) {
        edits.add(TextEdit.delete(sel.range));
        newSelections.add(Selection(sel.start, sel.start));
      } else if (expandedRanges.any(
        (r) => Selection.rangeCoversCaret(r, sel.head),
      )) {
        final host = expandedRanges.firstWhere(
          (r) => Selection.rangeCoversCaret(r, sel.head),
        );
        newSelections.add(Selection(host.start, host.start));
      } else if (sel.head < doc.length) {
        edits.add(TextEdit.delete(Range(sel.head, sel.head + 1)));
        newSelections.add(Selection(sel.head, sel.head));
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
