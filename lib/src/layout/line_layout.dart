import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/inlay/inlay_layout_metrics.dart';
import 'package:editor/src/layout/glyph_cache.dart';
import 'package:editor/src/layout/styled_run_layout.dart';
import 'package:editor/src/layout/text_box.dart';
import 'package:editor/src/layout/visual_line.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_code_units.dart';
import 'package:editor/src/styling/attributed_run.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/style_resolver.dart';

/// Сопоставляет строки документа с пиксельными координатами.
///
/// Разрешает стилизованные текстовые прогоны, при необходимости переносит
/// слова по [wrapWidth] и преобразует смещения документа в координаты X/Y
/// макета для hit-testing, позиционирования каретки и прямоугольников выделения.
/// Результаты кэшируются для каждой строки документа до вызова [invalidate].
///
/// ```dart
/// final layout = LineLayout(
///   document: document,
///   resolver: styleResolver,
///   glyphCache: glyphCache,
///   theme: theme,
///   wrapWidth: 800,
/// );
/// final offset = layout.getOffsetAtPoint(0, 42.0, localYInLine: 18);
/// final boxes = layout.getBoxesForRange(selection, theme.lineHeight);
/// ```
final class LineLayout {
  /// Создаёт движок макета, привязанный к [document], [_resolver] и [glyphCache].
  LineLayout({
    required this.document,
    required StyleResolver resolver,
    required this.glyphCache,
    required this.theme,
    this.inlays = const [],
    this.wrapWidth,
  }) {
    _resolver = resolver;
    _styledLayout = StyledRunLayout(
      document: document,
      runsForLine: attributedRunsForLine,
    );
  }

  /// Исходный документ для текста строк и смещений.
  final Document document;

  /// Резолвер стилей, формирующий [AttributedRun] для каждой строки.
  late StyleResolver _resolver;

  /// Резолвер стилей, формирующий [AttributedRun] для каждой строки.
  StyleResolver get resolver => _resolver;

  /// Кэш ширины глифов для измерения простого текста и переноса.
  final GlyphCache glyphCache;

  /// Тема для высоты строк и стилизации inlay.
  final EditorTheme theme;

  /// Inlay-подсказки, влияющие на горизонтальный макет (ширина и сопоставление смещений).
  List<EditorInlayHint> inlays;

  /// Максимальная ширина визуальной строки до переноса; `null` или неположительное значение отключает перенос.
  double? wrapWidth;

  /// Помощник макета с учётом inlay или `null`, когда [inlays] пуст.
  InlayLayoutMetrics? get inlayMetrics => inlays.isEmpty
      ? null
      : InlayLayoutMetrics(
          glyphCache: glyphCache,
          theme: theme,
          inlays: inlays,
          styledLayout: _styledLayout,
        );

  /// Кэш [visualLinesForDocumentLine] по индексу строки документа.
  final Map<int, List<VisualLine>> _visualCache = {};

  /// Кэш [attributedRunsForLine] по индексу строки документа.
  final Map<int, List<AttributedRun>> _attributedCache = {};

  /// Префикс-сумма высот блоков: `_blockTops[i]` — координата верха строки `i`,
  /// `_blockTops[lineCount]` — общая высота. Длина — число просчитанных строк + 1.
  final List<double> _blockTops = [0];

  /// Высота строки, для которой посчитан текущий [_blockTops]; смена `lineHeight`
  /// темы инвалидирует кэш.
  double _blockTopsLineHeight = 0;

  double? _cachedMaxWidth;
  int? _maxWidthLine;

  late StyledRunLayout _styledLayout;

  /// Можно ли считать высоту строки константой (`lineH`) без обращения к
  /// [visualLinesForDocumentLine]. Без word-wrap каждая строка документа даёт
  /// ровно одну визуальную строку, поэтому позиции/высоты вычисляются формулой
  /// `lineIndex * lineH` — это снимает O(N) обход кэша в paint при правках
  /// в больших файлах.
  bool get _hasUniformBlockHeight =>
      wrapWidth == null || wrapWidth!.isInfinite || wrapWidth! <= 0;

