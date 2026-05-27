import 'package:editor/src/layout/viewport.dart';
import 'package:test/test.dart';

void main() {
  group('ViewportState.clampScrollOffsetToContentHeight', () {
    test('clamps stale scroll after document shrink', () {
      final vp = ViewportState(viewportHeight: 400, scrollOffset: 800)
        ..clampScrollOffsetToContentHeight(500, lineHeightPx: 20);
      expect(vp.scrollOffset, 100);
      expect(vp.firstVisibleLine, 5);
    });

    test('zeroes scroll when content fits viewport', () {
      final vp = ViewportState(viewportHeight: 600, scrollOffset: 120)
        ..clampScrollOffsetToContentHeight(400, lineHeightPx: 20);
      expect(vp.scrollOffset, 0);
      expect(vp.firstVisibleLine, 0);
    });

    test('no-op when scroll already valid', () {
      final vp = ViewportState(viewportHeight: 400, scrollOffset: 50)
        ..clampScrollOffsetToContentHeight(900, lineHeightPx: 20);
      expect(vp.scrollOffset, 50);
      expect(vp.firstVisibleLine, 0);
    });
  });
}
