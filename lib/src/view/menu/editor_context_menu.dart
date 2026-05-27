import 'dart:async';

import 'package:editor/src/api/editor_action.dart';
import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/api/editor_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Презентация списка [EditorMenuItem] во всплывающем UI.
///
/// Два режима отрисовки:
///
/// - **Mobile** ([presentAsMobileToolbar] == `true`): [AdaptiveTextSelectionToolbar.buttonItems]
///   с платформенными [ContextMenuButtonType] для cut/copy/paste/selectAll.
/// - **Desktop**: вертикальный список [MenuItemButton] с единым hit-test и клавиатурной навигацией.
///
/// Общая оболочка [buildToolbar]:
///
/// - полноэкранный прозрачный [Listener] закрывает меню по клику снаружи;
/// - [FocusScope] с циклическим обходом пунктов (Tab, стрелки, Escape);
/// - после mount фокус переносится на первый пункт ([_MenuFocusBootstrap]).
abstract final class EditorMenuPresenter {
  EditorMenuPresenter._();

  /// Прямоугольник якоря для toolbar у координат указателя.
  ///
  /// Центр по X совпадает с [globalPointer]; минимальная ширина 48 px,
  /// чтобы [TextSelectionToolbarAnchors] не смещали панель слишком далеко от курсора.
  static Rect pointerAnchorRect(Offset globalPointer, double lineHeight) {
    const minWidth = 48.0;
    return Rect.fromLTWH(
      globalPointer.dx - minWidth / 2,
      globalPointer.dy - lineHeight / 2,
      minWidth,
      lineHeight,
    );
  }

  /// Верхний и нижний якоря для [AdaptiveTextSelectionToolbar] относительно [anchorRect].
  static TextSelectionToolbarAnchors toolbarAnchors(Rect anchorRect) =>
      TextSelectionToolbarAnchors(
        primaryAnchor: Offset(anchorRect.center.dx, anchorRect.top),
        secondaryAnchor: Offset(anchorRect.center.dx, anchorRect.bottom),
      );