  /// Подменяет [resolver] (например, после `_rebuildResolver`) без нового [LineLayout].
  ///
  /// Если задан [invalidateAttributedFromLine], очищает [_attributedCache] только
  /// для строк `>=` этого индекса (типичная правка в середине файла). Иначе — полный сброс.
  void updateResolver(
    StyleResolver resolver, {
    int? invalidateAttributedFromLine,
  }) {
    _resolver = resolver;
    if (invalidateAttributedFromLine == null) {
      _attributedCache.clear();
      _visualCache.clear();
      return;
    }
    final from = invalidateAttributedFromLine;
    final keys = _attributedCache.keys.where((k) => k >= from).toList();
    for (final k in keys) {
      _attributedCache.remove(k);
    }
  }

  /// Подменяет [inlays] и сбрасывает кэши макета.
  void updateInlays(List<EditorInlayHint> value) {
    inlays = List<EditorInlayHint>.of(value);
    invalidate();
    invalidateHeightCache();
    invalidateMaxWidthCache();
  }

  /// Обрезает кэши, если документ стал короче (удаление строк в конце).
  void truncateToLineCount(int lineCount) {
    if (lineCount < 0) return;
    if (_blockTops.length > lineCount + 1) {
      _blockTops.removeRange(lineCount + 1, _blockTops.length);
    }
    final visKeys = _visualCache.keys.where((k) => k >= lineCount).toList();
    for (final key in visKeys) {
      _visualCache.remove(key);
    }
    final attrKeys = _attributedCache.keys
        .where((k) => k >= lineCount)
        .toList();
    for (final key in attrKeys) {
      _attributedCache.remove(key);
    }
    final maxLine = _maxWidthLine;
    if (maxLine != null && maxLine >= lineCount) {
      _cachedMaxWidth = null;
      _maxWidthLine = null;
    }
  }

  /// Очищает кэшированные визуальные и стилизованные строки.
  ///
  /// Если [fromLine] равен `null`, удаляет весь кэш. Иначе удаляет записи
  /// для строк документа `>= fromLine` (после правки смещаются offset'ы хвоста).
  void invalidate({int? fromLine}) {
    if (fromLine == null) {
      _visualCache.clear();
      _attributedCache.clear();
      return;
    }
    final visKeys = _visualCache.keys.toList();
    for (final key in visKeys) {
      if (key >= fromLine) _visualCache.remove(key);
    }
    final attrKeys = _attributedCache.keys.toList();
    for (final key in attrKeys) {
      if (key >= fromLine) _attributedCache.remove(key);
    }
  }

  /// Сбрасывает префикс-сумму высот с [fromLine] (или полностью при `null`).
  void invalidateHeightCache({int? fromLine}) {
    if (fromLine == null || fromLine <= 0) {
      _blockTops
        ..clear()
        ..add(0);
      return;
    }
    if (fromLine + 1 < _blockTops.length) {
      _blockTops.removeRange(fromLine + 1, _blockTops.length);
    }
  }

  /// Сбрасывает кэш [maxLinePaintWidth], только если самая широкая строка
  /// попадает в затронутый диапазон `[fromLine, toLine]` (включительно).
  ///
  /// Раньше сбрасывали при `maxLine >= fromLine`, из‑за чего правка на строке 89
  /// инвалидировала кэш, хотя max width был на строке 1500 — и каждый `build()`
  /// заново обходил весь документ в [maxLinePaintWidth].
  void invalidateMaxWidthCache({int? fromLine, int? toLine}) {
    if (fromLine == null) {
      _cachedMaxWidth = null;
      _maxWidthLine = null;
      _maxWidthRescanFrom = null;
      return;
    }
    final last = toLine ?? (document.lineCount - 1);
    final maxLine = _maxWidthLine;
    if (maxLine != null && (maxLine < fromLine || maxLine > last)) {
      return;
    }
    _prefixMaxWidth = 0;
    _prefixMaxLine = 0;
    if (fromLine > 0) {
      for (var line = 0; line < fromLine; line++) {
        for (final visual in visualLinesForDocumentLine(line)) {
          if (visual.width > _prefixMaxWidth) {
            _prefixMaxWidth = visual.width;
            _prefixMaxLine = line;
          }
        }
      }
      _maxWidthRescanFrom = fromLine;
    } else {
      _maxWidthRescanFrom = 0;
    }
    _cachedMaxWidth = null;
    _maxWidthLine = null;
  }

