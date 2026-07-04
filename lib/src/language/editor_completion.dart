import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_edit.dart';

/// Причина запроса completion (LSP `CompletionTriggerKind`).
enum EditorCompletionTrigger { invoked, triggerCharacter, incomplete }

/// Один пункт списка completion.
final class EditorCompletionItem {
  const EditorCompletionItem({
    required this.label,
    this.detail,
    this.documentation,
    this.insertText,
    this.textEdit,
    this.filterText,
    this.sortText,
    this.needsResolve = false,
    this.resolveToken,
  });

  final String label;
  final String? detail;
  final String? documentation;
  final String? insertText;
  final TextEdit? textEdit;
  final String? filterText;
  final String? sortText;
  final bool needsResolve;

  /// Непрозрачный ключ для [EditorLanguageService.resolveCompletionItem].
  final String? resolveToken;

  EditorCompletionItem copyWith({
    String? label,
    String? detail,
    String? documentation,
    String? insertText,
    TextEdit? textEdit,
    String? filterText,
    String? sortText,
    bool? needsResolve,
    String? resolveToken,
  }) => EditorCompletionItem(
    label: label ?? this.label,
    detail: detail ?? this.detail,
    documentation: documentation ?? this.documentation,
    insertText: insertText ?? this.insertText,
    textEdit: textEdit ?? this.textEdit,
    filterText: filterText ?? this.filterText,
    sortText: sortText ?? this.sortText,
    needsResolve: needsResolve ?? this.needsResolve,
    resolveToken: resolveToken ?? this.resolveToken,
  );
}

/// Результат запроса completion.
final class EditorCompletionList {
  const EditorCompletionList({
    required this.items,
    required this.replaceRange,
    this.isIncomplete = false,
  });

  final List<EditorCompletionItem> items;
  final Range replaceRange;
  final bool isIncomplete;
}
