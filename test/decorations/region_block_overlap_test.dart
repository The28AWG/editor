import 'package:editor/src/decorations/editor_region_block.dart';
import 'package:editor/src/decorations/region_block_geometry.dart';
import 'package:editor/src/model/position.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RegionBlockGeometry.avoidOverlaps removes X overlaps per line', () {
    const b1 = EditorRegionBlock(
      range: Range(0, 10),
      borderColor: Color(0xFF000000),
      fillColor: Color(0x22000000),
    );
    const b2 = EditorRegionBlock(
      range: Range(20, 30),
      borderColor: Color(0xFF000000),
      fillColor: Color(0x22000000),
    );

    // Оба блока на одной визуальной строке, и изначально пересекаются по X.
    final blocks = <RegionBlockRects>[
      RegionBlockRects(
        block: b1,
        rects: [const Rect.fromLTRB(10, 100, 80, 120)],
      ),
      RegionBlockRects(
        block: b2,
        rects: [const Rect.fromLTRB(60, 100, 110, 120)],
      ),
    ];

    expect(RegionBlockGeometry.hasOverlaps(blocks), isTrue);
    RegionBlockGeometry.avoidOverlaps(blocks, gapPx: 2);
    expect(RegionBlockGeometry.hasOverlaps(blocks), isFalse);
  });

  test('RegionBlockGeometry groups lines by midY/height (padding-safe)', () {
    const b1 = EditorRegionBlock(
      range: Range(0, 10),
      borderColor: Color(0xFF000000),
    );
    const b2 = EditorRegionBlock(
      range: Range(20, 30),
      borderColor: Color(0xFF000000),
    );

    // Два сегмента на одной и той же визуальной строке, но разный padding
    // сдвигает top/bottom. midY/height должны совпасть => попадут в одну группу.
    final r1 = const Rect.fromLTRB(10, 100, 70, 120);
    final r2 = const Rect.fromLTRB(
      60,
      96,
      120,
      124,
    ); // тот же midY=110, height=28

    final blocks = <RegionBlockRects>[
      RegionBlockRects(block: b1, rects: [r1]),
      RegionBlockRects(block: b2, rects: [r2]),
    ];

    expect(RegionBlockGeometry.hasOverlaps(blocks), isTrue);
    RegionBlockGeometry.avoidOverlaps(blocks, gapPx: 2);
    expect(RegionBlockGeometry.hasOverlaps(blocks), isFalse);
  });

  test('RegionBlockGeometry does not cut nested blocks', () {
    const outer = EditorRegionBlock(
      range: Range(0, 100),
      borderColor: Color(0xFF000000),
      fillColor: Color(0x22000000),
    );
    const inner = EditorRegionBlock(
      range: Range(10, 20),
      borderColor: Color(0xFF000000),
      fillColor: Color(0x22000000),
    );

    // На одной строке: inner лежит внутри outer и пересекается по X/Y.
    final blocks = <RegionBlockRects>[
      RegionBlockRects(
        block: outer,
        rects: [const Rect.fromLTRB(10, 100, 140, 120)],
      ),
      RegionBlockRects(
        block: inner,
        rects: [const Rect.fromLTRB(60, 100, 110, 120)],
      ),
    ];

    RegionBlockGeometry.avoidOverlaps(blocks, gapPx: 2);
    // Вложенные блоки не режем — пересечение остаётся (inner поверх outer).
    expect(RegionBlockGeometry.hasOverlaps(blocks), isTrue);
  });
}
