import 'dart:ui';

import 'package:editor/src/diagnostics/editor_diagnostic.dart';
import 'package:editor/src/diagnostics/inline_diagnostic_label.dart'
    show InlineDiagnosticLabel, formatInlineDiagnosticMessage;
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/style_span.dart';

/// Строит декорации [StyleSpan] для подчёркиваний диагностики и фона строк с ошибками.
///
/// Для каждой диагностики:
/// - Добавляет span с волнистым подчёркиванием над нормализованным диапазоном.
/// - Записывает индекс строки для диагностик [DiagnosticSeverity.error].
///
/// После обработки всех диагностик добавляет полупрозрачный фоновый span,
/// покрывающий всё содержимое каждой строки с ошибкой (приоритет [layerPriority] - 1).
///
/// Пустые или выходящие за границы диапазоны пропускаются. Диапазоны нулевой ширины
/// у EOF расширяются на один code unit через [_normalizeDiagnosticRange].
///
/// ## Пример
///
/// ```dart
/// final spans = diagnosticDecorationSpans(
///   document: controller.document,
///   diagnostics: controller.diagnostics,
///   theme: controller.theme,
/// );
/// ```
List<StyleSpan> diagnosticDecorationSpans({
  required Document document,
  required List<EditorDiagnostic> diagnostics,
  required EditorTheme theme,
  int layerPriority = 100,
}) {
  if (diagnostics.isEmpty) return const [];

  final text = document.text;
  final spans = <StyleSpan>[];
  final errorLines = <int>{};

  for (final d in diagnostics) {
    if (!_diagnosticOverlapsDocument(d.range, text.length)) continue;

    final range = _normalizeDiagnosticRange(
      _clampRangeToDocument(d.range, text.length),
      text.length,
    );
    if (range.start >= range.end && range.end >= text.length) continue;

    final startPos = document.positionAt(range.start);
    if (d.severity == DiagnosticSeverity.error) {
      errorLines.add(startPos.line);
    }

    spans.add(
      StyleSpan(
        range: range,
        underline: true,
        wavyUnderline: true,
        underlineColor: _diagnosticUnderlineColor(d.severity, theme),
        priority: layerPriority,
      ),
    );
  }

  for (final line in errorLines) {
    if (line < 0 || line >= document.lineCount) continue;
    spans.add(
      StyleSpan(
        range: Range(document.lineStart(line), document.lineContentEnd(line)),
        backgroundColor: theme.diagnosticErrorLineColor,
        priority: layerPriority - 1,
      ),
    );
  }

  return spans;
}

/// Выбирает одну inline «призрачную» метку на строку документа из [diagnostics].
///
/// Если несколько диагностик начинаются на одной строке, побеждает та, у которой
/// наименьший [_diagnosticSeverityRank] (error важнее warning, info, hint).
/// Сообщения форматируются через [formatInlineDiagnosticMessage]; пустые результаты
/// опускаются. Выход отсортирован по возрастанию [InlineDiagnosticLabel.documentLine].
List<InlineDiagnosticLabel> diagnosticInlineLabels({
  required Document document,
  required List<EditorDiagnostic> diagnostics,
}) {
  if (diagnostics.isEmpty) return const [];

  final byLine = <int, EditorDiagnostic>{};
  for (final d in diagnostics) {
    if (!_diagnosticOverlapsDocument(d.range, document.length)) continue;

    final line = document
        .positionAt(d.range.start.clamp(0, document.length))
        .line;
    // На строке — одна ghost-метка: побеждает диагностика с меньшим rank (error < warning).
    final existing = byLine[line];
    if (existing == null ||
        _diagnosticSeverityRank(d.severity) <
            _diagnosticSeverityRank(existing.severity)) {
      byLine[line] = d;
    }
  }

  final labels = <InlineDiagnosticLabel>[];
  for (final entry in byLine.entries) {
    final message = formatInlineDiagnosticMessage(entry.value.message);
    if (message.isEmpty) continue;
    labels.add(
      InlineDiagnosticLabel(
        documentLine: entry.key,
        message: message,
        severity: entry.value.severity,
      ),
    );
  }
  labels.sort((a, b) => a.documentLine.compareTo(b.documentLine));
  return labels;
}

/// Возвращает цвет темы для inline «призрачного» текста диагностики.
Color diagnosticInlineMessageColor(
  DiagnosticSeverity severity,
  EditorTheme theme,
) => switch (severity) {
  DiagnosticSeverity.error => theme.diagnosticErrorInlineColor,
  DiagnosticSeverity.warning => theme.diagnosticWarningInlineColor,
  DiagnosticSeverity.information => theme.diagnosticInfoInlineColor,
  DiagnosticSeverity.hint => theme.diagnosticHintInlineColor,
};

/// Меньший rank = более высокий визуальный приоритет при выборе inline-метки.
int _diagnosticSeverityRank(DiagnosticSeverity s) => switch (s) {
  DiagnosticSeverity.error => 0,
  DiagnosticSeverity.warning => 1,
  DiagnosticSeverity.information => 2,
  DiagnosticSeverity.hint => 3,
};

/// True, если [range] пересекается с документом длины [textLength] (смещения `[0, textLength]`).
bool _diagnosticOverlapsDocument(Range range, int textLength) =>
    range.end > 0 && range.start <= textLength;

/// Ограничивает [range] смещениями документа `[0, textLength]`.
Range _clampRangeToDocument(Range range, int textLength) {
  var start = range.start;
  var end = range.end;
  if (start < 0) start = 0;
  if (end < 0) end = 0;
  if (start > textLength) start = textLength;
  if (end > textLength) end = textLength;
  if (end < start) end = start;
  return Range(start, end);
}

/// Расширяет диапазоны диагностики нулевой ширины, чтобы подчёркивания оставались видимыми.
///
/// - Обычный диапазон (`start < end`): возвращается без изменений.
/// - Нулевая ширина до EOF: расширяется до `[start, start + 1)`.
/// - Нулевая ширина у EOF при `start > 0`: `[start - 1, start)`.
/// - Иначе: возвращается как есть (может быть пропущен вызывающим кодом).
Range _normalizeDiagnosticRange(Range range, int textLength) {
  if (range.start < range.end) return range;
  if (range.start < textLength) {
    return Range(range.start, range.start + 1);
  }
  if (range.start > 0) return Range(range.start - 1, range.start);
  return range;
}

/// Возвращает цвет подчёркивания темы для указанной [severity].
Color _diagnosticUnderlineColor(
  DiagnosticSeverity severity,
  EditorTheme theme,
) => switch (severity) {
  DiagnosticSeverity.error => theme.diagnosticErrorColor,
  DiagnosticSeverity.warning => theme.diagnosticWarningColor,
  DiagnosticSeverity.information => theme.diagnosticInfoColor,
  DiagnosticSeverity.hint => theme.diagnosticHintColor,
};
