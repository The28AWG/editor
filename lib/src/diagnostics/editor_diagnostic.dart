import 'package:editor/src/model/position.dart';

/// Уровень серьёзности, соответствующий LSP `DiagnosticSeverity`.
///
/// Управляет цветом подчёркивания, необязательным фоном строки с ошибкой и цветом
/// inline «призрачного» сообщения через токены диагностики [EditorTheme].
enum DiagnosticSeverity {
  /// Блокирующая проблема; вызывает фон строки с ошибкой на этой строке.
  error,

  /// Потенциальная проблема; только волнистое подчёркивание.
  warning,

  /// Информационная заметка.
  information,

  /// Предложение или стилевой hint.
  hint,
}

/// Маркер диагностики, привязанный к [range] документа.
///
/// Обычно создаётся LSP-клиентом из `textDocument/publishDiagnostics`
/// и передаётся в [EditorController.setDiagnostics]. Редактор отображает:
///
/// - Волнистые подчёркивания над [range] ([diagnosticDecorationSpans]).
/// - Фон всей строки для [DiagnosticSeverity.error].
/// - Inline «призрачный» текст после строки ([InlineDiagnosticLabel]).
///
/// ## Пример
///
/// ```dart
/// controller.setDiagnostics([
///   EditorDiagnostic(
///     range: Range(10, 15),
///     message: 'Undefined name "foo"',
///     severity: DiagnosticSeverity.error,
///     source: 'analyzer',
///   ),
/// ]);
/// ```
final class EditorDiagnostic {
  /// Создаёт диагностику.
  ///
  /// [range] использует смещения code unit UTF-16, согласованные с [Document] и LSP.
  /// [message] может содержать `\n`; для inline-отображения нормализуется.
  const EditorDiagnostic({
    required this.range,
    required this.message,
    this.severity = DiagnosticSeverity.error,
    this.source,
  });

  /// Диапазон в буфере документа (start включительно, end исключительно).
  final Range range;

  /// Человекочитаемое описание, показываемое inline и доступное screen reader'ам.
  final String message;

  /// Визуальная серьёзность; по умолчанию [DiagnosticSeverity.error].
  final DiagnosticSeverity severity;

  /// Необязательная метка источника (например, `"dart"`, `"eslint"`); по умолчанию не рисуется.
  final String? source;
}