  /// Строит overlay меню или [SizedBox.shrink], если [items] пуст после фильтрации.
  ///
  /// [hideMenu] вызывается при клике вне toolbar и после выбора пункта.
  ///
  /// [actionConfiguration] — реестр для [EditorActions.perform]. Фильтрация
  /// [EditorActionConfiguration.disabledActions] выполняется при сборке [items]
  /// ([EditorMenuDefaults.standardItems]); произвольные пункты в [items] presenter
  /// не отфильтровывает.
  static Widget buildToolbar({
    required TextSelectionToolbarAnchors anchors,
    required List<EditorMenuItem> items,
    required EditorController controller,
    required EditorActionLabels labels,
    required VoidCallback hideMenu,
    required bool presentAsMobileToolbar,
    EditorActionConfiguration actionConfiguration =
        const EditorActionConfiguration(),
  }) {
    final toolbar = presentAsMobileToolbar
        ? _mobileToolbar(
            anchors: anchors,
            items: items,
            controller: controller,
            hideMenu: hideMenu,
            actionConfiguration: actionConfiguration,
          )
        : _desktopToolbar(
            anchors: anchors,
            items: items,
            controller: controller,
            labels: labels,
            hideMenu: hideMenu,
            actionConfiguration: actionConfiguration,
          );

    if (toolbar == null) return const SizedBox.shrink();

    // OverlayEntry иначе сжимается до размера toolbar — клики «снаружи» не ловятся.
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => hideMenu(),
          ),
          _menuFocusScope(hideMenu: hideMenu, child: toolbar),
        ],
      ),
    );
  }

  /// Оборачивает [child] в цепочку фокуса контекстного меню.
  ///
  /// Снизу вверх: [_EditorMenuFocusScope] → [_MenuFocusBootstrap] → [Shortcuts] →
  /// [Actions] → [FocusTraversalGroup] с [OrderedTraversalPolicy].
  /// Tab и стрелки двигают фокус между [MenuItemButton]; Escape обрабатывается
  /// на scope через [_handleMenuScopeKey].
  static Widget _menuFocusScope({
    required VoidCallback hideMenu,
    required Widget child,
  }) => _EditorMenuFocusScope(
    hideMenu: hideMenu,
    child: _MenuFocusBootstrap(
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.tab, shift: true):
              PreviousFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
            TraversalDirection.down,
          ),
          SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
            TraversalDirection.up,
          ),
          SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
            TraversalDirection.left,
          ),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              DirectionalFocusIntent(TraversalDirection.right),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            NextFocusIntent: NextFocusAction(),
            PreviousFocusIntent: PreviousFocusAction(),
            DirectionalFocusIntent: DirectionalFocusAction(),
          },
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: child,
          ),
        ),
      ),
    ),
  );

  /// Обработчик [FocusScopeNode.onKeyEvent] для overlay меню.
  ///
  /// Обрабатывает только [KeyDownEvent] и [KeyRepeatEvent]. Escape вызывает
  /// [hideMenu] и возвращает [KeyEventResult.handled]; остальные клавиши
  /// ([KeyEventResult.ignored]) проходят к [Shortcuts] ниже по дереву.
  static KeyEventResult _handleMenuScopeKey(
    KeyEvent event,
    VoidCallback hideMenu,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      hideMenu();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Горизонтальный toolbar для Android/iOS.
  ///
  /// Возвращает `null`, если после [_contextMenuButtons] не осталось кнопок
  /// (например, только undo/redo, не мапящиеся на [ContextMenuButtonType]).
  static Widget? _mobileToolbar({
    required TextSelectionToolbarAnchors anchors,
    required List<EditorMenuItem> items,
    required EditorController controller,
    required VoidCallback hideMenu,
    required EditorActionConfiguration actionConfiguration,
  }) {
    final buttons = _contextMenuButtons(
      items: items,
      controller: controller,
      hideMenu: hideMenu,
      actionConfiguration: actionConfiguration,
    );
    if (buttons.isEmpty) return null;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: buttons,
    );
  }

  /// Вертикальное меню для desktop/web.
  ///
  /// Список дочерних виджетов строит [_desktopWidgets]; `null`, если пунктов нет.
  static Widget? _desktopToolbar({
    required TextSelectionToolbarAnchors anchors,
    required List<EditorMenuItem> items,
    required EditorController controller,
    required EditorActionLabels labels,
    required VoidCallback hideMenu,
    required EditorActionConfiguration actionConfiguration,
  }) {
    final children = _desktopWidgets(
      items: items,
      controller: controller,
      labels: labels,
      hideMenu: hideMenu,
      actionConfiguration: actionConfiguration,
    );
    if (children.isEmpty) return null;
    return AdaptiveTextSelectionToolbar(anchors: anchors, children: children);
  }

  /// Преобразует [EditorStandardMenuItem] в [ContextMenuButtonItem].
  ///
  /// Пропускает disabled, custom и divider. Действия без [_buttonType]
  /// (undo, redo, кастомные id) в mobile toolbar не попадают.
  static List<ContextMenuButtonItem> _contextMenuButtons({
    required List<EditorMenuItem> items,
    required EditorController controller,
    required VoidCallback hideMenu,
    required EditorActionConfiguration actionConfiguration,
  }) {
    final result = <ContextMenuButtonItem>[];
    for (final item in items) {
      if (item is! EditorStandardMenuItem || !item.enabled) continue;
      final type = _buttonType(item.action);
      if (type == null) continue;
      result.add(
        ContextMenuButtonItem(
          type: type,
          onPressed: () => _onStandard(
            controller,
            item.action,
            hideMenu,
            actionConfiguration: actionConfiguration,
          ),
        ),
      );
    }
    return result;
  }

  /// Собирает дочерние виджеты для [AdaptiveTextSelectionToolbar] на десктопе.
  ///
  /// Использует единые [MenuItemButton] через [_MenuItemFocus] (стабильный hit-test
  /// вместо смеси platform-кнопок). [traversalOrder] задаёт порядок Tab/стрелок.
  /// Disabled-пункты не добавляются; [EditorMenuDividerItem] — только между группами.
  static List<Widget> _desktopWidgets({
    required List<EditorMenuItem> items,
    required EditorController controller,
    required EditorActionLabels labels,
    required VoidCallback hideMenu,
    required EditorActionConfiguration actionConfiguration,
  }) {
    final widgets = <Widget>[];
    var traversalOrder = 0.0;

    for (final item in items) {
      switch (item) {
        case EditorMenuDividerItem():
          if (widgets.isNotEmpty) widgets.add(const Divider(height: 1));
        case EditorStandardMenuItem(:final action, :final enabled, :final label)
            when enabled:
          widgets.add(
            _MenuItemFocus(
              order: traversalOrder++,
              onPressed: () => _onStandard(
                controller,
                action,
                hideMenu,
                actionConfiguration: actionConfiguration,
              ),
              label: Text(label ?? labels.labelFor(action)),
            ),
          );
        case EditorStandardMenuItem():
          break;
        case EditorCustomMenuItem(
              :final label,
              :final onPressed,
              :final enabled,
              :final actionId,
            )
            when enabled:
          widgets.add(
            _MenuItemFocus(
              order: traversalOrder++,
              onPressed: () {
                if (actionId != null) {
                  unawaited(controller.performCustom(actionId));
                } else {
                  onPressed();
                }
                hideMenu();
              },
              label: Text(label),
            ),
          );
        case EditorCustomMenuItem():
          break;
      }
    }
    return widgets;
  }

  /// Выполняет стандартное [EditorActionId] и закрывает меню.
  ///
  /// Вызов [EditorActions.perform] асинхронный ([unawaited]); [hideMenu]
  /// вызывается сразу после постановки задачи.
  static void _onStandard(
    EditorController controller,
    EditorActionId action,
    VoidCallback hideMenu, {
    required EditorActionConfiguration actionConfiguration,
  }) {
    unawaited(
      EditorActions.perform(
        EditorActionContext(controller: controller),
        EditorActionInvocation(action),
        registry: actionConfiguration.registry ?? controller.actionRegistry,
      ),
    );
    hideMenu();
  }

  /// Соответствие [EditorActionId] типу кнопки Material toolbar.
  ///
  /// `null` — действие не показывается в [AdaptiveTextSelectionToolbar.buttonItems]
  /// (undo/redo и неизвестные id).
  static ContextMenuButtonType? _buttonType(EditorActionId action) =>
      switch (action) {
        EditorActionId.cut => ContextMenuButtonType.cut,
        EditorActionId.copy => ContextMenuButtonType.copy,
        EditorActionId.paste => ContextMenuButtonType.paste,
        EditorActionId.selectAll => ContextMenuButtonType.selectAll,
        EditorActionId.undo || EditorActionId.redo => null,
        _ => null,
      };
}

