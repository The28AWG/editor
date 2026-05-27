import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/inlay/inlay_hint_style.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:flutter/widgets.dart';

/// Виджетная альтернатива canvas-отрисовке [EditorInlayHint].
///
/// Путь по умолчанию рисует inlay в [EditorLayersPainter] ради производительности.
/// Реализуйте [InlayHint] при построении overlay-layout (например, UI на Stack),
/// где нужны Flutter-виджеты вместо [CustomPaint].
abstract interface class InlayHint {
  /// Смещение в документе, к которому привязан этот hint.
  TextOffset get anchorOffset;

  /// Строит виджет hint, используя цвета и шрифты [theme].
  Widget build(BuildContext context, EditorTheme theme);
}

/// Текстовый [InlayHint] с раскраской по kind.
///
/// ## Пример
///
/// ```dart
/// TextInlayHint(
///   anchorOffset: 10,
///   text: ': String',
///   kind: EditorInlayHintKind.type,
/// )
/// ```
///
/// Или конвертация из модельного hint:
///
/// ```dart
/// TextInlayHint.fromEditor(lspHint)
/// ```
final class TextInlayHint implements InlayHint {
  /// Создаёт текстовый inlay в [anchorOffset].
  TextInlayHint({
    required this.anchorOffset,
    required this.text,
    this.kind = EditorInlayHintKind.other,
  });

  /// Копирует поля из экземпляра модели [EditorInlayHint].
  TextInlayHint.fromEditor(EditorInlayHint hint)
    : anchorOffset = hint.anchorOffset,
      text = hint.label,
      kind = hint.kind;

  @override
  final TextOffset anchorOffset;

  /// Текст метки (соответствует [EditorInlayHint.label]).
  final String text;

  /// Kind для поиска цвета через [inlayHintColor].
  final EditorInlayHintKind kind;

  @override
  Widget build(BuildContext context, EditorTheme theme) => Text(
    text,
    style: TextStyle(
      color: inlayHintColor(kind, theme),
      fontSize: theme.fontSize * 0.9,
      fontFamily: theme.fontFamily,
      fontStyle: FontStyle.italic,
    ),
  );
}
