import 'dart:async';

import 'package:editor/src/api/editor_action.dart';
import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/api/editor_menu.dart';
import 'package:editor/src/editing/clipboard_text.dart';
import 'package:editor/src/highlight/word_bounds.dart';
import 'package:editor/src/layout/glyph_cache.dart';
import 'package:editor/src/layout/line_layout.dart';
import 'package:editor/src/layout/line_text_metrics.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/style_resolver.dart';
import 'package:editor/src/view/caret/caret_blink_controller.dart';
import 'package:editor/src/view/input/editor_text_input.dart';
import 'package:editor/src/view/input/input_controller.dart';
import 'package:editor/src/view/layers/editor_layers_painter.dart';
import 'package:editor/src/view/menu/editor_context_menu.dart';
import 'package:editor/src/view/navigation/link_modifier.dart';
import 'package:editor/src/view/pointer/document_pointer_mapper.dart';
import 'package:editor/src/view/pointer/selection_drag_autoscroll.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter/services.dart';

/// Прокручиваемая поверхность редактора: layout, отрисовка, pointer-ввод и фокус клавиатуры.
///
/// Используется внутри [EditorView]. Управляет:
///
/// - [LineLayout] и [GlyphCache], пересобираемыми при уведомлении контроллера.
/// - Вертикальной (и необязательной горизонтальной) синхронизацией [ScrollController] с [ViewportState].
/// - [EditorLayersPainter] внутри [CustomPaint] + [GestureDetector].
/// - [EditorInputHandler] для клавиатуры desktop/web; [EditorTextInputClient] для IME на Android/iOS.
///
/// ## Режимы прокрутки
///
/// Когда включён [EditorController.config.wordWrap], используется только вертикальная прокрутка.
/// Иначе вложенные вертикальный + горизонтальный scroll view для длинных строк.
/// На desktop [Scrollbar] с `interactive: true` — клик по дорожке и перетаскивание ползунка.
///
/// ## Взаимодействие указателем
///
/// - Tap (1-й down): каретка; Alt+tap — мультикурсор ([EditorController.addCursorAt]).
/// - 2-й down на той же строке (≤500 ms): слово ([wordRangeAt]).
/// - 3-й down: логическая строка ([Document.getLineRange]).
/// - 4-й down: весь документ (как в VS Code).
/// - Pointer drag: расширить выделение от якоря; у краёв viewport — autoscroll.
/// - ПКМ; long-press (touch/stylus): контекстное меню ([EditorMenuConfiguration.buildItems],
///   отрисовка [EditorMenuPresenter]); каретка переносится на клик, если клик вне текущего
///   выделения (см. [shouldMoveCaretForPointerMenu]).
/// - IME toolbar: то же меню у каретки/выделения ([EditorMenuAnchor.selection]), без переноса каретки по клику.
/// - Ctrl/Cmd+hover: подсветка ссылки и курсор «рука»; Ctrl/Cmd+клик — переход ([EditorController.followLinkAt]).
///
/// ## Контекстное меню
///
/// Показ через [ContextMenuController] и [EditorMenuPresenter.buildToolbar].
/// При открытом меню у [Focus] редактора `skipTraversal: true` и
/// `canRequestFocus: false`, фокус уходит в overlay меню ([_MenuFocusBootstrap]).
final class EditorScrollable extends StatefulWidget {
  /// Создаёт прокручиваемый редактор, привязанный к [controller].
  const EditorScrollable({
    required this.controller,
    this.showGutter = false,
    this.actionConfiguration = const EditorActionConfiguration(),
    this.menuConfiguration,
    super.key,
  });

  /// Состояние редактирования, тема, диагностика и viewport.
  final EditorController controller;

  /// Резервировать ли 48 px для номеров строк (см. [EditorLayersPainter]).
  final bool showGutter;

  /// Клавиши, подписи, отключённые действия.
  final EditorActionConfiguration actionConfiguration;

  /// Пункты меню; по умолчанию строится из [actionConfiguration] в [build].
  final EditorMenuConfiguration? menuConfiguration;

  @override
  State<EditorScrollable> createState() => _EditorScrollableState();
}

