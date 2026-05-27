import 'dart:ui';

import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_code_units.dart';
import 'package:editor/src/styling/attributed_line.dart';
import 'package:editor/src/styling/attributed_run.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/layers/pending_shifted_syntax_layer.dart';
import 'package:editor/src/styling/layers/syntax_style_layer.dart';
import 'package:editor/src/styling/resolved_style.dart';
import 'package:editor/src/styling/style_layer.dart';
import 'package:editor/src/styling/style_span.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';

/// Объединяет [StyleLayer] в списки [AttributedLine] / [AttributedRun].
///
/// Разрешает перекрывающиеся span'ы, разбивая на каждом граничном событии, затем
/// применяет активные span'ы в порядке возрастания [StyleSpan.priority] (более поздние span'ы
/// переопределяют более ранние поля).
///
/// ```dart
/// final resolver = StyleResolver(theme: theme, layers: [
///   BaseStyleLayer(theme),
///   SyntaxStyleLayer(spans: syntaxTokens),
/// ]);
/// final runs = resolver.resolveLineRuns(document, 0);
/// ```
final class StyleResolver {
  /// Создаёт резолвер с упорядоченным списком [layers] (сначала слои с наименьшим приоритетом).
  StyleResolver({required this.theme, required List<StyleLayer> layers})
    : _layers = List<StyleLayer>.of(layers);

  /// Тема, предоставляющая значения по умолчанию и метрики шрифта.
  final EditorTheme theme;

  /// Монотонно увеличивается при замене стека слоёв через [setLayers].
  int styleEpoch = 0;

  /// Заменяет все слои и увеличивает [styleEpoch] для инвалидации кэша.
  void setLayers(List<StyleLayer> layers) {
    _layers
      ..clear()
      ..addAll(layers);
    styleEpoch++;
  }

  /// Обновляет viewport hint на syntax-слоях без вызова [EditorHost.styleLayersFor].
  ///
  /// Используется при прокрутке: иначе на каждый кадр — полная пересборка стека
  /// и десятки логов/аллокаций.
  void applyViewportHint(ViewportStyleScope? viewport) {
    for (final layer in _layers) {
      if (layer is SyntaxStyleLayer) {
        layer.updateViewport(viewport);
      } else if (layer is PendingShiftedSyntaxLayer) {
        layer.updateViewport(viewport);
      }
    }
    styleEpoch++;
  }

  /// Подменяет стек слоёв; [styleEpoch] растёт только при смене ссылок.
  ///
  /// Если новый стек совпадает с текущим по [identical] на каждый элемент
  /// (типичный keystroke: тот же [PendingShiftedSyntaxLayer], обновлённый
  /// in-place), увеличивает [styleEpoch] ровно один раз — без лишнего
  /// пересоздания списка слоёв.
  void replaceLayers(List<StyleLayer> layers) {
    if (_layers.length == layers.length) {
      var allSame = true;
      for (var i = 0; i < layers.length; i++) {
        if (!identical(_layers[i], layers[i])) {
          allSame = false;
          break;
        }
      }
      if (allSame) {
        styleEpoch++;
        return;
      }
    }
    _layers
      ..clear()
      ..addAll(layers);
    styleEpoch++;
  }

  /// Разрешает стилизованные прогоны для одной строки документа (только содержимое, без завершающего `\n`).
  ///
  /// Исключает code unit перевода строки, так как он не рисуется и искажает
  /// высоту [TextPainter].
  List<AttributedRun> resolveLineRuns(Document document, int lineIndex) {
    final start = document.lineStart(lineIndex);
    // Без завершающего \n: символ перевода строки не рисуется и ломает высоту TextPainter.
    final end = document.lineContentEnd(lineIndex);
    final range = Range(start, end);
    final text = document.getText(range);
    return _resolveRange(range, text);
  }

  /// Создаёт [AttributedLine] для [lineIndex].
  AttributedLine attributedLine(Document document, int lineIndex) {
    final runs = resolveLineRuns(document, lineIndex);
    return AttributedLine(
      lineIndex: lineIndex,
      documentStart: document.lineStart(lineIndex),
      runs: runs,
    );
  }

