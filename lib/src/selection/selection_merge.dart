import 'package:editor/src/selection/selection.dart';

/// Истина, если [a] и [b] должны стать одним выделением (пересечение, касание или
/// схлопнутая каретка на границе/внутри диапазона другого).
bool selectionsShouldMerge(Selection a, Selection b) {
  if (a.isCollapsed && b.isCollapsed) {
    return a.head == b.head;
  }

  final aStart = a.start;
  final aEnd = a.end;
  final bStart = b.start;
  final bEnd = b.end;

  if (a.isCollapsed) {
    final p = a.head;
    return p >= bStart && p <= bEnd;
  }
  if (b.isCollapsed) {
    final p = b.head;
    return p >= aStart && p <= aEnd;
  }

  return aStart <= bEnd && bStart <= aEnd;
}

/// Объединяет пересекающиеся и касающиеся выделения; порядок групп — по первому
/// индексу в [input] (primary остаётся первой группой, если она была первой).
List<Selection> mergeOverlappingSelections(List<Selection> input) {
  if (input.length <= 1) return List<Selection>.of(input);

  final groups = <_MergeGroup>[];
  final used = List.filled(input.length, false);

  for (var i = 0; i < input.length; i++) {
    if (used[i]) continue;
    var minIndex = i;
    final group = <Selection>[input[i]];
    used[i] = true;
    var changed = true;
    while (changed) {
      changed = false;
      for (var j = 0; j < input.length; j++) {
        if (used[j]) continue;
        if (!group.any((s) => selectionsShouldMerge(s, input[j]))) continue;
        if (j < minIndex) minIndex = j;
        group.add(input[j]);
        used[j] = true;
        changed = true;
      }
    }
    groups.add(_MergeGroup(minIndex, group));
  }

  groups.sort((a, b) => a.minIndex.compareTo(b.minIndex));
  final out = <Selection>[];
  for (final g in groups) {
    out.add(_mergeGroup(g.selections));
  }
  return out;
}

final class _MergeGroup {
  _MergeGroup(this.minIndex, this.selections);

  final int minIndex;
  final List<Selection> selections;
}

Selection _mergeGroup(List<Selection> group) {
  var unionStart = group.first.start;
  var unionEnd = group.first.end;
  for (var i = 1; i < group.length; i++) {
    final s = group[i];
    if (s.start < unionStart) unionStart = s.start;
    if (s.end > unionEnd) unionEnd = s.end;
  }
  if (unionStart >= unionEnd) {
    return Selection.collapsed(unionStart);
  }

  var anchorAtStart = false;
  var anchorAtEnd = false;
  var headAtStart = false;
  var headAtEnd = false;

  for (final s in group) {
    if (s.anchor == unionStart) anchorAtStart = true;
    if (s.anchor == unionEnd) anchorAtEnd = true;
    if (s.head == unionStart) headAtStart = true;
    if (s.head == unionEnd) headAtEnd = true;
  }

  if (anchorAtStart && headAtEnd) {
    return Selection(unionStart, unionEnd);
  }
  if (anchorAtEnd && headAtStart) {
    return Selection(unionEnd, unionStart);
  }
  if (anchorAtStart && headAtStart) {
    return Selection(unionStart, unionEnd);
  }
  if (anchorAtEnd && headAtEnd) {
    return Selection(unionEnd, unionStart);
  }

  Selection? ref;
  for (var i = group.length - 1; i >= 0; i--) {
    final s = group[i];
    if (s.isCollapsed) continue;
    if (s.anchor == unionStart || s.anchor == unionEnd) {
      ref = s;
      break;
    }
  }
  ref ??= group.last;

  var anchor = ref.anchor;
  var head = ref.head;
  if (anchor != unionStart && anchor != unionEnd) {
    anchor = ref.head <= ref.anchor ? unionEnd : unionStart;
  }
  if (head != unionStart && head != unionEnd) {
    head = head < anchor ? unionStart : unionEnd;
  }
  if (anchor == head) {
    head = anchor == unionStart ? unionEnd : unionStart;
  }
  return Selection(anchor, head);
}
