import 'package:editor/src/language/editor_completion.dart';
import 'package:editor/src/language/editor_hover.dart';
import 'package:editor/src/language/editor_signature_help.dart';
import 'package:editor/src/model/position.dart';

/// Расширение [EditorLanguageService] для overlay: completion, hover, signature.
///
/// Реализуйте вместе с [EditorLanguageService], если хост показывает LSP overlay.
abstract mixin class EditorOverlayLanguageService {
  /// Список completion у [offset] (LSP `textDocument/completion`).
  Future<EditorCompletionList?> completions({
    required String text,
    required int documentVersion,
    required TextOffset offset,
    EditorCompletionTrigger trigger = EditorCompletionTrigger.invoked,
    String? triggerCharacter,
  });

  /// Дозагрузка documentation (LSP `completionItem/resolve`).
  Future<EditorCompletionItem?> resolveCompletionItem({
    required String text,
    required int documentVersion,
    required EditorCompletionItem item,
  });

  /// Hover tooltip (LSP `textDocument/hover`).
  Future<EditorHover?> hover({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  });

  /// Signature help (LSP `textDocument/signatureHelp`).
  Future<EditorSignatureHelp?> signatureHelp({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  });
}
