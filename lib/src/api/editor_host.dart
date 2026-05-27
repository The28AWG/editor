import 'package:editor/src/api/selection_change.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/navigation/editor_document_location.dart';
import 'package:editor/src/styling/style_layer.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';

/// Точка интеграции для хост-приложений (оболочка IDE, LSP-клиент, плагин).
///
/// Реализуйте или подмешайте этот класс, чтобы предоставлять асинхронные стилевые слои
/// (например, синтаксические токены с LSP-сервера) и реагировать на изменения документа/выделения.
///
/// Подключается через [EditorController.setHost] или параметр конструктора [EditorView.host].
/// Стилевые слои пересобираются при каждом изменении версии документа
/// или при вызове [EditorController.refreshStyleLayers].
///
/// ## Стилевые слои
///
/// Возвращайте один или несколько экземпляров [StyleLayer] из [styleLayersFor]. Слои
/// объединяются с базовой темой, декорациями диагностики и временной подсветкой
/// во внутреннем [StyleResolver] [EditorController].
///
/// ## Пример
///
/// ```dart
/// class LspHost with EditorHost {
///   LspHost(this.tokens);
///
///   final List<StyleSpan> tokens;
///
///   @override
///   List<StyleLayer> styleLayersFor(int documentVersion) => [
///     SyntaxStyleLayer(documentVersion: documentVersion, spans: tokens),
///   ];
///
///   @override
///   void onDocumentChanged(DocumentChange change) {
///     requestSemanticTokens(change.newVersion);
///   }
/// }
/// ```
abstract mixin class EditorHost {
  /// Возвращает стилевые слои, действительные для указанной [documentVersion].
  ///
  /// Версия должна совпадать с [Document.version] на момент отрисовки; устаревшие слои
  /// игнорируются resolver'ом при расхождении версий.
  ///
  /// Вызывается из [EditorController._afterChange] до [_rebuildResolver] на каждой правке,
  /// а также может вызываться косвенно при явном [EditorController.refreshStyleLayers].
  List<StyleLayer> styleLayersFor(
    int documentVersion, {
    ViewportStyleScope? viewport,
  });

  /// Вызывается после изменения буфера документа.
  ///
  /// Реализация по умолчанию — no-op. Переопределите, чтобы запускать повторную токенизацию,
  /// флаги «грязного» состояния или передавать правки в LSP `textDocument/didChange`.
  ///
  /// [change] описывает применённые правки и новую версию документа.
  void onDocumentChanged(DocumentChange change) {
    return;
  }

  /// Вызывается при изменении кареток или диапазонов выделения.
  ///
  /// Реализация по умолчанию — no-op. Переопределите, чтобы обновлять UI статуса или
  /// запрашивать возможности LSP, привязанные к позиции курсора (например, hover, signature help).
  void onSelectionChanged(SelectionChange change) {
    return;
  }

  /// URI документа, открытого в этом редакторе (для сравнения с LSP `Location.uri`).
  ///
  /// Если `null`, навигация внутри того же файла по [onNavigate] не выполняется автоматически.
  String? get editorDocumentUri => null;

  /// Ctrl+клик по ссылке: открыть другой файл, перейти к определению и т.д.
  void onNavigate(EditorDocumentLocation location) {
    return;
  }
}
