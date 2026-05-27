/// Видимый диапазон строк документа и состояние вертикальной/горизонтальной прокрутки.
///
/// Отслеживает, какие строки документа на экране, насколько прокручен viewport
/// и сколько дополнительных строк рисовать сверху/снизу для плавной прокрутки
/// ([overscanLines]).
///
/// ```dart
/// final vp = ViewportState(
///   viewportHeight: 400,
///   viewportWidth: 800,
///   scrollOffset: 120,
/// );
/// final last = vp.lastVisibleLine(doc.lineCount, lineHeightPx);
/// vp.ensureOffsetVisible(caretY, lineHeightPx, padding: 8);
/// ```
final class ViewportState {
  /// Создаёт состояние viewport с опциональной позицией прокрутки и размерами.
  ViewportState({
    this.firstVisibleLine = 0,
    this.scrollOffset = 0,
    this.scrollOffsetX = 0,
    this.viewportHeight = 0,
    this.viewportWidth = 0,
    this.overscanLines = 3,
  });

  /// Индекс первой строки документа, пересекающей viewport (выводится из [scrollOffset]).
  int firstVisibleLine;

  /// Вертикальное смещение прокрутки в пикселях от верха содержимого документа.
  double scrollOffset;

  /// Горизонтальное смещение прокрутки в пикселях (для широких строк).
  double scrollOffsetX;

  /// Высота viewport в логических пикселях.
  double viewportHeight;

  /// Ширина viewport в логических пикселях.
  double viewportWidth;

  /// Дополнительные строки, рисуемые выше и ниже видимого диапазона для снижения мерцания.
  final int overscanLines;

  /// Индекс последней строки документа (исключая), которую нужно разметить или отрисовать.
  ///
  /// Алгоритм:
  /// 1. Если [lineHeightPx] `<= 0`, возвращает [firstVisibleLine] без изменений.
  /// 2. Вычисляет число видимых строк как `ceil(viewportHeight / lineHeightPx) + overscanLines`.
  /// 3. Ограничивает значением [lineCount].
  ///
  /// Возвращает [firstVisibleLine], когда [lineHeightPx] неположителен.
  int lastVisibleLine(int lineCount, double lineHeightPx) {
    if (lineHeightPx <= 0) return firstVisibleLine;
    final visibleCount = (viewportHeight / lineHeightPx).ceil() + overscanLines;
    final last = firstVisibleLine + visibleCount;
    return last > lineCount ? lineCount : last;
  }

  /// Ограничивает [scrollOffset], когда [contentHeight] меньше, чем до правки.
  ///
  /// После undo/redo или удаления большого фрагмента [ScrollController] уже
  /// может быть зажат до [maxScrollExtent], а [scrollOffset] ещё указывает
  /// на старую позицию — painter клипирует текст по [scrollOffset], и видны
  /// только прямоугольники выделения (они рисуются без clip).
  void clampScrollOffsetToContentHeight(
    double contentHeight, {
    required double lineHeightPx,
  }) {
    final maxScroll = contentHeight <= viewportHeight
        ? 0.0
        : contentHeight - viewportHeight;
    var next = scrollOffset;
    if (next > maxScroll) next = maxScroll;
    if (next < 0) next = 0;
    if (next == scrollOffset) return;
    scrollOffset = next;
    firstVisibleLine = lineHeightPx > 0
        ? (scrollOffset / lineHeightPx).floor()
        : 0;
  }

  /// Корректирует [scrollOffset], чтобы строка на [offsetY] оставалась в viewport.
  ///
  /// Алгоритм:
  /// 1. Если верх строки выше видимой области (минус [padding]), прокрутить вверх.
  /// 2. Если низ строки ниже видимой области (минус [padding]), прокрутить вниз.
  /// 3. Ограничить [scrollOffset] значением `>= 0`.
  /// 4. Пересчитать [firstVisibleLine] из [scrollOffset] и [lineHeightPx].
  ///
  /// [offsetY] — layout Y верха строки; [lineHeightPx] — высота одной строки.
  void ensureOffsetVisible(
    double offsetY,
    double lineHeightPx, {
    double padding = 0,
  }) {
    if (offsetY < scrollOffset + padding) {
      scrollOffset = offsetY - padding;
      if (scrollOffset < 0) scrollOffset = 0;
    } else if (offsetY + lineHeightPx >
        scrollOffset + viewportHeight - padding) {
      scrollOffset = offsetY + lineHeightPx - viewportHeight + padding;
      if (scrollOffset < 0) scrollOffset = 0;
    }
    firstVisibleLine = (scrollOffset / lineHeightPx).floor();
  }

  /// Фрагмент ключа кэша для инвалидации макета.
  ///
  /// Объединяет версии документа/стилей, диапазон строк, размер viewport и
  /// [scrollOffset], чтобы кэшированные данные отрисовки можно было переиспользовать или отбросить.
  String layoutCacheKey({
    required int documentVersion,
    required int styleEpoch,
    required int lineStart,
    required int lineEnd,
  }) =>
      '$documentVersion:$styleEpoch:$lineStart:$lineEnd:'
      '${viewportWidth}x$viewportHeight@$scrollOffset';
}
