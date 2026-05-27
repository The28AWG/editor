import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/resolved_style.dart';

/// Стилизованный непрерывный прогон в пределах одной строки документа.
///
/// Каждый прогон имеет единообразный [ResolvedStyle] и фрагмент [text],
/// соответствующий `[start, end)` в буфере документа.
final class AttributedRun {
  /// Создаёт прогон с границами в документе и разрешённым стилем.
  const AttributedRun({
    required this.start,
    required this.end,
    required this.text,
    required this.style,
  });

  /// Включительное начальное смещение в документе.
  final TextOffset start;

  /// Исключительное конечное смещение в документе.
  final TextOffset end;

  /// Текстовое содержимое этого прогона (подстрока строки, без завершающего перевода строки).
  final String text;

  /// Полностью объединённый стиль для отрисовки и макета.
  final ResolvedStyle style;
}
