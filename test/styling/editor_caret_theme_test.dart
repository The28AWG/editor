import 'dart:ui';

import 'package:editor/src/styling/editor_caret_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appearanceAt lerps color and stroke width', () {
    const theme = EditorCaretBlinkTheme(
      visible: EditorCaretAppearance(color: Color(0xFFFFFFFF), strokeWidth: 2),
      hidden: EditorCaretAppearance(color: Color(0x00FFFFFF), strokeWidth: 4),
    );
    final mid = theme.appearanceAt(0.5);
    expect((mid.color.a * 255.0).round(), 128);
    expect(mid.strokeWidth, 3);
  });

  test('standard hidden is transparent', () {
    final theme = EditorCaretBlinkTheme.standard(const Color(0xFFABCDEF));
    expect(theme.visible.color, const Color(0xFFABCDEF));
    expect(theme.hidden.color.a, 0);
    expect(theme.hidden.isEffectivelyVisible, isFalse);
  });
}
