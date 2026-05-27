import 'package:editor/src/model/position.dart';

/// Цель навигации: URI документа и диапазон в нём (смещения UTF-16, как в LSP).
///
/// Для текущего открытого файла [uri] совпадает с [EditorController.documentUri],
/// а [range] можно перевести в [TextOffset] через координаты того же буфера.
final class EditorDocumentLocation {
  const EditorDocumentLocation({required this.uri, required this.range});

  final String uri;

  /// Полуоткрытый диапазон `[start, end)` в целевом документе.
  final Range range;
}

/// Подсветка под курсором и куда перейти по Ctrl+клик.
final class EditorLinkTarget {
  const EditorLinkTarget({
    required this.highlightRange,
    required this.destination,
  });

  /// Диапазон, который рисуется как ссылка (подчёркивание).
  final Range highlightRange;

  final EditorDocumentLocation destination;
}
