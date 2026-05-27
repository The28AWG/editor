import 'package:editor/editor.dart';
import 'package:example/lsp/lsp_position.dart';

/// Parses LSP `textDocument/inlayHint` result items.
List<EditorInlayHint> inlayHintsFromLsp(String text, List<dynamic> items) {
  final hints = <EditorInlayHint>[];
  for (final item in items) {
    if (item is! Map<String, dynamic>) continue;
    final position = item['position'];
    if (position is! Map<String, dynamic>) continue;

    final label = _labelFromLsp(item['label']);
    if (label.isEmpty) continue;

    final anchor = offsetAtLspPosition(
      text,
      Position(position['line'] as int, position['character'] as int),
    );

    hints.add(
      EditorInlayHint(
        anchorOffset: anchor,
        label: label,
        kind: _kindFromLsp(item['kind'] as int?),
        paddingLeft: _paddingFromLsp(item['paddingLeft']),
        paddingRight: _paddingFromLsp(item['paddingRight']),
      ),
    );
  }
  hints.sort((a, b) => a.anchorOffset.compareTo(b.anchorOffset));
  return hints;
}

String _labelFromLsp(Object? label) {
  if (label is String) return label;
  if (label is! List) return '';
  final buffer = StringBuffer();
  for (final part in label) {
    if (part is! Map<String, dynamic>) continue;
    final value = part['value'];
    if (value is String) buffer.write(value);
  }
  return buffer.toString();
}

/// LSP uses [bool] (enable default padding) or legacy [num] pixel values.
double _paddingFromLsp(Object? value, {double whenTrue = 4}) {
  if (value == null) return 0;
  if (value is bool) return value ? whenTrue : 0;
  if (value is num) return value.toDouble();
  return 0;
}

EditorInlayHintKind _kindFromLsp(int? value) => switch (value) {
  1 => EditorInlayHintKind.type,
  2 => EditorInlayHintKind.parameter,
  _ => EditorInlayHintKind.other,
};
