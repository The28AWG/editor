import 'package:editor/src/editing/commands/editor_command.dart';
import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/model/transaction.dart';
import 'package:editor/src/selection/selection.dart';

/// Вставляет [character] в каждую каретку, заменяя выделенный диапазон.
///
/// Использует [TransactionMetadata.mergeKey] `'typing'`, чтобы последовательные нажатия
/// объединялись в один шаг undo. Порядок выделений восстанавливается после применения.
final class TypeCharacterCommand implements EditorCommand {
  TypeCharacterCommand(this.character);

  final String character;

  @override
  String get name => 'typeCharacter';

  @override
  /// См. [TypeCharacterCommand].
  DocumentChange? execute(Transaction engine, EditorConfig config) {
    if (character.isEmpty) return null;

    final edits = <TextEdit>[];
    final newSelections = <Selection>[];

    // От конца документа к началу: смещения в правках остаются валидными для всех курсоров.
    final sorted = List<Selection>.of(engine.selection.selections)
      ..sort((a, b) => b.start.compareTo(a.start));

    for (final sel in sorted) {
      final range = sel.range;
      edits.add(TextEdit.replace(range, character));
      newSelections.add(
        Selection(
          range.start + character.length,
          range.start + character.length,
        ),
      );
    }

    engine.begin(TransactionMetadata(mergeKey: 'typing', label: name));
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
