import 'package:editor/src/styling/editor_caret_theme.dart';
import 'package:editor/src/view/caret/caret_blink_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const theme = EditorCaretBlinkTheme(
    visibleDuration: Duration(milliseconds: 500),
    hiddenDuration: Duration(milliseconds: 500),
    solidDuration: Duration(milliseconds: 300),
  );

  test('solid pause keeps visible phase', () {
    expect(
      caretBlinkLerpT(
        elapsed: const Duration(milliseconds: 200),
        solidUntil: const Duration(milliseconds: 300),
        theme: theme,
      ),
      0,
    );
  });

  test('blinks after solid ends', () {
    const solid = Duration(milliseconds: 300);
    expect(
      caretBlinkLerpT(
        elapsed: const Duration(milliseconds: 400),
        solidUntil: solid,
        theme: theme,
      ),
      0,
    );
    expect(
      caretBlinkLerpT(
        elapsed: const Duration(milliseconds: 900),
        solidUntil: solid,
        theme: theme,
      ),
      1,
    );
  });

  test('delay until next phase respects solid window', () {
    const solid = Duration(milliseconds: 300);
    expect(
      caretBlinkDelayUntilNextPhase(
        elapsed: const Duration(milliseconds: 100),
        solidUntil: solid,
        theme: theme,
      ),
      const Duration(milliseconds: 200),
    );
  });

  test('disabled theme stays visible', () {
    const disabled = EditorCaretBlinkTheme.disabled();
    expect(
      caretBlinkLerpT(
        elapsed: const Duration(seconds: 10),
        solidUntil: Duration.zero,
        theme: disabled,
      ),
      0,
    );
  });
}
