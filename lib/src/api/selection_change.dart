import 'package:editor/src/selection/selection.dart';

/// Описывает переход между двумя значениями [SelectionState].
///
/// Передаётся в [EditorHost.onSelectionChanged] при перемещении кареток пользователем
/// или кодом хоста, а также при изменении диапазонов выделения. Полезно для синхронизации
/// внешнего UI (строка состояния, minimap, LSP `textDocument/selectionRange`) с редактором.
///
/// ## Пример
///
/// ```dart
/// class MyHost with EditorHost {
///   @override
///   void onSelectionChanged(SelectionChange change) {
///     final head = change.newValue.primary.head;
///     print('Caret moved from ${change.oldValue.primary.head} to $head');
///   }
///
///   @override
///   List<StyleLayer> styleLayersFor(int documentVersion) => [];
/// }
/// ```
final class SelectionChange {
  /// Создаёт запись об изменении выделения.
  ///
  /// [oldValue] и [newValue] обязательны; они могут совпадать, если выделение
  /// обновлено без видимого изменения.
  const SelectionChange({required this.oldValue, required this.newValue});

  /// Состояние выделения до изменения.
  final SelectionState oldValue;

  /// Состояние выделения после изменения.
  final SelectionState newValue;
}
