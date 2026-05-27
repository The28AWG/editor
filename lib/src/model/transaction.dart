/// Необязательные метаданные, прикрепляемые к транзакции [Transaction].
///
/// ## Объединение undo
///
/// Когда [mergeKey] совпадает у соседних записей стека undo, [UndoStack] может
/// объединить их в один шаг undo (типично для непрерывного набора с одним ключом).
///
/// ## Пример
///
/// ```dart
/// transaction.begin(TransactionMetadata(mergeKey: 'typing'));
/// transaction.add(TextEdit.insert(offset, ch));
/// transaction.commit();
/// ```
///
/// [label] зарезервирован для отладки или будущего UI; ядро движка сегодня его не использует.
final class TransactionMetadata {
  const TransactionMetadata({this.label, this.mergeKey});

  /// Человекочитаемое описание (необязательно).
  final String? label;

  /// Идентификатор для объединения соседних транзакций в [UndoStack].
  final Object? mergeKey;
}
