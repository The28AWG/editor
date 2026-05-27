import 'package:editor/editor.dart';
import 'package:flutter/foundation.dart';

/// `false` — отключить лог выделения в консоли.
const kSelectionDebug = false;

/// Логирует [SelectionChange] в debug console.
///
/// При double-click ожидайте одну запись с `text="…"` (полное слово).
/// Если сразу после неё `head` уменьшается без движения мыши — баг pointer drag.
void selectionChangeLog(Document doc, SelectionChange change, {String? tag}) {
  if (!kSelectionDebug) return;

  final prefix = tag == null ? '[selection]' : '[selection/$tag]';
  final oldP = change.oldValue.primary;
  final newP = change.newValue.primary;
  final buf = StringBuffer(prefix)
    ..write(' ')
    ..write(_formatSel(doc, oldP))
    ..write(' → ')
    ..write(_formatSel(doc, newP));

  if (!newP.isCollapsed) {
    final text = doc.getText(newP.range);
    final preview = _preview(text, 40);
    buf
      ..write(' text="')
      ..write(_escape(preview))
      ..write('"');
  }

  debugPrint(buf.toString());
}

String _formatSel(Document doc, Selection sel) {
  final a = doc.positionAt(sel.anchor);
  final h = doc.positionAt(sel.head);
  if (sel.isCollapsed) {
    return 'collapsed@${a.line + 1}:${a.column} off=${sel.head}';
  }
  return 'anchor=${sel.anchor}(${a.line + 1}:${a.column}) '
      'head=${sel.head}(${h.line + 1}:${h.column}) '
      'range=[${sel.start},${sel.end}) len=${sel.end - sel.start}';
}

String _preview(String text, int maxChars) {
  if (text.length <= maxChars) return text;
  final b = StringBuffer();
  for (var i = 0; i < maxChars; i++) {
    b.writeCharCode(text.codeUnitAt(i));
  }
  return '${b.toString()}…';
}

String _escape(String s) =>
    s.replaceAll('\n', '\\n').replaceAll('\r', '\\r').replaceAll('\t', '\\t');
