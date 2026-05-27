import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/sorted_style_spans.dart';
import 'package:editor/src/styling/style_layer.dart';
import 'package:editor/src/styling/style_span.dart';

/// Постоянные подсветки хоста (поиск, диагностика, выделения и т. д.).
///
/// То же поведение обрезки, что у [SyntaxStyleLayer], но [layerPriority]
/// по умолчанию `100`, размещая декорации поверх синтаксиса и базовой темы.
///
/// ```dart
/// DecorationStyleLayer(
///   spans: [
///     StyleSpan(range: searchHit, backgroundColor: Colors.yellow.withAlpha(80)),
///   ],
/// )
/// ```
final class DecorationStyleLayer implements StyleLayer {
  /// Создаёт слой декораций из span'ов подсветки хоста.
  DecorationStyleLayer({
    required List<StyleSpan> spans,
    this.documentVersion,
    this.layerPriority = 100,
  }) : _sortedSpans = sortedStyleSpans(spans);

  /// Span'ы декораций (поиск, диагностика, diff и т. д.).
  List<StyleSpan> get spans => _sortedSpans;

  final List<StyleSpan> _sortedSpans;

  /// Версия документа, для которой вычислены эти декорации.
  final int? documentVersion;

  /// Приоритет, присваиваемый каждому возвращаемому span'у.
  final int layerPriority;

  @override
  String get id => 'decoration';

  @override
  int? get validForDocumentVersion => documentVersion;

  @override
  Iterable<StyleSpan> spansForRange(Range range) =>
      spansForSortedRange(_sortedSpans, range, layerPriority);
}
