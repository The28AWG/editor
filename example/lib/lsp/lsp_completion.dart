import 'package:editor/editor.dart';
import 'package:example/lsp/lsp_markup.dart';
import 'package:example/lsp/lsp_position.dart';
import 'package:example/lsp/lsp_snippet.dart';

var _completionTokenSeq = 0;

/// Парсит LSP `textDocument/completion` → [EditorCompletionList].
EditorCompletionList? completionListFromLsp(
  String text,
  TextOffset offset,
  Object? result,
  Map<String, Map<String, dynamic>> resolveStore,
) {
  final itemsRaw = _completionItemsRaw(result);
  if (itemsRaw == null) return null;

  var replaceRange = wordRangeAt(text, offset) ?? Range(offset, offset);
  var isIncomplete = false;
  var defaults = const _CompletionDefaults();

  if (result is Map<String, dynamic>) {
    isIncomplete = result['isIncomplete'] == true;
    final itemDefaults = result['itemDefaults'] as Map<String, dynamic>?;
    if (itemDefaults != null) {
      final defaultRange = _editRangeFromDefaults(
        text,
        itemDefaults['editRange'],
      );
      defaults = _CompletionDefaults(
        snippetFormat: _isSnippetFormat(itemDefaults['insertTextFormat']),
        replaceRange: defaultRange,
      );
      if (defaultRange != null) replaceRange = defaultRange;
    }
  }

  final items = <EditorCompletionItem>[];
  for (final raw in itemsRaw) {
    if (raw is! Map<String, dynamic>) continue;
    final item = _completionItemFromLsp(
      text,
      raw,
      replaceRange,
      resolveStore,
      defaults,
    );
    if (item != null) items.add(item);
  }

  if (items.isEmpty) return null;
  return EditorCompletionList(
    items: items,
    replaceRange: replaceRange,
    isIncomplete: isIncomplete,
  );
}

/// [TextEdit] для применения выбранного completion в редактор.
TextEdit completionApplyEdit({
  required EditorCompletionItem item,
  required Range fallbackRange,
}) {
  final edit = item.textEdit;
  if (edit != null) return edit;

  final insert = item.insertText ?? insertTextFromDetail(item);
  return TextEdit.replace(fallbackRange, insert);
}

/// Fallback, если LSP не прислал insertText/textEdit (по [EditorCompletionItem.detail]).
String insertTextFromDetail(EditorCompletionItem item) {
  final detail = item.detail;
  if (detail != null && detail.startsWith('(')) return '${item.label}()';
  if (detail != null && detail.startsWith('<')) return '${item.label}<>';
  return item.label;
}

List<dynamic>? _completionItemsRaw(Object? result) {
  if (result is List) return result;
  if (result is Map<String, dynamic>) {
    final items = result['items'];
    if (items is List) return items;
  }
  return null;
}

final class _CompletionDefaults {
  const _CompletionDefaults({this.snippetFormat = false, this.replaceRange});

  final bool snippetFormat;
  final Range? replaceRange;
}

Range? _editRangeFromDefaults(String text, Object? editRange) {
  if (editRange is! Map<String, dynamic>) return null;
  final replace = editRange['replace'];
  if (replace is Map<String, dynamic>) {
    return rangeFromLsp(text, replace);
  }
  return rangeFromLsp(text, editRange);
}

bool _isSnippetFormat(Object? format) => format == 2 || format == 2.0;

bool _looksLikeSnippet(String text) => RegExp(r'\$\{?\d').hasMatch(text);

String _plainCompletionText(String text, bool declaredSnippet) {
  if (declaredSnippet || _looksLikeSnippet(text)) {
    return snippetToPlainText(text);
  }
  return text;
}

