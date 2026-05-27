import 'package:editor/src/diagnostics/editor_diagnostic.dart';

/// «Призрачный» текст, рисуемый после содержимого документа на одной строке.
///
/// В отличие от [EditorDiagnostic.message] в буфере, этот текст чисто визуальный —
/// он не влияет на метрики layout документа, но расширяет ширину прокрутки
/// в [EditorScrollable._paintWidth].
///
/// На строке документа показывается не более одной метки; при нескольких диагностиках
/// на одной строке побеждает сообщение с наивысшей серьёзностью (см. [diagnosticInlineLabels]).
final class InlineDiagnosticLabel {
  /// Создаёт inline-метку для [documentLine].
  const InlineDiagnosticLabel({
    required this.documentLine,
    required this.message,
    required this.severity,
  });

  /// Индекс строки документа (с нуля).
  final int documentLine;

  /// Отформатированное сообщение (см. [formatInlineDiagnosticMessage]).
  final String message;

  /// Серьёзность, используемая для цвета «призрачного» текста.
  final DiagnosticSeverity severity;
}

/// Визуальный разделитель между многострочными частями LSP-сообщения в одной строке.
///
/// Отображается как ⏎ (U+23CE) между обрезанными сегментами, в стиле inline-
/// диагностики VS Code.
const inlineDiagnosticLineBreak = '\u23ce';

/// Форматирует LSP-сообщение диагностики [message] для inline «призрачного» отображения.
///
/// Алгоритм:
/// 1. Нормализовать `\r\n` в `\n` и обрезать внешние пробелы.
/// 2. Разбить по `\n`, обрезать каждую часть, отбросить пустые.
/// 3. Соединить непустые части через ` $inlineDiagnosticLineBreak ` (с пробелами).
///
/// Возвращает пустую строку, если после нормализации сообщение пустое.
///
/// ## Пример
///
/// ```dart
/// formatInlineDiagnosticMessage('Line one\nLine two');
/// // => 'Line one ⏎ Line two'
/// ```
String formatInlineDiagnosticMessage(String message) {
  final normalized = message.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) return '';
  final parts = normalized.split('\n');
  final out = <String>[];
  for (final part in parts) {
    final trimmed = part.trim();
    if (trimmed.isNotEmpty) out.add(trimmed);
  }
  if (out.isEmpty) return '';
  return out.join(' $inlineDiagnosticLineBreak ');
}
