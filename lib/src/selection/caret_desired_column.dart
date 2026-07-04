import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/selection/selection.dart';

/// Желаемый столбец каретки для вертикального перемещения (↑/↓).
abstract final class CaretDesiredColumn {
  CaretDesiredColumn._();

  /// Столбец UTF-16 на строке [offset].
  static int at(Document doc, TextOffset offset) =>
      doc.positionAt(offset).column;

  /// По одному желаемому столбцу на каждую каретку ([Selection.head]).
  static List<int> fromHeads(Document doc, List<Selection> selections) {
    final cols = <int>[];
    for (final sel in selections) {
      cols.add(at(doc, sel.head));
    }
    return cols;
  }

  /// Сохраняет [existing] по индексу; для новых кареток — столбец [head].
  static List<int> align(
    Document doc,
    List<Selection> selections,
    List<int> existing,
  ) {
    final cols = <int>[];
    for (var i = 0; i < selections.length; i++) {
      cols.add(i < existing.length ? existing[i] : at(doc, selections[i].head));
    }
    return cols;
  }

  /// После [mergeOverlappingSelections]: для схлопнутых кареток на одном [head] берётся max desired.
  static List<int> afterMerge(
    Document doc,
    List<Selection> input,
    List<int> inputDesired,
    List<Selection> merged,
  ) {
    final cols = <int>[];
    for (final m in merged) {
      var col = at(doc, m.head);
      if (m.isCollapsed) {
        for (var i = 0; i < input.length; i++) {
          if (input[i].isCollapsed &&
              input[i].head == m.head &&
              i < inputDesired.length &&
              inputDesired[i] > col) {
            col = inputDesired[i];
          }
        }
      }
      cols.add(col);
    }
    return cols;
  }
}