/// Состояние [EditorScrollable]: layout, прокрутка, жесты, IME и клавиатура.
final class _EditorScrollableState extends State<EditorScrollable>
    with SingleTickerProviderStateMixin {
  static const _selectionScrollEdgeSize = 28.0;
  static const _selectionScrollMaxSpeed = 900.0;

  /// Кэш ширин символов текущей темы.
  late GlyphCache _glyphCache;

  /// Layout документа для hit-test и painter.
  late LineLayout _lineLayout;

  /// Обработчик клавиатуры desktop/web.
  late EditorInputHandler _input;

  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();

  /// Для [markNeedsPaint] без полного [setState] при инкрементальной правке.
  final GlobalKey _editorPaintKey = GlobalKey();

  /// Активное IME-соединение (Android/iOS) или `null`.
  TextInputConnection? _textInputConnection;

  EditorTextInputClient? _textInputClient;

  /// Последнее значение, отправленное в IME ([TextInputConnection.setEditingState]).
  TextEditingValue? _lastRemoteEditingValue;

  /// Управляет overlay контекстного меню ([ContextMenuController.show]).
  late ContextMenuController _contextMenuController;

  /// `true`, пока меню открыто: блокирует клавиатуру редактора и меняет focus traversal.
  bool _contextMenuOpen = false;

  final GlobalKey _surfaceKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();

  final ClipboardStatusNotifier _clipboardStatus = ClipboardStatusNotifier();

  late final SelectionDragAutoscroll _selectionAutoscroll;

  late final CaretBlinkController _caretBlink;

  int _trackedDocVersion = -1;
  String _trackedCaretSignature = '';
  StyleResolver? _trackedResolver;
  int _trackedStyleEpoch = -1;
  int _trackedInlayCount = -1;

  static const _dragExtendSlop = 4.0;

  bool _selectionDragActive = false;
  TextOffset? _selectionDragAnchor;
  Offset? _lastGlobalPointer;
  Offset? _dragDownGlobal;
  bool _dragExtendHead = false;

  /// После double/triple click блокировать «сжатие» head внутри выделенного диапазона.
  bool _freezeMultiClickSelection = false;
  Range? _frozenMultiClickRange;

  /// ЛКМ зажата (между down и up).
  bool _primaryHeld = false;

  /// Счётчик down без промежуточного up (ОС иногда шлёт 2–3 down подряд).
  int _downsWhileHeld = 0;

  /// Игнорировать новый «первый клик» сразу после double-click (фантомный down).
  DateTime? _blockNewClickSequenceUntil;

  /// Тип указателя активного нажатия ЛКМ; для long-press меню только touch/stylus.
  PointerDeviceKind? _primaryDownPointerKind;

  /// Интервал цепочки multi-click (VS Code `editor.multiClickTime` по умолчанию ~500 ms).
  static const _multiClickWindow = Duration(milliseconds: 500);

  int _clickCount = 0;
  DateTime? _lastClickTime;
  TextOffset? _lastClickOffset;

  /// Последняя глобальная позиция указателя (для link hover).
  Offset? _lastHoverGlobal;

  bool _linkModifierHandlerRegistered = false;

  /// Подписывается на контроллер, scroll listeners и запрашивает фокус после первого кадра.
  @override
  void initState() {
    super.initState();
    _contextMenuController = ContextMenuController(
      onRemove: () => _setContextMenuOpen(false),
    );
    _initLayout();
    _trackedDocVersion = widget.controller.document.version;
    _trackedResolver = widget.controller.resolver;
    _trackedStyleEpoch = widget.controller.resolver.styleEpoch;
    _trackedInlayCount = widget.controller.inlayHints.length;
    _recreateInputHandler();
    widget.controller.addListener(_onControllerChanged);
    _verticalScroll.addListener(_onVerticalScroll);
    _horizontalScroll.addListener(_onHorizontalScroll);
    widget.controller.focusNode.addListener(_onFocusChanged);
    _selectionAutoscroll = SelectionDragAutoscroll(
      vsync: this,
      viewportHeight: () => widget.controller.viewport.viewportHeight,
      viewportWidth: () => widget.controller.viewport.viewportWidth,
      edgeSize: _selectionScrollEdgeSize,
      maxSpeedPxPerSec: _selectionScrollMaxSpeed,
      onTick: _onSelectionAutoscrollTick,
    );
    _caretBlink = CaretBlinkController();
    _trackedCaretSignature = _caretSignature(widget.controller);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.focusNode.requestFocus();
      }
    });
    _registerLinkModifierHandler();
  }

  bool _onHardwareKeyChanged(KeyEvent event) {
    if (!linkModifierPressed()) {
      widget.controller.clearLinkHover();
    } else {
      final global = _lastHoverGlobal;
      if (global != null) {
        _updateLinkHoverAtGlobal(global, widget.showGutter ? 48.0 : 0.0);
      }
    }
    return false;
  }

  void _registerLinkModifierHandler() {
    if (_linkModifierHandlerRegistered) return;
    HardwareKeyboard.instance.addHandler(_onHardwareKeyChanged);
    _linkModifierHandlerRegistered = true;
  }

  void _unregisterLinkModifierHandler() {
    if (!_linkModifierHandlerRegistered) return;
    HardwareKeyboard.instance.removeHandler(_onHardwareKeyChanged);
    _linkModifierHandlerRegistered = false;
  }

  @override
  void didUpdateWidget(EditorScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actionConfiguration != widget.actionConfiguration) {
      _recreateInputHandler();
    }
  }

  /// Пересоздаёт [EditorInputHandler] после смены [EditorActionConfiguration].
  void _recreateInputHandler() {
    _input = EditorInputHandler(
      widget.controller,
      configuration: widget.actionConfiguration,
    );
  }

  /// Платформенный текстовый ввод используется на Android и iOS для IME-композиции.
  bool get _usePlatformTextInput =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Кэш [EditorConfig.wordWrap] для вложенности scroll view.
  bool get _wordWrap => widget.controller.config.wordWrap;

  /// На desktop полоса прокрутки всегда видна и реагирует на клик по дорожке.
  bool _desktopScrollbarThumbVisible(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return false;
    }
  }

  /// Подключает или отключает [TextInputConnection] при изменении фокуса.
  void _onFocusChanged() {
    _syncCaretBlink(
      recordActivity: widget.controller.focusNode.hasFocus,
    );
    if (widget.controller.focusNode.hasFocus && _usePlatformTextInput) {
      _textInputClient = EditorTextInputClient(
        widget.controller,
        onShowToolbar: _showSelectionToolbar,
        onHideToolbar: _hideContextMenu,
      );
      _lastRemoteEditingValue = null;
      _textInputConnection = TextInput.attach(
        _textInputClient!,
        const TextInputConfiguration(enableDeltaModel: true),
      )..show();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPlatformTextInput();
      });
    } else {
      _textInputConnection?.close();
      _textInputConnection = null;
      _textInputClient = null;
      _lastRemoteEditingValue = null;
      widget.controller.setCompositionRange(null);
      if (!_contextMenuOpen) {
        _hideContextMenu();
      }
    }
  }

  /// Синхронизирует документ/выделение и геометрию с платформенным IME.
  void _syncPlatformTextInput() {
    final connection = _textInputConnection;
    final client = _textInputClient;
    if (connection == null || client == null) return;

    final value = EditorTextInputClient.editingValueFor(widget.controller);
    client.currentTextEditingValue = value;
    if (value != _lastRemoteEditingValue) {
      connection.setEditingState(value);
      _lastRemoteEditingValue = value;
    }
    _updateTextInputGeometry(connection);
  }

  /// Обновляет размер editable-области и прямоугольник каретки для IME.
  void _updateTextInputGeometry(TextInputConnection connection) {
    final renderObject = _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    connection.setEditableSizeAndTransform(
      renderObject.size,
      renderObject.getTransformTo(null),
    );

    final gutterW = widget.showGutter ? 48.0 : 0.0;
    final caretRect = _caretRectForTextInput(gutterW);
    if (caretRect != null) {
      connection.setCaretRect(caretRect);
    }
  }

  /// Прямоугольник каретки в локальных координатах поверхности редактора.
  Rect? _caretRectForTextInput(double gutterW) {
    final controller = widget.controller;
    final head = controller.selection.primary.head;
    final boxes = _lineLayout.getBoxesForRange(
      Range(head, head),
      controller.theme.lineHeight,
    );
    if (boxes.isEmpty) return null;
    final box = boxes.first;
    return Rect.fromLTRB(
      gutterW + box.left,
      box.top,
      gutterW + box.right,
      box.bottom,
    );
  }

  /// Синхронизирует флаг открытого меню с focus-политикой редактора.
  ///
  /// Пока меню открыто, [FocusNode.canRequestFocus] редактора `false` и при
  /// пересборке [Focus.skipTraversal] — фокус остаётся в overlay меню.
  void _setContextMenuOpen(bool open) {
    if (_contextMenuOpen == open) return;
    widget.controller.focusNode.canRequestFocus = !open;
    if (mounted) {
      setState(() => _contextMenuOpen = open);
    } else {
      _contextMenuOpen = open;
    }
  }

  /// Закрывает overlay меню и возвращает фокус в редактор.
  ///
  /// Безопасен при повторном вызове. Использует [ContextMenuController.remove]
  /// или [ContextMenuController.removeAny], если overlay уже снят платформой.
  void _hideContextMenu() {
    if (!_contextMenuOpen && !_contextMenuController.isShown) return;
    _setContextMenuOpen(false);
    if (_contextMenuController.isShown) {
      _contextMenuController.remove();
    } else {
      ContextMenuController.removeAny();
    }
    widget.controller.focusNode.requestFocus();
  }

  /// Маршрутизирует клавиши: при открытом меню события игнорируются здесь
  /// (обрабатываются [FocusScope] меню), иначе — [EditorInputHandler].
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_contextMenuOpen) return KeyEventResult.ignored;
    return _input.handleKeyEvent(event);
  }

  /// Переносит каретку на [offset] перед контекстным меню, если клик вне выделения.
  void _prepareSelectionForPointerMenu(
    EditorController controller,
    TextOffset offset,
  ) {
    final primary = controller.selection.primary;
    if (shouldMoveCaretForPointerMenu(offset, primary)) {
      controller.setSingleCursor(offset);
    }
  }

  /// Прямоугольник primary-выделения в глобальных координатах (IME toolbar).
  Rect? _selectionRectInGlobal(double gutterW) {
    final renderObject = _surfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final controller = widget.controller;
    final theme = controller.theme;
    final sel = controller.selection.primary;
    final range = sel.isCollapsed ? Range(sel.head, sel.head) : sel.range;
    final boxes = _lineLayout.getBoxesForRange(range, theme.lineHeight);
    if (boxes.isEmpty) return null;

    var left = boxes.first.left;
    var top = boxes.first.top;
    var right = boxes.first.right;
    var bottom = boxes.first.bottom;
    for (var i = 1; i < boxes.length; i++) {
      final b = boxes[i];
      if (b.left < left) left = b.left;
      if (b.top < top) top = b.top;
      if (b.right > right) right = b.right;
      if (b.bottom > bottom) bottom = b.bottom;
    }

    final local = Rect.fromLTRB(gutterW + left, top, gutterW + right, bottom);
    return Rect.fromPoints(
      renderObject.localToGlobal(local.topLeft),
      renderObject.localToGlobal(local.bottomRight),
    );
  }

  /// Показывает контекстное меню через [ContextMenuController].
  ///
  /// Перед показом обновляет [ClipboardStatusNotifier], вычисляет якорь
  /// ([EditorMenuAnchor.pointer] или bbox выделения) и собирает пункты через
  /// [EditorMenuConfiguration.buildItems]. На каждый показ создаётся новый
  /// [ContextMenuController] (повторный [show] на том же экземпляре не поддерживается).
  Future<void> _showContextMenu({
    required double gutterW,
    required EditorMenuAnchor anchorKind,
    required Offset globalPointer,
    SelectionState? selectionForMenu,
  }) async {
    _hideContextMenu();
    await _clipboardStatus.update();
    if (!mounted) return;

    final controller = widget.controller;
    final menuSelection = selectionForMenu ?? controller.selection;
    final presentAsMobileToolbar =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    final lineH = controller.theme.lineHeightPx;
    final anchorRect = switch (anchorKind) {
      EditorMenuAnchor.pointer => EditorMenuPresenter.pointerAnchorRect(
        globalPointer,
        lineH,
      ),
      EditorMenuAnchor.selection =>
        _selectionRectInGlobal(gutterW) ??
            EditorMenuPresenter.pointerAnchorRect(globalPointer, lineH),
    };
    final anchors = EditorMenuPresenter.toolbarAnchors(anchorRect);

    _setContextMenuOpen(true);
    // Новый controller на каждый показ: после [remove] повторный [show] на том же
    // экземпляре в документации Flutter не поддерживается.
    _contextMenuController = ContextMenuController(
      onRemove: () => _setContextMenuOpen(false),
    );
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (menuContext) {
        final actionConfig = widget.actionConfiguration;
        final menuConfig =
            widget.menuConfiguration ??
            EditorMenuConfiguration(actionConfiguration: actionConfig);
        final menuCtx = EditorMenuBuildContext(
          controller: controller,
          capabilities: EditorActionCapabilities.of(
            controller,
            clipboardStatus: _clipboardStatus.value,
            selectionForMenu: menuSelection,
          ),
          anchor: anchorKind,
          clipboardStatus: _clipboardStatus.value,
          labels: menuConfig.labels,
          presentAsMobileToolbar: presentAsMobileToolbar,
          actionConfiguration: actionConfig,
        );
        final items = menuConfig.buildItems(menuCtx);

        return EditorMenuPresenter.buildToolbar(
          anchors: anchors,
          items: items,
          controller: controller,
          labels: menuConfig.labels,
          actionConfiguration: actionConfig,
          hideMenu: _hideContextMenu,
          presentAsMobileToolbar: presentAsMobileToolbar,
        );
      },
    );
  }

  /// Toolbar IME / выделения: меню у [EditorMenuAnchor.selection].
  ///
  /// Вызывается из [EditorTextInputClient] при запросе системной панели над выделением.
  void _showSelectionToolbar() {
    final gutterW = widget.showGutter ? 48.0 : 0.0;
    final anchor = _selectionRectInGlobal(gutterW);
    if (anchor == null) return;
    unawaited(
      _showContextMenu(
        gutterW: gutterW,
        anchorKind: EditorMenuAnchor.selection,
        globalPointer: anchor.center,
      ),
    );
  }

  /// ПКМ (desktop): контекстное меню у [details.globalPosition].
  void _onSecondaryTapDown(
    TapDownDetails details,
    EditorController controller,
    double gutterW,
  ) {
    _handlePointerContextMenu(details.globalPosition, controller, gutterW);
  }

  /// Long-press на touch/stylus: то же меню, что и ПКМ.
  void _onLongPressStart(
    LongPressStartDetails details,
    EditorController controller,
    double gutterW,
  ) {
    if (!_isTouchLikePointer(_primaryDownPointerKind)) return;
    _handlePointerContextMenu(details.globalPosition, controller, gutterW);
  }

  /// ПКМ или long-press: каретка к точке клика (если нужно), меню у указателя.
  void _handlePointerContextMenu(
    Offset globalPosition,
    EditorController controller,
    double gutterW,
  ) {
    _resetMultiClick();
    controller.focusNode.unfocus();
    final selectionForMenu = controller.selection;
    final offset = _offsetFromGlobal(globalPosition, gutterW);
    if (offset != null) {
      _prepareSelectionForPointerMenu(controller, offset);
    }
    unawaited(
      _showContextMenu(
        gutterW: gutterW,
        anchorKind: EditorMenuAnchor.pointer,
        globalPointer: globalPosition,
        selectionForMenu: selectionForMenu,
      ),
    );
  }

  /// Инициализирует [GlyphCache] и начальный [LineLayout].
  void _initLayout() {
    final theme = widget.controller.theme;
    _glyphCache = GlyphCache(
      fontFamily: theme.fontFamily,
      fontSize: theme.fontSize,
    );
    _lineLayout = _buildLineLayout(wrapWidth: _wrapWidthForViewport(0));
  }

  /// Возвращает ширину переноса, когда word wrap включён и ширина viewport положительна.
  double? _wrapWidthForViewport(double viewportTextWidth) {
    if (!_wordWrap || viewportTextWidth <= 0) return null;
    return viewportTextWidth;
  }

  /// Строит [LineLayout] с текущим документом, resolver, inlay и шириной переноса.
  LineLayout _buildLineLayout({required double? wrapWidth}) {
    final theme = widget.controller.theme;
    return LineLayout(
      document: widget.controller.document,
      resolver: widget.controller.resolver,
      glyphCache: _glyphCache,
      theme: theme,
      inlays: widget.controller.inlayHints,
      wrapWidth: wrapWidth,
    );
  }

  /// Синхронизирует [ViewportState.scrollOffset] с фактической высотой контента.
  ///
  /// Вызывается после правок, меняющих высоту документа, и в [build], чтобы
  /// clip в [EditorLayersPainter] совпадал с [ScrollController].
  void _clampViewportScrollToContent() {
    final controller = widget.controller;
    final theme = controller.theme;
    final contentHeight = _lineLayout.totalHeight(
      controller.document.lineCount,
      theme.lineHeight,
    );
    controller.viewport.clampScrollOffsetToContentHeight(
      contentHeight,
      lineHeightPx: theme.lineHeightPx,
    );
  }

  /// Зажимает [ScrollController], если [ViewportState] уже скорректирован.
  void _syncScrollControllersFromViewport() {
    final offset = widget.controller.viewport.scrollOffset;
    if (_verticalScroll.hasClients && _verticalScroll.offset != offset) {
      _verticalScroll.jumpTo(offset);
    }
  }

  /// Передаёт видимый диапазон в [EditorController] для viewport-aware syntax.
  void _syncStyleViewport({bool notify = true}) {
    final controller = widget.controller;
    final scope = controller.computeStyleViewportScope();
    if (scope == controller.styleViewport) return;
    controller.updateStyleViewport(scope, notify: notify);
    if (!notify) {
      _lineLayout
        ..updateResolver(controller.resolver)
        ..updateInlays(controller.inlayHints)
        ..invalidate(fromLine: scope.firstLine);
    }
  }

  String _caretSignature(EditorController controller) {
    final buf = StringBuffer();
    for (final sel in controller.selection.selections) {
      if (sel.isCollapsed) buf.write('${sel.head};');
    }
    return buf.toString();
  }

  void _syncCaretBlink({bool recordActivity = false}) {
    final controller = widget.controller;
    _caretBlink.syncWithCachedTheme(
      focused: controller.focusNode.hasFocus,
      hasCollapsedCaret: controller.selection.selections.any(
        (s) => s.isCollapsed,
      ),
      compositionActive: controller.compositionRange != null,
      theme: controller.theme.caretBlink,
      recordActivity: recordActivity,
    );
  }

  /// Инкрементально обновляет layout при правке; при смене только каретки — только repaint.
  void _onControllerChanged() {
    final controller = widget.controller;
    final caretSig = _caretSignature(controller);
    final caretMoved = caretSig != _trackedCaretSignature;
    _trackedCaretSignature = caretSig;
    final docEdited = controller.document.version != _trackedDocVersion;
    _syncCaretBlink(recordActivity: docEdited || caretMoved);

    final gutterW = widget.showGutter ? 48.0 : 0.0;
    final vw = controller.viewport.viewportWidth - gutterW;
    final wrapWidth = _wrapWidthForViewport(vw);

    if (_lineLayout.wrapWidth != wrapWidth) {
      _lineLayout = _buildLineLayout(wrapWidth: wrapWidth);
      _trackedDocVersion = controller.document.version;
      _trackedResolver = controller.resolver;
      _trackedStyleEpoch = controller.resolver.styleEpoch;
      _trackedInlayCount = controller.inlayHints.length;
    } else {
      final doc = controller.document;
      if (doc.version != _trackedDocVersion) {
        _trackedDocVersion = doc.version;
        _trackedResolver = controller.resolver;
        _trackedStyleEpoch = controller.resolver.styleEpoch;
        _trackedInlayCount = controller.inlayHints.length;
        final change = controller.lastChange;
        final fromLine = change?.affectedFirstLine ?? 0;
        final toLine = change?.affectedLastLine;
        _lineLayout
          ..updateResolver(
            controller.resolver,
            invalidateAttributedFromLine: fromLine,
          )
          ..updateInlays(controller.inlayHints)
          ..invalidate(fromLine: fromLine)
          ..invalidateHeightCache(fromLine: fromLine)
          ..invalidateMaxWidthCache(fromLine: fromLine, toLine: toLine)
          ..truncateToLineCount(doc.lineCount);
        _clampViewportScrollToContent();
        _syncScrollControllersFromViewport();
      } else if (controller.resolver.styleEpoch != _trackedStyleEpoch) {
        _trackedStyleEpoch = controller.resolver.styleEpoch;
        _trackedResolver = controller.resolver;
        _trackedInlayCount = controller.inlayHints.length;
        _lineLayout
          ..updateResolver(controller.resolver)
          ..updateInlays(controller.inlayHints);
      } else if (!identical(_trackedResolver, controller.resolver)) {
        _trackedResolver = controller.resolver;
        _trackedStyleEpoch = controller.resolver.styleEpoch;
        _trackedInlayCount = controller.inlayHints.length;
        _lineLayout
          ..updateResolver(controller.resolver)
          ..updateInlays(controller.inlayHints);
      } else if (controller.inlayHints.length != _trackedInlayCount) {
        _trackedInlayCount = controller.inlayHints.length;
        _lineLayout.updateInlays(controller.inlayHints);
      }
    }

    if (_textInputConnection != null) {
      _syncPlatformTextInput();
    }
    final reveal = controller.consumePendingReveal();
    if (reveal != null) {
      _scrollToOffset(reveal, gutterW);
    }
    _syncStyleViewport(notify: false);

    if (_canRepaintWithoutSetState(controller)) {
      _repaintEditorSurface();
    } else if (controller.lastChange == null) {
      // Link hover, каретка, IME preedit — без пересчёта layout.
      _repaintEditorSurface();
      setState(_rebuildFromController);
    } else {
      setState(_rebuildFromController);
    }
  }

  /// Правка только сдвинула текст/стили; размеры scroll surface не меняются.
  bool _canRepaintWithoutSetState(EditorController controller) {
    final change = controller.lastChange;
    if (change == null) return false;
    if (change.insertedText.contains('\n') ||
        change.insertedText.length > 32 ||
        change.removedLength > 32) {
      return false;
    }
    if (change.affectedFirstLine != change.affectedLastLine) return false;
    if (_lineLayout.wrapWidth != null &&
        _lineLayout.wrapWidth!.isFinite &&
        _lineLayout.wrapWidth! > 0) {
      return false;
    }
    return true;
  }

  void _repaintEditorSurface() {
    final ro = _editorPaintKey.currentContext?.findRenderObject();
    if (ro is RenderCustomPaint) ro.markNeedsPaint();
  }

  void _scrollToOffset(TextOffset offset, double gutterW) {
    final controller = widget.controller;
    final theme = controller.theme;
    final boxes = _lineLayout.getBoxesForRange(
      Range(offset, offset),
      theme.lineHeight,
    );
    if (boxes.isEmpty) return;
    controller.viewport.ensureOffsetVisible(
      boxes.first.top,
      theme.lineHeightPx,
      padding: theme.lineHeightPx,
    );
    if (_verticalScroll.hasClients) {
      _verticalScroll.jumpTo(controller.viewport.scrollOffset);
    }
    if (!_wordWrap && _horizontalScroll.hasClients) {
      final left = gutterW + boxes.first.left;
      final right = gutterW + boxes.first.right;
      final viewW = controller.viewport.viewportWidth;
      if (left < _horizontalScroll.offset) {
        _horizontalScroll.jumpTo(left > 8 ? left - 8 : 0);
      } else if (right > _horizontalScroll.offset + viewW) {
        _horizontalScroll.jumpTo(right - viewW + 8);
      }
    }
  }

  void _updateLinkHoverAtGlobal(Offset global, double gutterW) {
    if (!linkModifierPressed()) {
      widget.controller.clearLinkHover();
      return;
    }
    final offset = _offsetFromGlobal(global, gutterW);
    widget.controller.updateLinkHover(offset);
  }

  void _onPointerHover(PointerHoverEvent event, double gutterW) {
    _lastHoverGlobal = event.position;
    _updateLinkHoverAtGlobal(event.position, gutterW);
  }

  void _onPointerExitHover() {
    _lastHoverGlobal = null;
    widget.controller.clearLinkHover();
  }

  /// Заглушка для будущих инкрементальных оптимизаций перестроения.
  void _rebuildFromController() {
    return;
  }

  /// Синхронизирует [ViewportState.scrollOffset] и [ViewportState.firstVisibleLine].
  void _onVerticalScroll() {
    final offset = _verticalScroll.offset;
    final theme = widget.controller.theme;
    widget.controller.viewport.scrollOffset = offset;
    widget.controller.viewport.firstVisibleLine = _lineLayout
        .lineIndexForDocumentY(offset, theme.lineHeight);
    _syncStyleViewport(notify: false);
    final connection = _textInputConnection;
    if (connection != null) {
      _updateTextInputGeometry(connection);
    }
  }

  /// Синхронизирует горизонтальное смещение прокрутки для строк без переноса.
  void _onHorizontalScroll() {
    widget.controller.viewport.scrollOffsetX = _horizontalScroll.offset;
    final connection = _textInputConnection;
    if (connection != null) {
      _updateTextInputGeometry(connection);
    }
  }

  /// Отписывается от контроллера и освобождает scroll/IME-ресурсы.
  @override
  void dispose() {
    _unregisterLinkModifierHandler();
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.focusNode.removeListener(_onFocusChanged);
    _textInputConnection?.close();
    _clipboardStatus.dispose();
    _contextMenuController.remove();
    _selectionAutoscroll.dispose();
    _caretBlink.dispose();
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  DocumentPointerMapper _pointerMapper(double gutterW) => DocumentPointerMapper(
    lineLayout: _lineLayout,
    document: widget.controller.document,
    theme: widget.controller.theme,
    gutterWidth: gutterW,
  );

  TextOffset? _offsetFromGlobal(Offset global, double gutterW) {
    final box = _surfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return _pointerMapper(
      gutterW,
    ).surfaceLocalToOffset(box.globalToLocal(global));
  }

  void _onSelectionAutoscrollTick(double deltaY, double deltaX) {
    if (deltaY != 0 && _verticalScroll.hasClients) {
      final max = _verticalScroll.position.maxScrollExtent;
      final next = (_verticalScroll.offset + deltaY).clamp(0.0, max);
      if (next != _verticalScroll.offset) {
        _verticalScroll.jumpTo(next);
      }
    }
    if (deltaX != 0 && !_wordWrap && _horizontalScroll.hasClients) {
      final max = _horizontalScroll.position.maxScrollExtent;
      final next = (_horizontalScroll.offset + deltaX).clamp(0.0, max);
      if (next != _horizontalScroll.offset) {
        _horizontalScroll.jumpTo(next);
      }
    }
    final global = _lastGlobalPointer;
    final anchor = _selectionDragAnchor;
    if (_selectionDragActive && global != null && anchor != null) {
      _applySelectionHead(global, anchor, widget.showGutter ? 48.0 : 0.0);
    }
  }

  void _updateSelectionAutoscroll(Offset global) {
    final vpBox = _viewportKey.currentContext?.findRenderObject();
    if (vpBox is! RenderBox || !vpBox.hasSize) {
      _selectionAutoscroll.updatePointerInViewport(null);
      return;
    }
    _selectionAutoscroll.updatePointerInViewport(vpBox.globalToLocal(global));
  }

  void _applySelectionHead(Offset global, TextOffset anchor, double gutterW) {
    final head = _offsetFromGlobal(global, gutterW);
    if (head == null) return;

    final frozen = _frozenMultiClickRange;
    if (_freezeMultiClickSelection && frozen != null) {
      // Синтетический move при double-click часто > slop, но head остаётся в слове.
      if (head >= frozen.start && head <= frozen.end) return;
      _freezeMultiClickSelection = false;
      _frozenMultiClickRange = null;
    }

    widget.controller.setPrimarySelection(Selection(anchor, head));
  }

  void _endSelectionDrag() {
    _selectionDragActive = false;
    _selectionDragAnchor = null;
    _lastGlobalPointer = null;
    _dragDownGlobal = null;
    _dragExtendHead = false;
    _freezeMultiClickSelection = false;
    _frozenMultiClickRange = null;
    _primaryHeld = false;
    _downsWhileHeld = 0;
    _selectionAutoscroll.updatePointerInViewport(null);
  }

  bool _isTouchLikePointer(PointerDeviceKind? kind) =>
      kind == PointerDeviceKind.touch ||
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;

  void _onPointerDown(
    PointerDownEvent event,
    EditorController controller,
    double gutterW,
  ) {
    if (event.buttons != kPrimaryButton) return;

    _primaryDownPointerKind = event.kind;
    controller.focusNode.requestFocus();
    _hideContextMenu();

    final offset = _offsetFromGlobal(event.position, gutterW);
    if (offset == null) return;

    if (linkModifierPressed()) {
      unawaited(_onLinkModifierPointerDown(controller, offset, event, gutterW));
      return;
    }

    if (HardwareKeyboard.instance.isAltPressed) {
      _endSelectionDrag();
      _resetMultiClick();
      controller.addCursorAt(offset);
      return;
    }

    if (_primaryHeld) {
      _downsWhileHeld++;
      _handleChordedTapDown(controller, offset);
    } else {
      if (_shouldIgnoreSpuriousPointerDown()) return;
      _downsWhileHeld = 1;
      _handleTapDownAtOffset(controller, offset);
    }
    _primaryHeld = true;

    _freezeMultiClickSelection = _clickCount >= 2;
    if (_freezeMultiClickSelection) {
      final primary = controller.selection.primary;
      _frozenMultiClickRange = primary.isCollapsed ? null : primary.range;
    } else {
      _frozenMultiClickRange = null;
    }
    _selectionDragAnchor = controller.selection.primary.anchor;
    _selectionDragActive = true;
    _lastGlobalPointer = event.position;
    _dragDownGlobal = event.position;
    _dragExtendHead = _clickCount == 1;
    if (_dragExtendHead) {
      _applySelectionHead(event.position, _selectionDragAnchor!, gutterW);
    }
    _updateSelectionAutoscroll(event.position);
  }

  bool _pointerMovedPastDragSlop(Offset global) {
    final down = _dragDownGlobal;
    if (down == null) return false;
    return (global - down).distance > _dragExtendSlop;
  }

  void _onPointerMove(PointerMoveEvent event, double gutterW) {
    _lastHoverGlobal = event.position;
    if (linkModifierPressed()) {
      _updateLinkHoverAtGlobal(event.position, gutterW);
    }
    if (!_selectionDragActive) return;
    if ((event.buttons & kPrimaryButton) == 0) {
      _endSelectionDrag();
      return;
    }

    _lastGlobalPointer = event.position;
    final anchor = _selectionDragAnchor;
    if (anchor == null) return;

    if (!_freezeMultiClickSelection && !_dragExtendHead) {
      if (!_pointerMovedPastDragSlop(event.position)) return;
      _dragExtendHead = true;
    }

    _applySelectionHead(event.position, anchor, gutterW);
    _updateSelectionAutoscroll(event.position);
  }

  /// Ctrl/Cmd+клик: переход, если есть цель; иначе обычный клик по каретке.
  Future<void> _onLinkModifierPointerDown(
    EditorController controller,
    TextOffset offset,
    PointerDownEvent event,
    double gutterW,
  ) async {
    if (await controller.followLinkAt(offset)) {
      if (!mounted) return;
      _endSelectionDrag();
      _resetMultiClick();
      _hideContextMenu();
      return;
    }
    if (!mounted) return;
    _continuePrimaryPointerDown(controller, offset, event, gutterW);
  }

  void _continuePrimaryPointerDown(
    EditorController controller,
    TextOffset offset,
    PointerDownEvent event,
    double gutterW,
  ) {
    if (HardwareKeyboard.instance.isAltPressed) {
      _endSelectionDrag();
      _resetMultiClick();
      controller.addCursorAt(offset);
      return;
    }

    if (_primaryHeld) {
      _downsWhileHeld++;
      _handleChordedTapDown(controller, offset);
    } else {
      if (_shouldIgnoreSpuriousPointerDown()) return;
      _downsWhileHeld = 1;
      _handleTapDownAtOffset(controller, offset);
    }
    _primaryHeld = true;

    _freezeMultiClickSelection = _clickCount >= 2;
    if (_freezeMultiClickSelection) {
      final primary = controller.selection.primary;
      _frozenMultiClickRange = primary.isCollapsed ? null : primary.range;
    } else {
      _frozenMultiClickRange = null;
    }
    _selectionDragAnchor = controller.selection.primary.anchor;
    _selectionDragActive = true;
    _lastGlobalPointer = event.position;
    _dragDownGlobal = event.position;
    _dragExtendHead = _clickCount == 1;
    if (_dragExtendHead) {
      _applySelectionHead(event.position, _selectionDragAnchor!, gutterW);
    }
    _updateSelectionAutoscroll(event.position);
  }

  void _onPointerUp(PointerEvent event) {
    _primaryDownPointerKind = null;
    _primaryHeld = false;
    _downsWhileHeld = 0;
    _endSelectionDrag();
  }

  bool _shouldIgnoreSpuriousPointerDown() {
    final until = _blockNewClickSequenceUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  void _markMultiClickCompleted() {
    _blockNewClickSequenceUntil = DateTime.now().add(
      const Duration(milliseconds: 200),
    );
  }

  /// 2-й down без up → слово; 3-й → строка (как VS Code, без сброса в collapsed).
  void _handleChordedTapDown(EditorController controller, TextOffset offset) {
    _lastClickTime = DateTime.now();
    _lastClickOffset = offset;
    _clickCount = _downsWhileHeld;

    switch (_downsWhileHeld) {
      case 2:
        _selectWordAt(controller, offset);
        _markMultiClickCompleted();
      case 3:
        _selectLineAt(controller, offset);
        _markMultiClickCompleted();
      case 4:
        controller.setPrimarySelection(
          Selection(0, controller.document.length),
        );
        _markMultiClickCompleted();
      default:
        break;
    }
  }

  /// Общая высота содержимого по числу строк и визуальному переносу.
  double get _contentHeight {
    final theme = widget.controller.theme;
    return _lineLayout.totalHeight(
      widget.controller.document.lineCount,
      theme.lineHeight,
    );
  }

  /// Ширина содержимого с учётом overflow inline «призрачных» диагностических сообщений.
  ///
  /// Сравнивает [LineLayout.maxLinePaintWidth] с шириной каждой строки плюс
  /// ширина inline-сообщения диагностики; возвращает не меньше [viewportTextWidth].
  double _paintWidth(double viewportTextWidth) {
    var maxW = _lineLayout.maxLinePaintWidth();
    final theme = widget.controller.theme;
    final inlineByLine = {
      for (final label in widget.controller.inlineDiagnosticLabels)
        label.documentLine: label,
    };

    for (final entry in inlineByLine.entries) {
      if (entry.key < 0 || entry.key >= widget.controller.document.lineCount) {
        continue;
      }
      final visuals = _lineLayout.visualLinesForDocumentLine(entry.key);
      if (visuals.isEmpty) continue;
      final lineW =
          visuals.last.width +
          _inlineDiagnosticWidth(entry.value.message, theme);
      if (lineW > maxW) maxW = lineW;
    }

    if (viewportTextWidth > maxW) return viewportTextWidth;
    return maxW;
  }

  /// Измеряет ширину курсивного «призрачного» текста диагностики для расчёта прокрутки.
  double _inlineDiagnosticWidth(String message, EditorTheme theme) {
    final gap = _glyphCache.measureText('  ');
    final painter = layoutRunPainter(
      text: ' $message',
      style: TextStyle(
        fontSize: theme.fontSize,
        fontFamily: theme.fontFamily,
        fontStyle: FontStyle.italic,
      ),
    );
    return gap + painter.width;
  }

  /// Multi-click как в VS Code (счётчик на каждом pointer down).
  void _handleTapDownAtOffset(EditorController controller, TextOffset offset) {
    if (HardwareKeyboard.instance.isAltPressed) {
      _resetMultiClick();
      controller.addCursorAt(offset);
      return;
    }

    final doc = controller.document;
    if (_continuesMultiClick(doc, offset)) {
      _clickCount++;
    } else {
      _clickCount = 1;
    }
    _lastClickTime = DateTime.now();
    _lastClickOffset = offset;

    switch (_clickCount) {
      case 1:
        controller.setSingleCursor(offset);
      case 2:
        _selectWordAt(controller, offset);
        _markMultiClickCompleted();
      case 3:
        _selectLineAt(controller, offset);
        _markMultiClickCompleted();
      default:
        final len = doc.length;
        controller.setPrimarySelection(Selection(0, len));
        _markMultiClickCompleted();
    }
  }

  void _resetMultiClick() {
    _clickCount = 0;
    _lastClickTime = null;
    _lastClickOffset = null;
  }

  /// Продолжение цепочки: тот же документ и строка, интервал ≤ [_multiClickWindow].
  bool _continuesMultiClick(Document doc, TextOffset offset) {
    if (_lastClickTime == null || _lastClickOffset == null) return false;
    if (offset >= doc.length || _lastClickOffset! >= doc.length) return false;
    if (DateTime.now().difference(_lastClickTime!) >= _multiClickWindow) {
      return false;
    }
    return doc.positionAt(_lastClickOffset!).line ==
        doc.positionAt(offset).line;
  }

  /// Выделяет слово по [wordRangeAt] или ставит каретку, если слова нет.
  void _selectWordAt(EditorController controller, TextOffset offset) {
    final range = wordRangeAt(controller.document.text, offset);
    if (range == null) {
      controller.setSingleCursor(offset);
      return;
    }
    controller.setPrimarySelection(Selection(range.start, range.end));
  }

  /// Выделяет логическую строку (включая символ перевода строки).
  void _selectLineAt(EditorController controller, TextOffset offset) {
    final line = controller.document.positionAt(offset).line;
    final range = controller.document.getLineRange(line);
    controller.setPrimarySelection(Selection(range.start, range.end));
  }

  /// Строит [CustomPaint], gesture detector и scroll view с [Scrollbar].
  Widget _buildEditorSurface({
    required BuildContext context,
    required EditorController controller,
    required double gutterW,
    required double childWidth,
    required double contentHeight,
  }) {
    final thumbVisible = _desktopScrollbarThumbVisible(context);
    final repaintListenable = _wordWrap
        ? Listenable.merge([controller, _verticalScroll, _caretBlink])
        : Listenable.merge([
            controller,
            _verticalScroll,
            _horizontalScroll,
            _caretBlink,
          ]);

    final paint = CustomPaint(
      key: _editorPaintKey,
      painter: EditorLayersPainter(
        controller: controller,
        lineLayout: _lineLayout,
        glyphCache: _glyphCache,
        caretBlink: _caretBlink,
        showGutter: widget.showGutter,
        gutterWidth: gutterW,
        repaint: repaintListenable,
      ),
      size: Size(childWidth, contentHeight),
    );

    final surface = MouseRegion(
      cursor: controller.hasActiveLink
          ? SystemMouseCursors.click
          : SystemMouseCursors.text,
      onExit: (_) => _onPointerExitHover(),
      child: GestureDetector(
        key: _surfaceKey,
        onSecondaryTapDown: (d) => _onSecondaryTapDown(d, controller, gutterW),
        onLongPressStart: (d) => _onLongPressStart(d, controller, gutterW),
        child: paint,
      ),
    );

    final scrollChild = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _onPointerDown(e, controller, gutterW),
      onPointerMove: (e) => _onPointerMove(e, gutterW),
      onPointerHover: (e) => _onPointerHover(e, gutterW),
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: SizedBox(height: contentHeight, width: childWidth, child: surface),
    );

    if (_wordWrap) {
      return KeyedSubtree(
        key: _viewportKey,
        child: Scrollbar(
          controller: _verticalScroll,
          thumbVisibility: thumbVisible,
          interactive: true,
          child: SingleChildScrollView(
            controller: _verticalScroll,
            child: scrollChild,
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: _viewportKey,
      child: Scrollbar(
        controller: _verticalScroll,
        thumbVisibility: thumbVisible,
        interactive: true,
        child: SingleChildScrollView(
          controller: _verticalScroll,
          child: Scrollbar(
            controller: _horizontalScroll,
            thumbVisibility: thumbVisible,
            interactive: true,
            notificationPredicate: (n) => n.depth == 1,
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              child: scrollChild,
            ),
          ),
        ),
      ),
    );
  }

  /// [Focus] + [LayoutBuilder] + scroll surface с пересчётом wrap width.
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final gutterW = widget.showGutter ? 48.0 : 0.0;

    return Focus(
      focusNode: controller.focusNode,
      skipTraversal: _contextMenuOpen,
      canRequestFocus: !_contextMenuOpen,
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          controller.viewport
            ..viewportWidth = constraints.maxWidth
            ..viewportHeight = constraints.maxHeight;
          _syncStyleViewport(notify: false);
          final viewportTextWidth = constraints.maxWidth - gutterW;
          final wrapWidth = _wrapWidthForViewport(viewportTextWidth);
          if (_lineLayout.wrapWidth != wrapWidth) {
            _lineLayout = _buildLineLayout(wrapWidth: wrapWidth);
          }

          final paintWidth = _paintWidth(viewportTextWidth);
          final childWidth = paintWidth + gutterW;
          final contentHeight = _contentHeight;
          controller.viewport.clampScrollOffsetToContentHeight(
            contentHeight,
            lineHeightPx: controller.theme.lineHeightPx,
          );
          if (_verticalScroll.hasClients &&
              _verticalScroll.offset != controller.viewport.scrollOffset) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _syncScrollControllersFromViewport();
            });
          }

          return _buildEditorSurface(
            context: context,
            controller: controller,
            gutterW: gutterW,
            childWidth: childWidth,
            contentHeight: contentHeight,
          );
        },
      ),
    );
  }
}
