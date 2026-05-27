import 'package:editor/src/highlight/highlight_kind.dart';
import 'package:editor/src/model/position.dart';

/// Полуоткрытый диапазон подсветки с [HighlightKind] для стилизации.
///
/// Создаётся сопоставлением скобок, подсветками документа LSP и
/// [caretHighlightsFor]. Потребляется [TransientStyleLayer] для формирования
/// фоновых [StyleSpan].
///
/// ```dart
/// HighlightSpan(
///   range: Range(10, 15),
///   kind: HighlightKind.occurrence,
/// )
/// ```
final class HighlightSpan {
  /// Создаёт span, охватывающий `[range.start, range.end)` с [kind].
  const HighlightSpan({required this.range, required this.kind});

  /// Диапазон документа для подсветки (полуоткрытый, смещения code unit).
  final Range range;

  /// Категория, выбирающая цвет темы в [TransientStyleLayer].
  final HighlightKind kind;
}
