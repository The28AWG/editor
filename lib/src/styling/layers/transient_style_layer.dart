import 'dart:ui';

import 'package:editor/src/highlight/highlight_kind.dart';
import 'package:editor/src/highlight/highlight_span.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/style_layer.dart';
import 'package:editor/src/styling/style_span.dart';

/// IME preedit, совпадение скобок, вхождения и подсветка связанного редактирования.
///
/// Временные оверлеи с наивысшим приоритетом (preedit на `1000`, подсветки на `900`).
/// Часто обновляются при перемещении каретки; не привязаны к правкам документа.
///
/// ```dart
/// final layer = TransientStyleLayer(theme: theme);
/// layer.preeditRange = imeRange;
/// layer.highlights = caretHighlightsFor(text: line, offset: caret);
/// ```
final class TransientStyleLayer implements StyleLayer {
  /// Создаёт временный слой с опциональным preedit и [highlights].
  TransientStyleLayer({
    this.preeditRange,
    this.preeditColor,
    this.highlights = const [],
    this.linkHoverRange,
    this.documentVersion,
    required this.theme,
  });

  /// Диапазон IME-композиции или `null`, когда композиция не активна.
  Range? preeditRange;

  /// Переопределение фона preedit; по умолчанию [EditorTheme.preeditBackgroundColor].
  Color? preeditColor;

  /// Эфемерные подсветки из [caretHighlightsFor] или связанного редактирования LSP.
  List<HighlightSpan> highlights;

  /// Диапазон ссылки при Ctrl+hover или `null`.
  Range? linkHoverRange;

  /// Тема, сопоставляющая [HighlightKind] с цветами фона.
  final EditorTheme theme;

  /// Опциональная метка версии документа.
  int? documentVersion;

  @override
  String get id => 'transient';

  @override
  int? get validForDocumentVersion => documentVersion;

  @override
  Iterable<StyleSpan> spansForRange(Range range) sync* {
    final preedit = preeditRange;
    if (preedit != null) {
      final start = preedit.start < range.start ? range.start : preedit.start;
      final end = preedit.end > range.end ? range.end : preedit.end;
      if (start < end) {
        yield StyleSpan(
          range: Range(start, end),
          backgroundColor: preeditColor ?? theme.preeditBackgroundColor,
          priority: 1000,
        );
      }
    }

    for (final h in highlights) {
      final start = h.range.start < range.start ? range.start : h.range.start;
      final end = h.range.end > range.end ? range.end : h.range.end;
      if (start >= end) continue;

      final color = switch (h.kind) {
        HighlightKind.occurrence => theme.occurrenceHighlightColor,
        HighlightKind.bracket => theme.bracketMatchColor,
        HighlightKind.bracketActive => theme.bracketMatchActiveColor,
        HighlightKind.linkedEditing => theme.linkedEditingHighlightColor,
      };

      yield StyleSpan(
        range: Range(start, end),
        backgroundColor: color,
        priority: 900,
      );
    }

    final link = linkHoverRange;
    if (link != null) {
      final start = link.start < range.start ? range.start : link.start;
      final end = link.end > range.end ? range.end : link.end;
      if (start < end) {
        yield StyleSpan(
          range: Range(start, end),
          underline: true,
          underlineColor: theme.navigationLinkColor,
          color: theme.navigationLinkColor,
          priority: 950,
        );
      }
    }
  }
}
