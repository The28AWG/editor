import 'package:editor/src/highlight/highlight_span.dart';
import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/navigation/editor_document_location.dart';

/// Необязательный бэкенд языковой аналитики (LSP-клиент, анализатор, пользовательский парсер).
///
/// При подключении через [EditorController.setLanguageService] контроллер
/// автоматически запрашивает:
///
/// - **Document highlights** — маркеры вхождений символа под кареткой.
/// - **Linked editing** — парные диапазоны тегов/идентификаторов (синхронизация переименования HTML/XML).
/// - **Inlay hints** — виртуальные аннотации типов/параметров после правок.
/// - **Link targets** — цели Ctrl+клик (`definition`, `documentLink`).
///
/// Все методы асинхронны; контроллер использует счётчики поколений, чтобы отбрасывать
/// устаревшие ответы, если версия документа или позиция каретки изменились до завершения.
///
/// ## Соответствие LSP
///
/// | Метод | LSP-запрос |
/// |---|---|
/// | [documentHighlights] | `textDocument/documentHighlight` |
/// | [linkedEditingHighlights] | `textDocument/linkedEditingRange` |
/// | [inlayHints] | `textDocument/inlayHint` |
/// | [linkTargetAt] | `textDocument/definition`, `textDocument/documentLink` |
///
/// Overlay (completion, hover, signature): [EditorOverlayLanguageService].
///
/// ## Пример
///
/// ```dart
/// class MyLspService implements EditorLanguageService {
///   @override
///   Future<List<HighlightSpan>> documentHighlights({
///     required String text,
///     required int documentVersion,
///     required TextOffset offset,
///   }) async {
///     final result = await lsp.documentHighlight(uri, offset);
///     return result.map(toHighlightSpan).toList();
///   }
///
///   // ... linkedEditingHighlights, inlayHints
/// }
/// ```
abstract class EditorLanguageService {
  /// Возвращает подсветку вхождений символа в [offset].
  ///
  /// Соответствует LSP `textDocument/documentHighlight`. Результаты объединяются
  /// с подсветкой скобок и необязательным fallback по границам слова внутри
  /// [EditorController._refreshCaretHighlights].
  ///
  /// Возвращает пустой список, если символ не найден или запрос завершился ошибкой.
  ///
  /// [text] и [documentVersion] должны соответствовать текущему документу контроллера
  /// на момент запроса; устаревшие ответы отбрасываются контроллером.
  Future<List<HighlightSpan>> documentHighlights({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  });

  /// Возвращает диапазоны связанного редактирования для идентификатора в [offset].
  ///
  /// Соответствует LSP `textDocument/linkedEditingRange`. Используется для синхронного
  /// редактирования парных конструкций (например, HTML-тегов). Диапазоны обычно
  /// отображаются с [HighlightKind.linkedEditing].
  ///
  /// Возвращает пустой список, если связанное редактирование недоступно в [offset].
  Future<List<HighlightSpan>> linkedEditingHighlights({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  });

  /// Возвращает inlay hints, якоря которых попадают в [range].
  ///
  /// Соответствует LSP `textDocument/inlayHint`. Вызывается с debounce (300 мс) после
  /// правок документа и сразу при первом подключении сервиса.
  ///
  /// [range] — видимое scroll-окно (и при необходимости полоса каретки вне экрана),
  /// как у [ViewportStyleScope]. Hints — виртуальный текст; буфер не меняют.
  Future<List<EditorInlayHint>> inlayHints({
    required String text,
    required int documentVersion,
    required Range range,
  });

  /// Возвращает цель навигации под [offset] для Ctrl+hover / Ctrl+клик.
  ///
  /// Соответствует LSP `textDocument/definition` и `textDocument/documentLink`.
  /// Реализация обычно подчёркивает [EditorLinkTarget.highlightRange] (слово или
  /// диапазон ссылки) и задаёт [EditorLinkTarget.destination].
  ///
  /// Возвращает `null`, если переход недоступен.
  Future<EditorLinkTarget?> linkTargetAt({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  });
}
