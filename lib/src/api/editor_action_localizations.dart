import 'package:editor/src/api/editor_action.dart';
import 'package:flutter/material.dart';

/// Собирает [EditorActionLabels] из [MaterialLocalizations] текущего [BuildContext].
///
/// Cut, copy, paste и select all берутся из локали Material. Undo и redo
/// в Material не локализованы — передайте свои строки через [undo] и [redo]
/// (или используйте [EditorActionLabels] напрямую).
///
/// ```dart
/// EditorView(
///   actionConfiguration: EditorActionConfiguration(
///     labels: editorActionLabelsFromMaterial(
///       context,
///       undo: l10n.editorUndo,
///       redo: l10n.editorRedo,
///     ),
///   ),
/// );
/// ```
EditorActionLabels editorActionLabelsFromMaterial(
  BuildContext context, {
  String undo = 'Undo',
  String redo = 'Redo',
}) {
  final m = MaterialLocalizations.of(context);
  return EditorActionLabels(
    undo: undo,
    redo: redo,
    cut: m.cutButtonLabel,
    copy: m.copyButtonLabel,
    paste: m.pasteButtonLabel,
    selectAll: m.selectAllButtonLabel,
  );
}
