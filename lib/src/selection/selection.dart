import 'package:editor/src/model/position.dart';

/// Направленное выделение: фиксированный [anchor] и активный [head] (каретка).
///
/// ## Соглашения
///
/// - [start] / [end]: min/max anchor и head (для подсвеченного диапазона)
/// - [isCollapsed]: anchor == head (только каретка)
/// - [normalize]: меняет местами anchor/head так, чтобы anchor ≤ head
///
/// ## Пример
///
/// ```dart
/// const sel = Selection(5, 10); // anchor 5, head 10
/// sel.range; // Range(5, 10)
/// Selection.collapsed(3); // zero-width at offset 3
/// ```
///
/// Используется в [SelectionState], [Transaction] и [EditorController].
final class Selection {
  const Selection(this.anchor, this.head);

  /// Каретка на [offset] с anchor == head.
  const Selection.collapsed(TextOffset offset) : this(offset, offset);

  /// Фиксированный конец выделения (откуда началось shift+arrow).
  final TextOffset anchor;

  /// Активный конец (позиция каретки).
  final TextOffset head;

  /// Истина, если подсвеченного диапазона нет.
  bool get isCollapsed => anchor == head;

  /// Меньшее из anchor и head.
  TextOffset get start => anchor < head ? anchor : head;

  /// Большее из anchor и head.
  TextOffset get end => anchor < head ? head : anchor;

  /// Полуоткрытый подсвеченный диапазон.
  Range get range => Range(start, end);

  /// Истина, если [head] внутри [range] или на его конце (`head == range.end`).
  ///
  /// Для полуоткрытого [Range] конец исключён из [Range.contains], но схлопнутая
  /// каретка на `range.end` всё равно считается «внутри» выделения при удалении.
  static bool rangeCoversCaret(Range range, TextOffset head) =>
      head > range.start && head <= range.end;

  /// Возвращает копию с anchor ≤ head.
  Selection normalize() {
    if (anchor <= head) return this;
    return Selection(head, anchor);
  }

  /// Сохраняет anchor, перемещает head.
  Selection withHead(TextOffset newHead) => Selection(anchor, newHead);

  /// Сохраняет head, перемещает anchor.
  Selection withAnchor(TextOffset newAnchor) => Selection(newAnchor, head);

  @override
  bool operator ==(Object other) =>
      other is Selection && anchor == other.anchor && head == other.head;

  @override
  int get hashCode => Object.hash(anchor, head);

  @override
  String toString() => 'Selection($anchor, $head)';
}

/// Набор параллельных выделений (редактирование с несколькими каретками).
///
/// [primary] — первый элемент; используется для подсветки языка, скобок и
/// фокуса по умолчанию. Остальные каретки — вторичные.
///
/// Конструктор по умолчанию даёт одну схлопнутую каретку в начале документа `(0,0)`.
///
/// [desiredColumns] — желаемый столбец для ↑/↓ на каждую каретку; длина должна совпадать
/// с [selections]. Если не задан или длина не совпадает, [hasDesiredColumns] ложен —
/// [EditorController.setSelection] выровняет столбцы по [Selection.head].
final class SelectionState {
  SelectionState([List<Selection>? selections, List<int>? desiredColumns])
    : selections = List<Selection>.unmodifiable(
        selections ?? [const Selection(0, 0)],
      ),
      desiredColumns = List<int>.unmodifiable(
        desiredColumns != null &&
                desiredColumns.length ==
                    (selections?.length ?? (desiredColumns.isEmpty ? 1 : 0))
            ? desiredColumns
            : const [],
      );

  final List<Selection> selections;

  /// Желаемые столбцы кареток; пустой список — «не задано».
  final List<int> desiredColumns;

  /// Заданы ли [desiredColumns] для текущего числа кареток.
  bool get hasDesiredColumns => desiredColumns.length == selections.length;

  /// Первое выделение (основная каретка).
  Selection get primary => selections.first;

  /// Заменяет только основное выделение, сохраняя вторичные каретки.
  ///
  /// Несхлопнутое [selection] сбрасывает дополнительные каретки, чтобы схлопнутая
  /// каретка на конце диапазона не давала лишний [TextEdit] при backspace/delete.
  SelectionState withPrimary(Selection selection) {
    if (!selection.isCollapsed) {
      return SelectionState([selection]);
    }
    if (selections.isEmpty) {
      return SelectionState([selection]);
    }
    final next = List<Selection>.of(selections);
    next[0] = selection;
    final nextDesired = hasDesiredColumns
        ? (List<int>.of(desiredColumns)..[0] = desiredColumns.first)
        : null;
    return SelectionState(next, nextDesired);
  }

  /// Заменяет весь список кареток.
  SelectionState withSelections(List<Selection> value) =>
      SelectionState(value, hasDesiredColumns ? desiredColumns : null);

  /// Копия с явными желаемыми столбцами.
  SelectionState withDesiredColumns(List<int> columns) =>
      SelectionState(selections, columns);

  @override
  bool operator ==(Object other) {
    if (other is! SelectionState) return false;
    if (other.selections.length != selections.length) return false;
    for (var i = 0; i < selections.length; i++) {
      if (selections[i] != other.selections[i]) return false;
    }
    if (other.desiredColumns.length != desiredColumns.length) return false;
    for (var i = 0; i < desiredColumns.length; i++) {
      if (desiredColumns[i] != other.desiredColumns[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(selections), Object.hashAll(desiredColumns));
}
