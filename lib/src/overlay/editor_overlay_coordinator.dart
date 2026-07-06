import 'package:editor/src/overlay/editor_overlay_descriptor.dart';
import 'package:editor/src/overlay/editor_overlay_dismiss.dart';
import 'package:editor/src/overlay/editor_overlay_geometry.dart';
import 'package:editor/src/overlay/editor_overlay_keyboard.dart';
import 'package:editor/src/overlay/editor_overlay_layout.dart';
import 'package:flutter/widgets.dart';

/// Управляет стеком overlay: показ, скрытие, приоритеты и реакция на события.
final class EditorOverlayCoordinator extends ChangeNotifier {
  EditorOverlayGeometrySource? geometry;

  /// Размер overlay-хоста (экран); задаётся [EditorView] для `clampToViewport: false`.
  Size? overlayHostSize;

  final List<_OverlayEntry> _entries = [];
  int _documentVersion = -1;

  /// Активные сессии, отсортированные по [EditorOverlayDescriptor.priority].
  List<EditorOverlaySession> get sessions {
    final result = <EditorOverlaySession>[];
    for (final e in _entries) {
      result.add(e.session);
    }
    return List.unmodifiable(result);
  }

  bool get isEmpty => _entries.isEmpty;

  bool get isNotEmpty => _entries.isNotEmpty;

  /// `true`, если верхний overlay (или его родитель) перехватывает клавиатуру редактора.
  bool get capturesKeyboard {
    if (_entries.isEmpty) return false;
    return _sessionCapturesKeyboard(_entries.last.session);
  }

  bool _sessionCapturesKeyboard(EditorOverlaySession session) {
    if (_sessionBlocksEditor(session)) return true;
    final parentId = session.descriptor.parentId;
    if (parentId == null) return false;
    final parent = _entryFor(parentId);
    if (parent == null) return false;
    return _sessionCapturesKeyboard(parent.session);
  }

  bool _sessionBlocksEditor(EditorOverlaySession session) {
    final d = session.descriptor;
    return d.capturesKeyboard ||
        d.keyboardPolicy == EditorOverlayKeyboardPolicy.exclusive;
  }

  /// Передаёт клавишу cooperative-overlay; `handled` — редактор не видит событие.
  KeyEventResult dispatchCooperativeKeyEvent(KeyEvent event) {
    for (final e in _entries) {
      final d = e.descriptor;
      if (d.keyboardPolicy != EditorOverlayKeyboardPolicy.cooperative) continue;
      final handler = d.onKeyEvent;
      if (handler == null) continue;
      final result = handler(event);
      if (result == KeyEventResult.handled) return result;
    }
    return KeyEventResult.ignored;
  }

  /// Закрывает верхний overlay по Escape; для вложенных панелей скрывает корень группы.
  bool dismissOnEscape() {
    final top = topSession;
    if (top == null) return false;
    return dismissSessionOnEscape(top);
  }

  /// Закрывает overlay и его группу, если [EditorOverlayDismissPolicy.escape] разрешён.
  bool dismissSessionOnEscape(EditorOverlaySession session) {
    if (!session.descriptor.dismissPolicy.escape) return false;
    hide(_rootOverlayId(session));
    return true;
  }

  String _rootOverlayId(EditorOverlaySession session) {
    var id = session.id;
    var parentId = session.descriptor.parentId;
    while (parentId != null) {
      id = parentId;
      final parent = _entryFor(parentId);
      parentId = parent?.descriptor.parentId;
    }
    return id;
  }

  /// Верхняя сессия (наибольший priority).
  EditorOverlaySession? get topSession =>
      _entries.isEmpty ? null : _entries.last.session;

  /// Показывает overlay; с тем же [EditorOverlayDescriptor.id] заменяет существующий.
  void show(EditorOverlayDescriptor descriptor) {
    _applyConflictPolicy(descriptor);
    final preserved = <String, _OverlaySessionState>{};
    _captureSessionState(preserved, descriptor.id);
    for (final child in descriptor.children) {
      _captureSessionState(preserved, child.id);
    }

    _removeEntry(descriptor.id);
    _entries.removeWhere((e) => e.descriptor.parentId == descriptor.id);

    final session = EditorOverlaySession(
      id: descriptor.id,
      descriptor: descriptor,
      coordinator: this,
    );
    _restoreSessionState(session, preserved[descriptor.id]);
    _resolveAnchor(session);
    _entries.add(_OverlayEntry(session: session, descriptor: descriptor));
    _sortEntries();
    _registerChildren(descriptor, session, preserved);
    notifyListeners();
  }

  void _captureSessionState(
    Map<String, _OverlaySessionState> preserved,
    String id,
  ) {
    final entry = _entryFor(id);
    if (entry == null) return;
    preserved[id] = _OverlaySessionState(
      measuredSize: entry.session.measuredSize,
      userSize: entry.session.userSize,
      userOffset: entry.session.userOffset,
    );
  }

