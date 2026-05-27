import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/style_span.dart';

/// Подключаемый источник стилей (синтаксис, декорации, временные подсветки и т. д.).
///
/// Реализации возвращают [StyleSpan], пересекающиеся с запрошенным [Range].
/// [StyleResolver] объединяет все слои по приоритету на границах сегментов.
///
/// ```dart
/// final layers = <StyleLayer>[
///   BaseStyleLayer(theme),
///   SyntaxStyleLayer(spans: tokens),
///   DecorationStyleLayer(spans: searchHits),
/// ];
/// ```
abstract interface class StyleLayer {
  /// Стабильный идентификатор для отладки и ключей кэша.
  String get id;

  /// Версия документа, для которой построен этот слой, или `null`, если всегда актуален.
  int? get validForDocumentVersion;

  /// Стилевые span'ы, пересекающиеся с [range] (могут обрезаться по диапазону).
  Iterable<StyleSpan> spansForRange(Range range);
}
