import 'package:editor/src/highlight/highlight_span.dart';
import 'package:editor/src/model/position.dart';

/// Отбрасывает spans, полностью лежащие вне [viewport].
///
/// Пересекающие viewport сохраняются целиком — обрезка по видимой части
/// выполняется позже в [TransientStyleLayer.spansForRange].
List<HighlightSpan> highlightSpansInViewport(
  Iterable<HighlightSpan> spans,
  Range viewport,
) {
  final result = <HighlightSpan>[];
  for (final span in spans) {
    if (span.range.intersect(viewport).isEmpty) continue;
    result.add(span);
  }
  return result;
}