  void _restoreSessionState(
    EditorOverlaySession session,
    _OverlaySessionState? state,
  ) {
    if (state == null) return;
    session
      ..measuredSize = state.measuredSize
      ..userSize = state.userSize
      ..userOffset = state.userOffset;
  }

  void _registerChildren(
    EditorOverlayDescriptor parent,
    EditorOverlaySession parentSession,
    Map<String, _OverlaySessionState> preserved,
  ) {
    for (final child in parent.children) {
      final childDescriptor = EditorOverlayDescriptor(
        id: child.id,
        builder: child.builder,
        anchor: child.anchor,
        kind: child.kind,
        layout: child.layout,
        priority: child.priority,
        capturesKeyboard: child.capturesKeyboard,
        keyboardPolicy: child.keyboardPolicy,
        onKeyEvent: child.onKeyEvent,
        dismissPolicy: child.dismissPolicy,
        children: child.children,
        parentId: parent.id,
      );
      _applyConflictPolicy(childDescriptor);
      _removeEntry(childDescriptor.id);
      final childSession = EditorOverlaySession(
        id: childDescriptor.id,
        descriptor: childDescriptor,
        coordinator: this,
      );
      _restoreSessionState(childSession, preserved[childDescriptor.id]);
      childSession.anchorRect = _parentPanelRect(parentSession);
      _entries.add(
        _OverlayEntry(session: childSession, descriptor: childDescriptor),
      );
    }
    _sortEntries();
  }

  Rect? _parentPanelRect(EditorOverlaySession parent) {
    final anchor = parent.anchorRect;
    if (anchor == null) return null;
    final size = _panelSize(parent);
    final viewport = _viewportRectLocal();
    if (viewport == null) {
      return Rect.fromLTWH(anchor.left, anchor.top, size.width, size.height);
    }
    final layout = computeOverlayLayout(
      anchorRect: anchor,
      layoutBounds: _layoutBoundsFor(parent.descriptor.layout),
      policy: parent.descriptor.layout,
      contentSize: size,
    );
    return Rect.fromLTWH(
      layout.offset.dx,
      layout.offset.dy,
      size.width,
      size.height,
    );
  }

  Rect _layoutBoundsFor(EditorOverlayLayoutPolicy policy) {
    final viewport = _viewportRectLocal();
    if (viewport == null) return Offset.zero & (overlayHostSize ?? Size.zero);
    if (policy.clampToViewport || overlayHostSize == null) return viewport;
    final geo = geometry;
    if (geo == null) return viewport;
    final global = geo.viewportRectInGlobal();
    if (global == null) return viewport;
    return overlayLayoutBounds(
      viewportRectLocal: viewport,
      viewportGlobalOrigin: global.topLeft,
      overlayHostSize: overlayHostSize!,
      clampToViewport: false,
    );
  }

  Rect? _viewportRectLocal() {
    final geo = geometry;
    if (geo == null) return null;
    final global = geo.viewportRectInGlobal();
    if (global == null) return null;
    return geo.globalRectToViewportLocal(global);
  }

  /// Измеренный размер или оценка из [EditorOverlayLayoutPolicy] до первого layout.
  Size _panelSize(EditorOverlaySession session) {
    final measured = session.effectiveSize;
    if (measured != null) return measured;
    final layout = session.descriptor.layout;
    return Size(
      layout.preferredWidth ?? layout.minWidth,
      layout.preferredHeight ?? layout.minHeight,
    );
  }

  void _applyConflictPolicy(EditorOverlayDescriptor descriptor) {
    final policy = descriptor.dismissPolicy;
    if (policy.supersedesLowerPriority) {
      _entries.removeWhere(
        (e) =>
            e.descriptor.priority < descriptor.priority &&
            e.descriptor.id != descriptor.parentId,
      );
    }
    if (policy.exclusiveWithinKind && descriptor.parentId == null) {
      _entries.removeWhere(
        (e) =>
            e.descriptor.parentId == null &&
            e.descriptor.kind == descriptor.kind &&
            e.descriptor.id != descriptor.id,
      );
    }
  }

  /// Скрывает overlay и его дочерние панели.
  void hide(String id) {
    final before = _entries.length;
    _removeEntry(id);
    _entries.removeWhere((e) => e.descriptor.parentId == id);
    if (_entries.length == before) return;
    notifyListeners();
  }

