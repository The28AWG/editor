import 'package:editor/src/model/position.dart';

/// Категория inlay hint, соответствующая LSP `InlayHintKind`.
enum EditorInlayHintKind {
  /// Hint с аннотацией типа (например, выведенный тип в Dart/TypeScript).
  type,

  /// Hint с именем параметра в месте вызова.
  parameter,

  /// Любой другой или неуказанный тип.
  other,
}

/// Виртуальный текст, вставляемый в [anchorOffset] при layout и отрисовке.
///
/// Inlay hints не входят в буфер [Document]. Они резервируют горизонтальное
/// пространство через [InlayLayoutMetrics] и рисуются в [EditorLayersPainter]
/// между сегментами текста документа.
///
/// ## Пример
///
/// ```dart
/// EditorInlayHint(
///   anchorOffset: 42,
///   label: ': int',
///   kind: EditorInlayHintKind.type,
///   paddingLeft: 2,
/// )
/// ```
final class EditorInlayHint {
  /// Создаёт inlay hint, привязанный к смещению в документе.
  const EditorInlayHint({
    required this.anchorOffset,
    required this.label,
    this.kind = EditorInlayHintKind.other,
    this.paddingLeft = 0,
    this.paddingRight = 0,
  });

  /// Смещение в документе (UTF-16), куда вставляется hint — текст появляется после
  /// символа перед этим смещением (семантика якоря LSP).
  final TextOffset anchorOffset;

  /// Отображаемая строка (не редактируется пользователем).
  final String label;

  /// Определяет цвет через [inlayHintColor].
  final EditorInlayHintKind kind;

  /// Дополнительное пространство перед [label] в логических пикселях.
  final double paddingLeft;

  /// Дополнительное пространство после [label] в логических пикселях.
  final double paddingRight;
}