  /// Нижняя граница частичного пересчёта [maxLinePaintWidth].
  int? _maxWidthRescanFrom;

  /// Максимум ширины среди строк `[0, _maxWidthRescanFrom)` при частичной инвалидации.
  double _prefixMaxWidth = 0;
  int _prefixMaxLine = 0;

  /// Возвращает [AttributedRun] строки документа, используя кэш.
  ///
  /// Кэш инвалидируется в [invalidate] и [updateResolver]. Использует [resolver]
  /// для пересчёта при промахе.
  List<AttributedRun> attributedRunsForLine(int lineIndex) {
    final cached = _attributedCache[lineIndex];
    if (cached != null) return cached;
    final runs = _resolver.resolveLineRuns(document, lineIndex);
    _attributedCache[lineIndex] = runs;
    return runs;
  }

  /// Возвращает визуальные строки для [lineIndex], вычисляя и кэшируя при первом обращении.
  ///
  /// Без переноса создаёт одну [VisualLine] на строку документа. С [wrapWidth]
  /// разбивает строку на сегменты, укладывающиеся в заданную ширину.
  List<VisualLine> visualLinesForDocumentLine(int lineIndex) {
    final cached = _visualCache[lineIndex];
    if (cached != null) return cached;

    final runs = attributedRunsForLine(lineIndex);
    final fullText = _runsText(runs);
    final start = document.lineStart(lineIndex);

    if (wrapWidth == null || wrapWidth!.isInfinite || wrapWidth! <= 0) {
      final visual = VisualLine(
        documentStart: start,
        documentEnd: start + fullText.length,
        text: fullText,
        width: 0,
      );
      final width =
          inlayMetrics?.layoutX(lineIndex, visual, visual.documentEnd) ??
          glyphCache.measureText(fullText);
      final result = [visual.copyWith(width: width)];
      _visualCache[lineIndex] = result;
      return result;
    }

    final result = _wrapLine(fullText, start, wrapWidth!, lineIndex);
    _visualCache[lineIndex] = result;
    return result;
  }

  /// Высота одной строки документа в пикселях (`fontSize * lineHeightFactor`).
  double lineHeightPx(double lineHeightFactor) =>
      glyphCache.fontSize * lineHeightFactor;

  /// Самая широкая визуальная строка во всём документе (кэшируется до инвалидации).
  ///
  /// Наиболее точно, когда [wrapWidth] не задан (одна визуальная строка на строку документа).
  /// Перенесённые строки всё равно учитывают ширину каждого сегмента.
  double maxLinePaintWidth() {
    final cached = _cachedMaxWidth;
    if (cached != null) return cached;

    var maxW = _prefixMaxWidth;
    var maxLine = _prefixMaxLine;
    final startLine = _maxWidthRescanFrom ?? 0;
    for (var line = startLine; line < document.lineCount; line++) {
      for (final visual in visualLinesForDocumentLine(line)) {
        if (visual.width > maxW) {
          maxW = visual.width;
          maxLine = line;
        }
      }
    }
    _cachedMaxWidth = maxW;
    _maxWidthLine = maxLine;
    _maxWidthRescanFrom = null;
    return maxW;
  }