  void hideAll() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }

  /// Скрывает overlay указанной категории.
  void hideKind(EditorOverlayKind kind) {
    final before = _entries.length;
    _entries.removeWhere((e) => e.descriptor.kind == kind);
    if (_entries.length != before) notifyListeners();
  }

  void resize(String id, Size size) {
    final entry = _entryFor(id);
    if (entry == null) return;
    entry.session.userSize = size;
    _updateChildrenAnchors(entry.session);
    notifyListeners();
  }

  /// Сохраняет пользовательское смещение панели после drag.
  void move(String id, Offset userOffset) {
    final entry = _entryFor(id);
    if (entry == null) return;
    if (entry.session.userOffset == userOffset) return;
    entry.session.userOffset = userOffset;
    notifyListeners();
  }

  void updateMeasuredSize(String id, Size size) {
    final entry = _entryFor(id);
    if (entry == null) return;
    if (entry.session.measuredSize == size) return;
    entry.session.measuredSize = size;
    _updateChildrenAnchors(entry.session);
    notifyListeners();
  }

  void _updateChildrenAnchors(EditorOverlaySession parent) {
    final panel = _parentPanelRect(parent);
    if (panel == null) return;
    for (final e in _entries) {
      if (e.descriptor.parentId == parent.id) {
        e.session.anchorRect = panel;
      }
    }
  }

  /// Вызывается при прокрутке viewport.
  void onScroll() {
    if (_entries.isEmpty) return;
    var changed = false;
    final toRemove = <String>[];
    for (final e in _entries) {
      final policy = e.descriptor.dismissPolicy;
      if (policy.scroll && !policy.trackAnchorOnScroll) {
        toRemove.add(e.descriptor.id);
        continue;
      }
      if (policy.trackAnchorOnScroll) {
        final before = e.session.anchorRect;
        _resolveAnchor(e.session, parentId: e.descriptor.parentId);
        if (e.session.anchorRect != before) changed = true;
      }
    }
    for (final id in toRemove) {
      _removeEntry(id);
      _entries.removeWhere((e) => e.descriptor.parentId == id);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Вызывается при изменении версии документа.
  void onDocumentChanged(int version) {
    if (version == _documentVersion) return;
    _documentVersion = version;
    if (_entries.isEmpty) return;
    var changed = false;
    final toRemove = <String>[];
    for (final e in _entries) {
      if (e.descriptor.dismissPolicy.documentChange) {
        toRemove.add(e.descriptor.id);
      }
    }
    for (final id in toRemove) {
      _removeEntry(id);
      _entries.removeWhere((e) => e.descriptor.parentId == id);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Вызывается при смене выделения.
  void onSelectionChanged() {
    if (_entries.isEmpty) return;
    var changed = false;
    final toRemove = <String>[];
    for (final e in _entries) {
      if (e.descriptor.dismissPolicy.selectionChange) {
        toRemove.add(e.descriptor.id);
        continue;
      }
      if (e.descriptor.dismissPolicy.trackAnchorOnScroll) {
        final before = e.session.anchorRect;
        _resolveAnchor(e.session, parentId: e.descriptor.parentId);
        if (e.session.anchorRect != before) changed = true;
      }
    }
    for (final id in toRemove) {
      _removeEntry(id);
      _entries.removeWhere((e) => e.descriptor.parentId == id);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Пересчитывает якоря (например, после layout).
  void refreshAnchors() {
    if (_entries.isEmpty || geometry == null) return;
    var changed = false;
    for (final e in _entries) {
      if (e.descriptor.parentId != null) continue;
      final before = e.session.anchorRect;
      _resolveAnchor(e.session);
      if (e.session.anchorRect != before) changed = true;
    }
    for (final e in _entries) {
      if (e.descriptor.parentId == null) continue;
      final parent = _entryFor(e.descriptor.parentId!);
      if (parent == null) continue;
      final before = e.session.anchorRect;
      e.session.anchorRect = _parentPanelRect(parent.session);
      if (e.session.anchorRect != before) changed = true;
    }
    if (changed) notifyListeners();
  }

  void _resolveAnchor(EditorOverlaySession session, {String? parentId}) {
    if (parentId != null) {
      final parent = _entryFor(parentId);
      session.anchorRect = parent == null
          ? null
          : _parentPanelRect(parent.session);
      return;
    }
    final geo = geometry;
    if (geo == null) {
      session.anchorRect = null;
      return;
    }
    session.anchorRect = resolveOverlayAnchorRect(
      anchor: session.descriptor.anchor,
      geometry: geo,
    );
  }

  bool _removeEntry(String id) {
    final before = _entries.length;
    _entries.removeWhere((e) => e.descriptor.id == id);
    return _entries.length != before;
  }

  _OverlayEntry? _entryFor(String id) {
    for (final e in _entries) {
      if (e.descriptor.id == id) return e;
    }
    return null;
  }

  void _sortEntries() {
    _entries.sort(
      (a, b) => a.descriptor.priority.compareTo(b.descriptor.priority),
    );
  }
}

final class _OverlaySessionState {
  const _OverlaySessionState({
    this.measuredSize,
    this.userSize,
    this.userOffset = Offset.zero,
  });

  final Size? measuredSize;
  final Size? userSize;
  final Offset userOffset;
}

final class _OverlayEntry {
  _OverlayEntry({required this.session, required this.descriptor});

  final EditorOverlaySession session;
  final EditorOverlayDescriptor descriptor;
}
