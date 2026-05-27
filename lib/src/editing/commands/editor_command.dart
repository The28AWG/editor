import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document_change.dart';

/// Подключаемое действие редактирования, применяемое через [Transaction].
///
/// Реализации формируют списки [TextEdit], выполняют транзакцию и возвращают
/// [DocumentChange]. Команды с несколькими каретками сортируют выделения по убыванию
/// [Selection.start], чтобы при применении сохранялась корректность более ранних смещений в документе.
///
/// После [commitTransaction] порядок кареток в [SelectionState] восстанавливают через
/// `newSelections.reversed` — исходный порядок selections сохраняется для UI.
abstract interface class EditorCommand {
  /// Имя для [CommandRegistry.execute] / [EditorController.executeCommand].
  String get name;

  /// Применяет команду через [Transaction]; `null`, если изменений нет.
  DocumentChange? execute(Transaction engine, EditorConfig config);
}
