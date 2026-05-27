import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/selection/selection.dart';

/// Пересчитывает каждое [Selection] в [selections] для одной [edit].
///
/// Обёртка над [mapSelectionForEdit] для мультикурсора.
List<Selection> mapSelectionsForEdit(
  List<Selection> selections,
  TextEdit edit,
) {
  final result = <Selection>[];
  for (final sel in selections) {
    result.add(mapSelectionForEdit(sel, edit));
  }
  return result;
}

/// Обновляет смещения anchor/head после одной [TextEdit].
///
/// ## Правила пересчёта смещений
///
/// Пусть `editStart = range.start`, `editEnd = range.end`, `delta = edit.delta`.
///
/// Для каждого смещения каретки:
/// - **До** правки (`offset < editStart`): без изменений
/// - **После** удалённого фрагмента (`offset > editEnd`): сдвиг на `delta`
/// - **Внутри** заменённого фрагмента (`editStart <= offset <= editEnd`): схлопывание в
///   `editStart + text.length` (конец вставки — поведение в стиле VS Code)
///
/// Anchor и head пересчитываются независимо (поддерживаются обратные выделения).
///
/// ## Пример
///
/// Текст `"hello"`, правка удаления `Range(1,4)` → `"ho"`, каретка на 4:
/// - offset 4 > editEnd 4 → преобразуется в 4 + (2 - 3) = 3
Selection mapSelectionForEdit(Selection sel, TextEdit edit) {
  final delta = edit.delta;
  final editStart = edit.range.start;
  final editEnd = edit.range.end;

  /// Переносит одно смещение каретки через границы замены [edit].
  TextOffset mapOffset(TextOffset offset) {
    if (offset < editStart) return offset;
    if (offset > editEnd) return offset + delta;
    if (offset == editEnd) return editStart + edit.text.length;
    return editStart + edit.text.length;
  }

  return Selection(mapOffset(sel.anchor), mapOffset(sel.head));
}

/// Пересчитывает [selections] для нескольких [edits] в **возрастающем** порядке start.
///
/// Каждая правка применяется к результату предыдущего пересчёта. Смещения в
/// [edits] должны относиться к состоянию документа **до** объединённой транзакции
/// (та же конвенция, что и для входа [Document.apply]).
List<Selection> mapSelectionsForEdits(
  List<Selection> selections,
  List<TextEdit> edits,
) {
  var current = selections;
  final sorted = List<TextEdit>.of(edits)
    ..sort((a, b) => a.range.start.compareTo(b.range.start));
  for (final edit in sorted) {
    current = mapSelectionsForEdit(current, edit);
  }
  return current;
}
