import 'package:editor/editor.dart';
import 'package:example/lsp/dart_lsp_client.dart';
import 'package:example/lsp/lsp_location.dart';
import 'package:example/lsp/lsp_position.dart';

/// [EditorLanguageService] backed by `dart language-server`.
final class DartLanguageService
    implements EditorLanguageService, EditorOverlayLanguageService {
  DartLanguageService(this._client);

  final DartLspClient _client;

  @override
  Future<List<HighlightSpan>> documentHighlights({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) async {
    final items = await _client.documentHighlights(
      text,
      lspPositionAt(text, offset),
    );
    return [
      for (final range in items)
        HighlightSpan(range: range, kind: HighlightKind.occurrence),
    ];
  }

  @override
  Future<List<HighlightSpan>> linkedEditingHighlights({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) async {
    final ranges = await _client.linkedEditingRanges(
      text,
      lspPositionAt(text, offset),
    );
    if (ranges == null) return const [];
    return [
      for (final range in ranges)
        HighlightSpan(range: range, kind: HighlightKind.linkedEditing),
    ];
  }

  @override
  Future<List<EditorInlayHint>> inlayHints({
    required String text,
    required int documentVersion,
    required Range range,
  }) => _client.requestInlayHints(text, range);

  @override
  Future<EditorLinkTarget?> linkTargetAt({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) async {
    final links = await _client.documentLinks(text);
    final fromLink = documentLinkTargetFromLsp(
      links,
      text,
      offset,
      fallbackDocumentUri: _client.documentUri,
    );
    if (fromLink != null) return fromLink;

    final definition = await _client.definition(
      text,
      lspPositionAt(text, offset),
    );
    if (definition == null) return null;

    final highlight = wordRangeAt(text, offset) ?? Range(offset, offset + 1);
    return EditorLinkTarget(highlightRange: highlight, destination: definition);
  }

  @override
  Future<EditorCompletionList?> completions({
    required String text,
    required int documentVersion,
    required TextOffset offset,
    EditorCompletionTrigger trigger = EditorCompletionTrigger.invoked,
    String? triggerCharacter,
  }) => _client.completion(
    text,
    lspPositionAt(text, offset),
    trigger: trigger,
    triggerCharacter: triggerCharacter,
  );

  @override
  Future<EditorCompletionItem?> resolveCompletionItem({
    required String text,
    required int documentVersion,
    required EditorCompletionItem item,
  }) => _client.resolveCompletionItem(text, item);

  @override
  Future<EditorHover?> hover({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) => _client.hover(text, lspPositionAt(text, offset));

  @override
  Future<EditorSignatureHelp?> signatureHelp({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) => _client.signatureHelp(text, lspPositionAt(text, offset));
}
