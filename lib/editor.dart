/// Текстовый редактор на Flutter с подсветкой синтаксиса, диагностикой и интеграцией LSP.
///
/// Эта библиотека предоставляет публичный API для встраивания редактора кода во Flutter-
/// приложения. Основные точки входа:
///
/// - [EditorController] — состояние документа, выделения, undo/redo и стилизации.
/// - [EditorView] — встраиваемый виджет, отрисовывающий поверхность редактора.
/// - [EditorActionConfiguration] / [EditorMenuConfiguration] — клавиши, контекстное меню, кастомные действия.
/// - [EditorHost] — необязательные колбэки для стилевых слоёв и уведомлений об изменениях.
/// - [EditorLanguageService] — необязательные хуки LSP/анализатора для подсветки и inlay.
///
/// ## Быстрый старт
///
/// ```dart
/// final controller = EditorController(initialText: 'void main() {}');
/// controller.setDiagnostics([
///   EditorDiagnostic(
///     range: Range(0, 4),
///     message: 'Unexpected token',
///     severity: DiagnosticSeverity.error,
///   ),
/// ]);
///
/// EditorView(controller: controller, showGutter: true);
/// ```
///
/// ## Архитектура
///
/// Редактор разделяет обязанности по слоям:
///
/// - **Model** — [Document], [TextEdit], [SelectionState].
/// - **Editing** — [Transaction] и реестр команд (не экспортируются напрямую).
/// - **Styling** — [StyleResolver] объединяет тему, синтаксис, диагностику и подсветку.
/// - **View** — [EditorScrollable] отвечает за layout, отрисовку, прокрутку и ввод.
///
/// Хост-приложения обычно подключают [EditorHost] для асинхронной токенизации и
/// [EditorLanguageService] для возможностей LSP (подсветка документа, inlay hints).
library;

export 'src/api/editor_action.dart';
export 'src/api/editor_action_localizations.dart';
export 'src/api/editor_controller.dart';
export 'src/api/editor_host.dart';
export 'src/api/editor_language_service.dart';
export 'src/api/editor_menu.dart';
export 'src/api/editor_overlay.dart';
export 'src/api/editor_overlay_language_service.dart';
export 'src/api/selection_change.dart';
export 'src/decorations/editor_region_block.dart';
export 'src/diagnostics/diagnostic_decorations.dart';
export 'src/diagnostics/editor_diagnostic.dart';
export 'src/diagnostics/inline_diagnostic_label.dart';
export 'src/highlight/bracket_matcher.dart';
export 'src/highlight/caret_highlights.dart';
export 'src/highlight/highlight_kind.dart';
export 'src/highlight/highlight_span.dart';
export 'src/highlight/highlight_viewport.dart';
export 'src/highlight/word_bounds.dart';
export 'src/inlay/editor_inlay_hint.dart';
export 'src/inlay/inlay_hint_style.dart';
export 'src/inlay/inlay_layout_metrics.dart';
export 'src/language/editor_completion.dart';
export 'src/language/editor_hover.dart';
export 'src/language/editor_signature_help.dart';
export 'src/layout/line_text_metrics.dart';
export 'src/layout/viewport.dart' show ViewportState;
export 'src/model/document.dart';
export 'src/model/document_change.dart';
export 'src/model/position.dart' show Position, Range, TextAffinity, TextOffset;
export 'src/model/text_edit.dart';
export 'src/navigation/editor_document_location.dart';
export 'src/navigation/url_link.dart' show isWebNavigationUri, urlRangeAt;
export 'src/selection/selection.dart';
export 'src/styling/editor_caret_theme.dart';
export 'src/styling/editor_theme.dart';
export 'src/styling/layers/decoration_style_layer.dart';
export 'src/styling/layers/pending_shifted_syntax_layer.dart';
export 'src/styling/layers/syntax_style_layer.dart';
export 'src/styling/sorted_style_spans.dart';
export 'src/styling/style_layer.dart';
export 'src/styling/style_resolver.dart';
export 'src/styling/style_span.dart';
export 'src/styling/style_span_mask.dart';
export 'src/styling/viewport_style_scope.dart';
export 'src/view/editor_view.dart';
export 'src/view/inlay/inlay_hint.dart';
