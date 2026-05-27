import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';

/// Диапазон code units для LSP `textDocument/inlayHint`.
///
/// Базируется на scroll-окне [ViewportStyleScope.documentRange]. Если каретка
/// вне экрана, union с [ViewportStyleScope.caretSearchRange] — иначе hints у
/// off-screen каретки не запрашиваются (аналогично syntax-слоям).
Range inlayHintFetchRange(ViewportStyleScope viewport) {
  var start = viewport.documentRange.start;
  var end = viewport.documentRange.end;
  final caret = viewport.caretSearchRange;
  if (caret != null) {
    if (caret.start < start) start = caret.start;
    if (caret.end > end) end = caret.end;
  }
  return Range(start, end);
}

/// Оставляет hints, чей якорь попадает в scroll-окно [viewport.documentRange].
///
/// Якорь сравнивается как точка (`anchorOffset`), не как диапазон label.
List<EditorInlayHint> inlayHintsInViewport(
  Iterable<EditorInlayHint> hints,
  ViewportStyleScope viewport,
) {
  final r = viewport.documentRange;
  final result = <EditorInlayHint>[];
  for (final hint in hints) {
    final o = hint.anchorOffset;
    if (o < r.start) continue;
    if (o >= r.end) continue;
    result.add(hint);
  }
  return result;
}

/// Фильтрует ответ LSP по [fetchRange] (на случай лишних элементов вне запроса).
List<EditorInlayHint> filterInlayHintsForRange(
  Iterable<EditorInlayHint> hints,
  Range fetchRange,
) {
  final result = <EditorInlayHint>[];
  for (final hint in hints) {
    final o = hint.anchorOffset;
    if (o < fetchRange.start) continue;
    if (o >= fetchRange.end) continue;
    result.add(hint);
  }
  return result;
}
