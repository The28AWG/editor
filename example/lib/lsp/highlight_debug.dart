import 'package:editor/editor.dart';
import 'package:flutter/foundation.dart';

/// Включить трассировку подсветки:
///
/// ```bash
/// flutter run --dart-define=HIGHLIGHT_DEBUG=true
/// ```
///
/// или выставить [kHighlightDebug] в `true` для локальной отладки.
const kHighlightDebug = false;

void highlightDebugLog(String message) {
  if (!kHighlightDebug) return;
  debugPrint('[highlight] $message');
}

/// Краткое описание [DocumentChange] для лога.
String describeDocumentChange(DocumentChange change) =>
    'range=[${change.range.start},${change.range.end}) '
    'removed=${change.removedLength} '
    'insertedLen=${change.insertedText.length} '
    'v${change.oldVersion}->${change.newVersion}';

/// Похоже на undo вставки: удаление без новой вставки.
bool isUndoLikeChange(DocumentChange change) =>
    change.insertedText.isEmpty && change.removedLength > 0;

/// Похоже на чистую вставку (набор символов или redo вставки).
bool isInsertLikeChange(DocumentChange change) =>
    change.removedLength == 0 && change.insertedText.isNotEmpty;

/// Сводка журнала [_pendingStyleChanges].
String summarizePendingChanges(List<DocumentChange> pending) {
  if (pending.isEmpty) return '[]';
  final parts = <String>[];
  for (final c in pending) {
    parts.add('@${c.range.start}+${c.insertedText.length}-${c.removedLength}');
  }
  return '[${parts.join(', ')}]';
}
