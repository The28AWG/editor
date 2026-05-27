import 'package:editor/src/model/position.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/style_layer.dart';
import 'package:editor/src/styling/style_span.dart';

/// Значения темы с наименьшим приоритетом.
///
/// Выдаёт один span, покрывающий запрошенный [Range], с [EditorTheme.defaultColor]
/// и приоритетом `0`. Должен быть первым слоем в стеке [StyleResolver].
///
/// ```dart
/// StyleResolver(theme: theme, layers: [BaseStyleLayer(theme), ...]);
/// ```
final class BaseStyleLayer implements StyleLayer {
  /// Создаёт базовый слой, привязанный к [theme] и опциональной [documentVersion].
  BaseStyleLayer(this.theme, {this.documentVersion});

  /// Тема, предоставляющая [EditorTheme.defaultColor].
  final EditorTheme theme;

  /// Метка версии документа для проверки кэша.
  final int? documentVersion;

  @override
  String get id => 'base';

  @override
  int? get validForDocumentVersion => documentVersion;

  @override
  Iterable<StyleSpan> spansForRange(Range range) sync* {
    yield StyleSpan(range: range, color: theme.defaultColor, priority: 0);
  }
}
