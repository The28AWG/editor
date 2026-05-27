import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/selection/selection.dart';

/// Снимок одной транзакции [Transaction], доступной для undo.
final class UndoEntry {
  UndoEntry({
    required this.inverseEdits,
    required this.forwardEdits,
    required this.selectionBefore,
    required this.selectionAfter,
    this.mergeKey,
  });

  /// Правки, восстанавливающие документ до состояния до транзакции.
  final List<TextEdit> inverseEdits;

  /// Исходные прямые правки (для redo).
  final List<TextEdit> forwardEdits;

  /// Каретки до транзакции.
  final List<Selection> selectionBefore;

  /// Каретки после транзакции.
  final List<Selection> selectionAfter;

  /// Если не null, может объединиться с предыдущей записью стека при совпадении.
  final Object? mergeKey;
}

/// Линейная история undo/redo для транзакций правок.
///
/// ## Поведение слияния
///
/// Когда [UndoEntry.mergeKey] совпадает с ключом предыдущей записи, [push] объединяет:
/// - `forwardEdits`: сначала более старые, затем более новые
/// - `inverseEdits`: сначала более новые обратные, затем более старые (чтобы undo применялся в правильном порядке)
/// - `selectionBefore`: из **первой** объединённой транзакции
/// - `selectionAfter`: из **последней** объединённой транзакции
///
/// Любая новая правка очищает стек redo ([_redo]).
///
/// ## Использование
///
/// Принадлежит [Transaction]. [EditorController.canUndo] / [canRedo] отражают состояние стека.
final class UndoStack {
  final List<UndoEntry> _undo = [];
  final List<UndoEntry> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Записывает [entry]; объединяет с предыдущей, если [UndoEntry.mergeKey] совпадает.
  ///
  /// Записи с пустым [forwardEdits] игнорируются.
  void push(UndoEntry entry) {
    if (entry.forwardEdits.isEmpty) return;

    if (entry.mergeKey != null &&
        _undo.isNotEmpty &&
        _undo.last.mergeKey == entry.mergeKey) {
      final last = _undo.removeLast();
      // inverse: новые undo-шаги первыми; forward: хронология набора символов сохраняется.
      _undo.add(
        UndoEntry(
          inverseEdits: [...entry.inverseEdits, ...last.inverseEdits],
          forwardEdits: [...last.forwardEdits, ...entry.forwardEdits],
          selectionBefore: last.selectionBefore,
          selectionAfter: entry.selectionAfter,
          mergeKey: entry.mergeKey,
        ),
      );
    } else {
      _undo.add(entry);
    }
    _redo.clear();
  }

  /// Удаляет и возвращает последнюю запись undo; помещает её в стек redo.
  UndoEntry? popUndo() {
    if (_undo.isEmpty) return null;
    final entry = _undo.removeLast();
    _redo.add(entry);
    return entry;
  }

  /// Извлекает запись из стека redo и возвращает её для повторного применения.
  UndoEntry? popRedo() {
    if (_redo.isEmpty) return null;
    final entry = _redo.removeLast();
    _undo.add(entry);
    return entry;
  }
}
