import 'package:editor/src/editing/selection_mapper.dart';
import 'package:editor/src/editing/undo_stack.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/model/transaction.dart';
import 'package:editor/src/selection/selection.dart';

/// Координирует правки документа, обновление выделения и undo/redo.
///
/// ## Роль
///
/// Единый конвейер мутаций для [Document]:
/// - Буферизует правки в **транзакции** ([begin] → [add] → [commit])
/// - Применяет их через [Document.apply]
/// - Пересчитывает [selection] с помощью [mapSelectionsForEdits]
/// - Записывает [UndoEntry] в [undoStack], если включено
///
/// [EditorController] владеет [Transaction]; команды обращаются к нему опосредованно.
///
/// ## Поток транзакции
///
/// ```dart
/// engine.beginTransaction();
/// engine.addEdit(TextEdit.insert(0, 'a'));
/// final change = engine.commitTransaction(); // applies + undo push
/// ```
///
/// [rollback] отбрасывает ожидающие правки, не изменяя документ.
///
/// ## Undo / redo
///
/// - [undo] применяет **обратные** правки и восстанавливает [selectionBefore]
/// - [redo] повторно применяет **прямые** правки и восстанавливает [selectionAfter]
/// - Оба используют [apply] с `recordUndo: false`, чтобы не накапливать записи undo
///
/// ## Ошибки / краевые случаи
///
/// - [commit] при пустом списке ожидающих правок возвращает `null`
/// - Недопустимые диапазоны [TextEdit] выбрасывают исключение из [PieceTree] внутри [Document.apply]
/// - Вложенный [begin] при наличии ожидающих правок: второй вызов игнорируется (no-op)
final class Transaction {
  Transaction({required this.document, SelectionState? selection})
    : selection = selection ?? SelectionState();

  final Document document;
  SelectionState selection;
  final UndoStack undoStack = UndoStack();

  /// Правки, накопленные в открытой транзакции.
  final List<TextEdit> _pendingEdits = [];

  /// Метаданные открытой транзакции (merge key для undo).
  TransactionMetadata? _pendingMeta;

  /// Снимок выделения на момент [begin].
  List<Selection>? _selectionBefore;

  /// Истина, пока в транзакции есть ещё не зафиксированные правки.
  bool get hasPendingTransaction => _pendingEdits.isNotEmpty;

  /// Начинает сбор правок. Сохраняет текущее [selection] для восстановления при undo.
  ///
  /// Если транзакция уже открыта, ничего не делает (метаданные не сбрасываются).
  void begin([TransactionMetadata? metadata]) {
    if (_pendingEdits.isNotEmpty) return;
    _pendingMeta = metadata;
    _selectionBefore = List<Selection>.of(selection.selections);
  }

  /// Ставит одну [edit] в очередь открытой транзакции.
  void add(TextEdit edit) {
    _pendingEdits.add(edit);
  }

  /// Применяет ожидающие правки, обновляет выделение, при необходимости добавляет запись в undo.
  ///
  /// ## Построение обратных правок
  ///
  /// Для каждой прямой правки (в обратном порядке) создаёт [TextEdit], заменяющий
  /// вставленный фрагмент **исходным** снимком текста, взятым до применения.
  /// Так [undo] восстанавливает предыдущее состояние документа.
  ///
  /// Возвращает `null`, если ожидающих правок не было.
  DocumentChange? commit({
    bool recordUndo = true,
    bool applyFromStartToEnd = false,
  }) {
    if (_pendingEdits.isEmpty) return null;

    final before = _selectionBefore ?? selection.selections;
    final forward = List<TextEdit>.of(_pendingEdits);

    final removedTexts = <String>[];
    for (final edit in forward) {
      removedTexts.add(document.getText(edit.range));
    }

    final change = document.apply(
      forward,
      applyFromStartToEnd: applyFromStartToEnd,
    );
    selection = SelectionState(mapSelectionsForEdits(before, forward));
    final after = selection.selections;

    // Обратные правки в обратном порядке прямых: каждая заменяет вставку на снимок до apply.
    final inverse = <TextEdit>[];
    for (var i = forward.length - 1; i >= 0; i--) {
      final edit = forward[i];
      inverse.add(
        TextEdit(
          Range(edit.range.start, edit.range.start + edit.text.length),
          removedTexts[i],
        ),
      );
    }

    if (recordUndo) {
      undoStack.push(
        UndoEntry(
          inverseEdits: inverse,
          forwardEdits: forward,
          selectionBefore: before,
          selectionAfter: after,
          mergeKey: _pendingMeta?.mergeKey,
        ),
      );
    }

    _pendingEdits.clear();
    _pendingMeta = null;
    _selectionBefore = null;

    return change;
  }

  /// Отбрасывает ожидающие правки и метаданные без применения.
  void rollback() {
    _pendingEdits.clear();
    _pendingMeta = null;
    _selectionBefore = null;
  }

  /// Удобный метод: [begin], добавление всех [edits], [commit].
  ///
  /// Если задан [selectionAfter], после применения выделение принудительно устанавливается
  /// в это значение (используется undo/redo для восстановления позиций каретки).
  DocumentChange? apply(
    List<TextEdit> edits, {
    TransactionMetadata? metadata,
    List<Selection>? selectionAfter,
    bool recordUndo = true,
    bool applyFromStartToEnd = false,
  }) {
    begin(metadata);
    for (final edit in edits) {
      add(edit);
    }
    if (selectionAfter != null) {
      final change = commit(
        recordUndo: recordUndo,
        applyFromStartToEnd: applyFromStartToEnd,
      );
      if (change != null) {
        selection = SelectionState(selectionAfter);
      }
      return change;
    }
    return commit(
      recordUndo: recordUndo,
      applyFromStartToEnd: applyFromStartToEnd,
    );
  }

  /// Отменяет последнюю транзакцию, доступную для undo.
  DocumentChange? undo() {
    final entry = undoStack.popUndo();
    if (entry == null) return null;
    rollback();
    return apply(
      entry.inverseEdits,
      selectionAfter: entry.selectionBefore,
      recordUndo: false,
    );
  }

  /// Повторно применяет последнюю отменённую транзакцию.
  DocumentChange? redo() {
    final entry = undoStack.popRedo();
    if (entry == null) return null;
    rollback();
    return apply(
      entry.forwardEdits,
      selectionAfter: entry.selectionAfter,
      recordUndo: false,
      applyFromStartToEnd: true,
    );
  }
}