/// [FocusScope] контекстного меню.
///
/// [directionalTraversalEdgeBehavior] == [TraversalEdgeBehavior.closedLoop]:
/// со последнего пункта стрелка вниз переходит на первый. Escape закрывает меню
/// через [EditorMenuPresenter._handleMenuScopeKey].
final class _EditorMenuFocusScope extends StatefulWidget {
  const _EditorMenuFocusScope({required this.hideMenu, required this.child});

  /// Закрытие меню по Escape (передаётся в [_handleMenuScopeKey]).
  final VoidCallback hideMenu;

  /// Toolbar или обёртка с пунктами меню.
  final Widget child;

  @override
  State<_EditorMenuFocusScope> createState() => _EditorMenuFocusScopeState();
}

final class _EditorMenuFocusScopeState extends State<_EditorMenuFocusScope> {
  /// Изолированный scope фокуса overlay; циклический обход по краям списка.
  late final FocusScopeNode _scopeNode = FocusScopeNode(
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );

  @override
  void initState() {
    super.initState();
    _scopeNode.onKeyEvent = (_, event) =>
        EditorMenuPresenter._handleMenuScopeKey(event, widget.hideMenu);
  }

  @override
  void dispose() {
    _scopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope.withExternalFocusNode(
    focusScopeNode: _scopeNode,
    child: widget.child,
  );
}

/// Обёртка [MenuItemButton] с собственным [FocusNode] и [NumericFocusOrder].
///
/// Один узел фокуса на пункт (совпадает с [MenuItemButton.focusNode]),
/// чтобы Tab/стрелки и клик мышью вели себя предсказуемо.
final class _MenuItemFocus extends StatefulWidget {
  const _MenuItemFocus({
    required this.order,
    required this.onPressed,
    required this.label,
  });

  /// Порядок в [OrderedTraversalPolicy] ([NumericFocusOrder]).
  final double order;

  /// Действие по активации пункта (Enter / клик).
  final VoidCallback onPressed;

  /// Подпись пункта ([Text] с локализованной строкой).
  final Widget label;

  @override
  State<_MenuItemFocus> createState() => _MenuItemFocusState();
}

final class _MenuItemFocusState extends State<_MenuItemFocus> {
  /// Отдельный узел на пункт — тот же экземпляр передаётся в [MenuItemButton.focusNode].
  late final FocusNode _node = FocusNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusTraversalOrder(
    order: NumericFocusOrder(widget.order),
    child: MenuItemButton(
      focusNode: _node,
      onPressed: widget.onPressed,
      child: widget.label,
    ),
  );
}

/// Запрашивает начальный фокус на первом пункте меню после появления overlay.
///
/// Autofocus у [FocusScope] в overlay часто не срабатывает; два post-frame callback
/// дают [ModalRoute] и [OverlayEntry] завершить mount до [OrderedTraversalPolicy.findFirstFocus].
final class _MenuFocusBootstrap extends StatefulWidget {
  const _MenuFocusBootstrap({required this.child});

  /// Поддерево меню внутри [Shortcuts] / [FocusTraversalGroup].
  final Widget child;

  @override
  State<_MenuFocusBootstrap> createState() => _MenuFocusBootstrapState();
}

final class _MenuFocusBootstrapState extends State<_MenuFocusBootstrap> {
  @override
  void initState() {
    super.initState();
    // Два кадра: overlay и ModalScope успевают отдать дерево до findFirstFocus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _requestInitialFocus(),
      );
    });
  }

  /// Переносит фокус на первый focusable потомок scope меню.
  ///
  /// Снимает фокус с предыдущего [FocusManager.primaryFocus] (часто редактор
  /// или modal route), затем [FocusNode.requestFocus] на [findFirstFocus].
  void _requestInitialFocus() {
    if (!mounted) return;

    final scopeNode = FocusScope.of(context);
    final policy = OrderedTraversalPolicy();
    final first = policy.findFirstFocus(scopeNode, ignoreCurrentFocus: true);

    if (first != null) {
      FocusManager.instance.primaryFocus?.unfocus();
      first.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