  /// Объединяет все слои над [range] в неперекрывающиеся [AttributedRun].
  ///
  /// Алгоритм:
  /// 1. Собрать события начала/конца из каждого span слоя, пересекающего [range].
  /// 2. Отсортировать события по смещению; при одном смещении сначала начала, затем концы,
  ///    среди концов — сначала span'ы с более высоким [StyleSpan.priority].
  /// 3. Построить граничные точки из краёв диапазона и смещений событий.
  /// 4. Для каждого сегмента `[points[i], points[i+1])` собрать span'ы, полностью
  ///    покрывающие сегмент, отсортировать по приоритету, свернуть атрибуты.
  /// 5. Выдать [AttributedRun] с текстом [sliceCodeUnits] и [ResolvedStyle].
  ///
  /// Пустой текст даёт один прогон нулевой ширины с [_defaultStyle].
  List<AttributedRun> _resolveRange(Range range, String text) {
    if (text.isEmpty) {
      return [
        AttributedRun(
          start: range.start,
          end: range.start,
          text: '',
          style: _defaultStyle(),
        ),
      ];
    }

    // Один проход spansForRange на слой (не на каждый сегмент строки).
    final spansByLayer = <StyleLayer, List<StyleSpan>>{};
    for (final layer in _layers) {
      spansByLayer[layer] = layer.spansForRange(range).toList();
    }

    final events = <_StyleEvent>[];
    for (final entry in spansByLayer.entries) {
      for (final span in entry.value) {
        events
          ..add(
            _StyleEvent(span.range.start, span.priority, span, isStart: true),
          )
          ..add(
            _StyleEvent(span.range.end, span.priority, span, isStart: false),
          );
      }
    }

    // Сначала по смещению; на границе — start перед end; при end — выше priority закрывается раньше.
    events.sort((a, b) {
      final c = a.offset.compareTo(b.offset);
      if (c != 0) return c;
      if (a.isStart != b.isStart) return a.isStart ? -1 : 1;
      return b.priority.compareTo(a.priority);
    });

    final boundaries = <int>{range.start, range.end};
    for (final e in events) {
      if (e.offset >= range.start && e.offset <= range.end) {
        boundaries.add(e.offset);
      }
    }
    final points = boundaries.toList()..sort();

    final runs = <AttributedRun>[];
    for (var i = 0; i < points.length - 1; i++) {
      final segStart = points[i];
      final segEnd = points[i + 1];
      if (segStart >= segEnd) continue;

      // Span активен на сегменте, только если полностью покрывает [segStart, segEnd).
      final active = <StyleSpan>[];
      for (final spans in spansByLayer.values) {
        for (final span in spans) {
          if (span.range.start <= segStart && span.range.end >= segEnd) {
            active.add(span);
          }
        }
      }

      active.sort((a, b) => a.priority.compareTo(b.priority));

      var color = theme.defaultColor;
      var background = const Color(0x00000000);
      var weight = theme.fontWeight;
      var style = theme.fontStyle;
      var underline = false;
      var wavyUnderline = false;
      Color? underlineColor;

      for (final span in active) {
        if (span.color != null) color = span.color!;
        if (span.backgroundColor != null) {
          background = span.backgroundColor!;
        }
        if (span.fontWeight != null) weight = span.fontWeight!;
        if (span.fontStyle != null) style = span.fontStyle!;
        if (span.underline) underline = true;
        if (span.wavyUnderline) wavyUnderline = true;
        if (span.underlineColor != null) underlineColor = span.underlineColor;
      }

      final localStart = segStart - range.start;
      final localEnd = segEnd - range.start;
      runs.add(
        AttributedRun(
          start: segStart,
          end: segEnd,
          text: sliceCodeUnits(text, localStart, localEnd),
          style: ResolvedStyle(
            color: color,
            backgroundColor: background,
            fontWeight: weight,
            fontStyle: style,
            underline: underline,
            wavyUnderline: wavyUnderline,
            underlineColor: underlineColor,
            fontSize: theme.fontSize,
            fontFamily: theme.fontFamily,
          ),
        ),
      );
    }

    if (runs.isEmpty) {
      runs.add(
        AttributedRun(
          start: range.start,
          end: range.end,
          text: text,
          style: _defaultStyle(),
        ),
      );
    }
    return runs;
  }

  /// Стиль только из темы без переопределений span'ов.
  ResolvedStyle _defaultStyle() => ResolvedStyle(
    color: theme.defaultColor,
    backgroundColor: const Color(0x00000000),
    fontWeight: theme.fontWeight,
    fontStyle: theme.fontStyle,
    underline: false,
    wavyUnderline: false,
    fontSize: theme.fontSize,
    fontFamily: theme.fontFamily,
  );

  final List<StyleLayer> _layers;
}

/// Событие начала или конца [StyleSpan] на границе смещения (для sweep-line в [_resolveRange]).
final class _StyleEvent {
  _StyleEvent(this.offset, this.priority, this.span, {required this.isStart});

  /// Смещение в документе, где span начинается или заканчивается.
  final int offset;

  /// [StyleSpan.priority] для порядка при совпадении смещений.
  final int priority;

  final StyleSpan span;

  /// `true` — начало span; `false` — конец.
  final bool isStart;
}