  /// Общая высота содержимого документа для [lineCount] строк.
  ///
  /// При отсутствии переноса возвращает `lineCount * lineH` без обращения к
  /// `_blockTops`. С переносом достраивает префикс-суммы лениво.
  double totalHeight(int lineCount, double lineHeightFactor) {
    if (lineCount <= 0) return 0;
    if (_hasUniformBlockHeight) {
      return lineCount * lineHeightPx(lineHeightFactor);
    }
    _ensureBlockTopsUpTo(lineCount, lineHeightFactor);
    return _blockTops[lineCount];
  }

  /// Высота блока строки документа (все визуальные строки) в пикселях.
  double blockHeightForLine(int lineIndex, double lineHeightFactor) {
    if (_hasUniformBlockHeight) return lineHeightPx(lineHeightFactor);
    _ensureBlockTopsUpTo(lineIndex + 1, lineHeightFactor);
    return _blockTops[lineIndex + 1] - _blockTops[lineIndex];
  }

  /// Строка документа, содержащая вертикальную координату [documentY] от верха содержимого.
  ///
  /// При отсутствии переноса — O(1) деление. Иначе использует префикс-суммы
  /// высот блоков (`O(log n)` бинарный поиск); при холодном кэше — лениво.
  int lineIndexForDocumentY(double documentY, double lineHeightFactor) {
    final lineCount = document.lineCount;
    if (lineCount == 0) return 0;
    if (_hasUniformBlockHeight) {
      if (documentY <= 0) return 0;
      final lineH = lineHeightPx(lineHeightFactor);
      final idx = (documentY / lineH).floor();
      return idx.clamp(0, lineCount - 1);
    }
    _ensureBlockTopsUpTo(lineCount, lineHeightFactor);
    if (documentY <= 0) return 0;
    final last = _blockTops[lineCount];
    if (documentY >= last) return lineCount - 1;
    // Ищем максимальный i (0 <= i < lineCount) такой, что _blockTops[i] <= documentY.
    var lo = 0;
    var hi = lineCount;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_blockTops[mid] <= documentY) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo.clamp(0, lineCount - 1);
  }

  /// Exclusive-индекс строки после [documentY] (для нижней границы viewport).
  int lineIndexAfterDocumentY(double documentY, double lineHeightFactor) {
    final lineCount = document.lineCount;
    if (lineCount == 0) return 0;
    if (_hasUniformBlockHeight) {
      if (documentY < 0) return 0;
      final lineH = lineHeightPx(lineHeightFactor);
      final idx = (documentY / lineH).floor() + 1;
      return idx.clamp(0, lineCount);
    }
    _ensureBlockTopsUpTo(lineCount, lineHeightFactor);
    if (documentY < 0) return 0;
    final last = _blockTops[lineCount];
    if (documentY >= last) return lineCount;
    // Ищем минимальный i (1 <= i <= lineCount) такой, что _blockTops[i] > documentY.
    var lo = 1;
    var hi = lineCount;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_blockTops[mid] > documentY) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  /// Сопоставляет точку `(x, localYInLine)` на [lineIndex] со смещением [TextOffset] в документе.
  ///
  /// Алгоритм:
  /// 1. Определить [VisualLine] по [localYInLine] или [affinity] при переносе.
  /// 2. Если визуальная строка пуста, вернуть [VisualLine.documentStart].
  /// 3. При наличии inlay делегировать в [InlayLayoutMetrics.offsetAtLayoutX].
  /// 4. Иначе [StyledRunLayout.offsetAtLayoutX] по тем же [TextPainter], что и отрисовка.
  ///
  /// **Граничные случаи:** Схлопнутая каретка на пустой строке возвращает начало строки.
  /// При нескольких визуальных строках и `null` в [localYInLine]
  /// [TextAffinity.downstream] выбирает последнюю визуальную строку; upstream — первую.
  TextOffset getOffsetAtPoint(
    int lineIndex,
    double x, {
    TextAffinity affinity = TextAffinity.downstream,
    double? localYInLine,
    double lineHeightFactor = 1.5,
  }) {
    final visuals = visualLinesForDocumentLine(lineIndex);
    var visualIndex = 0;
    if (visuals.length > 1) {
      if (localYInLine != null) {
        // Какая «подстрока» переноса под курсором по вертикали внутри логической строки.
        final lineH = lineHeightPx(lineHeightFactor);
        visualIndex = (localYInLine / lineH).floor();
        if (visualIndex >= visuals.length) {
          visualIndex = visuals.length - 1;
        }
        if (visualIndex < 0) visualIndex = 0;
      } else if (affinity == TextAffinity.downstream) {
        visualIndex = visuals.length - 1;
      }
    }
    final visual = visuals[visualIndex];
    final contentEnd = document.lineContentEnd(lineIndex);
    final contentLength = contentEnd - visual.documentStart;
    if (contentLength <= 0) {
      return visual.documentStart;
    }

    final metrics = inlayMetrics;
    if (metrics != null) {
      return metrics.offsetAtLayoutX(lineIndex, visual, x);
    }

    return _styledLayout.offsetAtLayoutX(lineIndex, visual, x);
  }

  /// Возвращает осевые [EditorBox], покрывающие [range] в координатах макета.
  ///
  /// Перебирает строки документа от начала до конца диапазона, затем каждую [VisualLine]
  /// на этих строках. Обрезает диапазон по каждому визуальному сегменту и преобразует
  /// границы смещений в X через [_xForOffsetInVisual].
  List<EditorBox> getBoxesForRange(Range range, double lineHeightFactor) {
    final boxes = <EditorBox>[];
    final startPos = document.positionAt(range.start);
    final endPos = document.positionAt(range.end);

    for (var line = startPos.line; line <= endPos.line; line++) {
      final visuals = visualLinesForDocumentLine(line);
      final lineH = lineHeightPx(lineHeightFactor);
      var y = _lineTopY(line, lineHeightFactor);

      for (final visual in visuals) {
        final selStart = range.start < visual.documentStart
            ? visual.documentStart
            : range.start;
        final selEnd = range.end > visual.documentEnd
            ? visual.documentEnd
            : range.end;
        if (selStart > selEnd) {
          y += lineH;
          continue;
        }

        final x1 = _xForOffsetInVisual(line, visual, selStart);
        final x2 = selStart == selEnd
            ? x1
            : _xForOffsetInVisual(line, visual, selEnd);
        boxes.add(EditorBox(left: x1, top: y, right: x2, bottom: y + lineH));
        y += lineH;
      }
    }
    return boxes;
  }

  /// Y-координата верха [lineIndex] (публичный API для painter'ов).
  ///
  /// При отсутствии переноса — `lineIndex * lineH` за O(1). Иначе — из
  /// префикс-суммы [_blockTops], которая лениво достраивается.
  double lineTopY(int lineIndex, double lineHeightFactor) =>
      _lineTopY(lineIndex, lineHeightFactor);

  /// Y-координата верха [lineIndex] из префикс-суммы.
  double _lineTopY(int lineIndex, double lineHeightFactor) {
    if (lineIndex <= 0) return 0;
    if (_hasUniformBlockHeight) {
      return lineIndex * lineHeightPx(lineHeightFactor);
    }
    _ensureBlockTopsUpTo(lineIndex, lineHeightFactor);
    return _blockTops[lineIndex];
  }

  /// Дозаполняет [_blockTops] до элемента с индексом [upToInclusive] включительно
  /// (то есть для всех строк `< upToInclusive`).
  void _ensureBlockTopsUpTo(int upToInclusive, double lineHeightFactor) {
    final lineH = lineHeightPx(lineHeightFactor);
    if (_blockTopsLineHeight != lineH) {
      _blockTops
        ..clear()
        ..add(0);
      _blockTopsLineHeight = lineH;
    }
    while (_blockTops.length <= upToInclusive) {
      final line = _blockTops.length - 1;
      final blockH = lineH * visualLinesForDocumentLine(line).length;
      _blockTops.add(_blockTops.last + blockH);
    }
  }

  /// Горизонтальная X-позиция [offset] внутри одной [VisualLine] (с inlay или без).
  double _xForOffsetInVisual(
    int lineIndex,
    VisualLine visual,
    TextOffset offset,
  ) {
    final metrics = inlayMetrics;
    if (metrics != null) {
      return metrics.layoutX(lineIndex, visual, offset);
    }
    return _styledLayout.layoutX(lineIndex, visual, offset);
  }

  /// Склеивает текст всех [AttributedRun] строки для переноса и измерения.
  String _runsText(List<AttributedRun> runs) {
    final buffer = StringBuffer();
    for (final run in runs) {
      buffer.write(run.text);
    }
    return buffer.toString();
  }

  /// Переносит [text], начиная со смещения документа [start], в сегменты [VisualLine].
  ///
  /// Использует ширину с учётом inlay, когда [inlayMetrics] не равен null; иначе
  /// [_wrapLinePlain]. Пустой текст даёт одну визуальную строку нулевой ширины.
  List<VisualLine> _wrapLine(
    String text,
    int start,
    double maxWidth,
    int lineIndex,
  ) {
    if (text.isEmpty) {
      return [
        VisualLine(
          documentStart: start,
          documentEnd: start,
          text: '',
          width: 0,
        ),
      ];
    }

    final metrics = inlayMetrics;
    if (metrics == null) {
      return _wrapLinePlain(text, start, maxWidth);
    }

    final result = <VisualLine>[];
    var segStart = 0;

    for (var i = 0; i < text.length; i++) {
      final seg = sliceCodeUnits(text, segStart, i + 1);
      final visual = VisualLine(
        documentStart: start + segStart,
        documentEnd: start + i + 1,
        text: seg,
        width: 0,
      );
      final w = metrics.layoutX(lineIndex, visual, visual.documentEnd);
      if (w > maxWidth && i > segStart) {
        final lineText = sliceCodeUnits(text, segStart, i);
        final lineVisual = VisualLine(
          documentStart: start + segStart,
          documentEnd: start + i,
          text: lineText,
          width: 0,
        );
        result.add(
          lineVisual.copyWith(
            width: metrics.layoutX(
              lineIndex,
              lineVisual,
              lineVisual.documentEnd,
            ),
          ),
        );
        segStart = i;
      }
    }

    final tail = sliceCodeUnits(text, segStart, text.length);
    final tailVisual = VisualLine(
      documentStart: start + segStart,
      documentEnd: start + text.length,
      text: tail,
      width: 0,
    );
    result.add(
      tailVisual.copyWith(
        width: metrics.layoutX(lineIndex, tailVisual, tailVisual.documentEnd),
      ),
    );
    return result;
  }

  /// Жадный перенос по ширине символов без учёта inlay.
  ///
  /// Разрывает перед code unit [i], если его добавление превысит [maxWidth] и
  /// сегмент не пуст.
  List<VisualLine> _wrapLinePlain(String text, int start, double maxWidth) {
    final result = <VisualLine>[];
    var segStart = 0;
    var width = 0.0;

    for (var i = 0; i < text.length; i++) {
      final cw = glyphCache.charWidth(text.codeUnitAt(i));
      if (width + cw > maxWidth && i > segStart) {
        final seg = sliceCodeUnits(text, segStart, i);
        result.add(
          VisualLine(
            documentStart: start + segStart,
            documentEnd: start + i,
            text: seg,
            width: width,
          ),
        );
        segStart = i;
        width = cw;
      } else {
        width += cw;
      }
    }

    final tail = sliceCodeUnits(text, segStart, text.length);
    result.add(
      VisualLine(
        documentStart: start + segStart,
        documentEnd: start + text.length,
        text: tail,
        width: glyphCache.measureText(tail),
      ),
    );
    return result;
  }
}