EditorCompletionItem? _completionItemFromLsp(
  String text,
  Map<String, dynamic> raw,
  Range fallbackRange,
  Map<String, Map<String, dynamic>> resolveStore,
  _CompletionDefaults defaults,
) {
  final label = _labelFromLsp(raw['label']);
  if (label.isEmpty) return null;

  final detail = _detailFromLsp(raw);
  final doc = markupContentFromLsp(raw['documentation']);
  final hasDoc = raw['documentation'] != null;
  final hasData = raw['data'] != null;
  final needsResolve = !hasDoc && (hasData || detail == null);

  final isSnippet =
      _isSnippetFormat(raw['insertTextFormat']) || defaults.snippetFormat;

  TextEdit? edit;
  final textEdit = raw['textEdit'];
  if (textEdit is Map<String, dynamic>) {
    final newText = textEdit['newText'];
    if (newText is String) {
      final plain = _plainCompletionText(newText, isSnippet);
      final rangeRaw = textEdit['range'] ?? textEdit['insert'];
      edit = rangeRaw is Map<String, dynamic>
          ? TextEdit.replace(rangeFromLsp(text, rangeRaw), plain)
          : TextEdit.replace(fallbackRange, plain);
    }
  }

  if (edit == null) {
    final textEditText = raw['textEditText'];
    if (textEditText is String) {
      final plain = _plainCompletionText(textEditText, isSnippet);
      edit = TextEdit.replace(fallbackRange, plain);
    }
  }

  if (edit == null) {
    final insert = raw['insertText'];
    if (insert is String) {
      final plain = _plainCompletionText(insert, isSnippet);
      edit = TextEdit.replace(fallbackRange, plain);
    }
  }

  String? insertText;
  final rawInsert = raw['insertText'] ?? raw['textEditText'];
  if (rawInsert is String) {
    insertText = _plainCompletionText(rawInsert, isSnippet);
  }

  String? resolveToken;
  if (needsResolve || hasData) {
    resolveToken = 'c${_completionTokenSeq++}';
    resolveStore[resolveToken] = raw;
  }

  return EditorCompletionItem(
    label: label,
    detail: detail,
    documentation: doc.isEmpty ? null : doc,
    insertText: insertText,
    textEdit: edit,
    filterText: raw['filterText'] as String?,
    sortText: raw['sortText'] as String?,
    needsResolve: needsResolve && doc.isEmpty,
    resolveToken: resolveToken,
  );
}

EditorCompletionItem completionItemResolvedFromLsp(
  String text,
  Range fallbackRange,
  Map<String, dynamic> raw,
  EditorCompletionItem base,
  Map<String, Map<String, dynamic>> resolveStore,
) {
  final reparsed = _completionItemFromLsp(
    text,
    raw,
    fallbackRange,
    resolveStore,
    const _CompletionDefaults(),
  );
  final doc = markupContentFromLsp(raw['documentation']);
  final detail = _detailFromLsp(raw) ?? base.detail;
  if (reparsed == null) {
    return EditorCompletionItem(
      label: base.label,
      detail: detail,
      documentation: doc.isEmpty ? base.documentation : doc,
      insertText: base.insertText,
      textEdit: base.textEdit,
      filterText: base.filterText,
      sortText: base.sortText,
      needsResolve: false,
      resolveToken: base.resolveToken,
    );
  }
  return EditorCompletionItem(
    label: reparsed.label,
    detail: detail,
    documentation: doc.isEmpty ? reparsed.documentation : doc,
    insertText: reparsed.insertText ?? base.insertText,
    textEdit: reparsed.textEdit ?? base.textEdit,
    filterText: reparsed.filterText,
    sortText: reparsed.sortText,
    needsResolve: false,
    resolveToken: base.resolveToken,
  );
}

String _labelFromLsp(Object? label) {
  if (label is String) return label;
  if (label is! Map<String, dynamic>) return '';
  final name = label['label'];
  return name is String ? name : '';
}

String? _detailFromLsp(Map<String, dynamic> raw) {
  final detail = raw['detail'];
  if (detail is String && detail.isNotEmpty) return detail;
  final label = raw['label'];
  if (label is Map<String, dynamic>) {
    final d = label['detail'];
    if (d is String && d.isNotEmpty) return d;
  }
  return null;
}
