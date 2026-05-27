import 'package:editor/src/editing/commands/editor_command.dart';
import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/selection/selection.dart';

/// Удаляет выделение или одну кодовую единицу перед каждой схлопнутой кареткой.
///
/// Каретки в начале документа не дают правки для этой каретки. Возвращает `null`,
/// если ничего не изменится.
final class BackspaceCommand implements EditorCommand {
  @override
  String get name => 'backspace';

  @override
  /// См. [BackspaceCommand].
  DocumentChange? execute(Transaction engine, EditorConfig config) {
    final edits = <TextEdit>[];
    final newSelections = <Selection>[];

    // Правки с конца документа: смещения в последующих TextEdit остаются валидными.
    final sorted = List<Selection>.of(engine.selection.selections)
      ..sort((a, b) => b.start.compareTo(a.start));

    // Несхлопнутые выделения в этом проходе: вторичная каретка внутри чужого
    // диапазона не удаляет символ сама — схлопывается в начало host-выделения.
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
      } else if (sel.head > 0) {
        edits.add(TextEdit.delete(Range(sel.head - 1, sel.head)));
        newSelections.add(Selection(sel.head - 1, sel.head - 1));
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
