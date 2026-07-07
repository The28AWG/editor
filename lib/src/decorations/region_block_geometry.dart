import 'package:editor/src/decorations/editor_region_block.dart';
import 'package:editor/src/model/position.dart' show Range;
import 'package:flutter/painting.dart';

/// Геометрия блоков-рамок для отладки и тестов (без Canvas).
///
/// Этот модуль выделен специально, чтобы можно было писать unit-тесты на
/// «пересечения рамок» и воспроизводить кейсы без запуска Flutter-приложения.
final class RegionBlockGeometry {
  const RegionBlockGeometry._();

  static const double defaultGapPx = 2.0;

  /// Возвращает `true`, если сегменты разных блоков пересекаются
  /// одновременно по X и по Y (то есть визуально накладываются).
  static bool hasOverlaps(List<RegionBlockRects> blocks, {double eps = 0.01}) {
    final segs = _collectSegments(blocks);
    for (var i = 0; i < segs.length; i++) {
      for (var j = i + 1; j < segs.length; j++) {
        if (identical(segs[i].owner, segs[j].owner)) continue;
        if (_rectsOverlap(segs[i].rect, segs[j].rect, eps: eps)) return true;
      }
    }
    return false;
  }

  /// Разводит сегменты, чтобы сегменты разных блоков не накладывались.
  ///
  /// Конфликтом считается любая пара сегментов разных блоков с пересечением
  /// и по X, и по Y — без требования одинаковой высоты строк (разный
  /// [EditorRegionBlock.padding] даёт разные top/bottom). Функция **не
  /// сдвигает** сегменты, а только **сужает**: у более левого сегмента
  /// обрезается правая грань до `left - gapPx` правого соседа.
  static void avoidOverlaps(
    List<RegionBlockRects> blocks, {
    double gapPx = defaultGapPx,
    double eps = 0.01,
  }) {
    final segs = _collectSegments(blocks)
      // Слева направо: более левый сегмент уступает место правому.
      ..sort((a, b) => a.rect.left.compareTo(b.rect.left));

    for (var i = 0; i < segs.length; i++) {
      for (var j = i + 1; j < segs.length; j++) {
        final a = segs[i];
        final b = segs[j];
        if (identical(a.owner, b.owner)) continue;
        // Вложенные блоки НЕ разводим: внешний должен оставаться целым,
        // а внутренний просто рисуется поверх.
        if (_isNested(a.owner.block.range, b.owner.block.range)) continue;
        final ra = a.rect;
        final rb = b.rect;
        if (!_rectsOverlap(ra, rb, eps: eps)) continue;

        final maxRight = rb.left - gapPx;
        a.setRect(Rect.fromLTRB(ra.left, ra.top, maxRight, ra.bottom));
      }
    }

    // Удаляем вырожденные сегменты (места не осталось).
    for (final b in blocks) {
      b.rects.removeWhere(
        (r) => r.right <= r.left + 1 || r.bottom <= r.top + 1,
      );
    }
  }

  /// Нормализует прямоугольники в «видимую границу» для рамки:
  /// возвращает копию, пригодную для дальнейшей обработки.
  static List<Rect> normalizeRectsForTheme(
    List<Rect> rects, {
    required double paddingX,
    required double paddingY,
  }) {
    final out = <Rect>[];
    for (final r in rects) {
      final rr = Rect.fromLTRB(
        r.left - paddingX,
        r.top + paddingY,
        r.right + paddingX,
        r.bottom - paddingY,
      );
      // Защита от вырождения по высоте.
      if (rr.bottom <= rr.top + 1) {
        out.add(Rect.fromLTRB(rr.left, r.top, rr.right, r.bottom));
      } else {
        out.add(rr);
      }
    }
    return out;
  }

  static bool _rectsOverlap(Rect a, Rect b, {required double eps}) =>
      a.right > b.left + eps &&
      b.right > a.left + eps &&
      a.bottom > b.top + eps &&
      b.bottom > a.top + eps;

  static bool _isNested(Range a, Range b) {
    // true, если один диапазон полностью содержит другой
    final aContainsB = a.start <= b.start && a.end >= b.end;
    final bContainsA = b.start <= a.start && b.end >= a.end;
    return aContainsB || bContainsA;
  }

  static List<_SegRef> _collectSegments(List<RegionBlockRects> blocks) {
    final segs = <_SegRef>[];
    for (final block in blocks) {
      for (var ri = 0; ri < block.rects.length; ri++) {
        segs.add(_SegRef(block, ri));
      }
    }
    return segs;
  }
}

/// Прямоугольники одного блока по визуальным строкам.
final class RegionBlockRects {
  RegionBlockRects({required this.block, required List<Rect> rects})
    : rects = List<Rect>.of(rects);

  final EditorRegionBlock block;
  final List<Rect> rects;
}

final class _SegRef {
  _SegRef(this.owner, this.rectIndex);

  final RegionBlockRects owner;
  final int rectIndex;

  Rect get rect => owner.rects[rectIndex];

  void setRect(Rect value) => owner.rects[rectIndex] = value;
}
