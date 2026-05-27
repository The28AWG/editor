import 'package:editor/src/highlight/highlight_kind.dart';
import 'package:editor/src/highlight/highlight_span.dart';
import 'package:editor/src/highlight/highlight_viewport.dart';
import 'package:editor/src/model/position.dart';
import 'package:test/test.dart';

void main() {
  test('highlightSpansInViewport keeps intersecting spans', () {
    const viewport = Range(10, 20);
    final spans = highlightSpansInViewport(const [
      HighlightSpan(range: Range(0, 5), kind: HighlightKind.occurrence),
      HighlightSpan(range: Range(8, 12), kind: HighlightKind.occurrence),
      HighlightSpan(range: Range(15, 25), kind: HighlightKind.linkedEditing),
      HighlightSpan(range: Range(30, 40), kind: HighlightKind.bracket),
    ], viewport);
    expect(spans, hasLength(2));
    expect(spans.first.range, const Range(8, 12));
    expect(spans[1].range, const Range(15, 25));
  });
}
