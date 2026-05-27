import 'package:editor/src/api/editor_action.dart';
import 'package:editor/src/api/editor_controller.dart';
import 'package:flutter/widgets.dart';

/// Точка привязки всплывающего контекстного меню.
///
/// Влияет на прямоугольник якоря toolbar. Для [EditorMenuAnchor.pointer]
/// каретка может переноситься на точку клика до открытия меню
/// ([shouldMoveCaretForPointerMenu] в [EditorScrollable]).
enum EditorMenuAnchor {
  /// ПКМ или long-press: меню у координат указателя.
  pointer,

  /// Плавающая панель IME / selection handles: меню у каретки или выделения.
  selection,
}

/// Входные данные для [EditorMenuItemsBuilder].
///
/// Собирается в [EditorScrollable] перед вызовом [EditorMenuConfiguration.buildItems].
/// [capabilities] и [clipboardStatus] отражают состояние на момент открытия меню.
final class EditorMenuBuildContext {
  const EditorMenuBuildContext({
    required this.controller,
    required this.capabilities,
    required this.anchor,
    required this.clipboardStatus,
    required this.labels,
    required this.presentAsMobileToolbar,
    this.actionConfiguration = const EditorActionConfiguration(),
  });

  /// Контроллер редактора.
  final EditorController controller;

  /// Какие стандартные действия сейчас доступны.
  final EditorActionCapabilities capabilities;

  /// Откуда открыто меню (указатель или selection/IME).
  final EditorMenuAnchor anchor;

  /// Статус буфера (paste скрывают при [ClipboardStatus.unknown] в [EditorMenuDefaults.standardItems]).
  final ClipboardStatus clipboardStatus;

  /// Подписи из [EditorActionConfiguration.labels].
  final EditorActionLabels labels;

  /// `true` на Android/iOS: [AdaptiveTextSelectionToolbar.buttonItems] вместо вертикального списка.
  final bool presentAsMobileToolbar;

  /// Общие настройки действий (отключённые id, реестр).
  final EditorActionConfiguration actionConfiguration;
}

/// Базовый тип пункта контекстного меню.
///
/// Реализации: [EditorStandardMenuItem], [EditorCustomMenuItem], [EditorMenuDividerItem].
/// Список отрисовывается [EditorMenuPresenter].
sealed class EditorMenuItem {}

/// Пункт, привязанный к встроенному [EditorActionId].
///
/// По нажатию вызывается [EditorActions.perform] через [EditorMenuPresenter].
/// На mobile toolbar отображаются только cut/copy/paste/selectAll;
/// undo/redo — только в десктопном вертикальном меню.
final class EditorStandardMenuItem extends EditorMenuItem {
  EditorStandardMenuItem({
    required this.action,
    this.enabled = true,
    this.label,
  });

  /// Какое действие выполнить.
  final EditorActionId action;

  /// `false` — пункт не показывается (серые disabled не рисуются).
  final bool enabled;

  /// Явная подпись; `null` — [EditorActionLabels.labelFor] на десктопе.
  final String? label;
}

/// Произвольный пункт приложения.
///
/// Либо локальный [onPressed], либо централизованный вызов через [actionId]
/// и [EditorActionRegistry] (рекомендуется для единообразия с [EditorController.performCustom]).
final class EditorCustomMenuItem extends EditorMenuItem {
  EditorCustomMenuItem({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.actionId,
  });

  /// Текст на кнопке меню.
  final String label;

  /// Вызывается при нажатии, если [actionId] == `null`.
  final VoidCallback onPressed;

  /// `false` — пункт пропускается при сборке UI.
  final bool enabled;

  /// Если задан — вместо [onPressed] вызывается [EditorController.performCustom].
  final String? actionId;
}

/// Горизонтальный разделитель между группами пунктов (только десктопное меню).
final class EditorMenuDividerItem extends EditorMenuItem {
  EditorMenuDividerItem();
}

/// Функция сборки списка пунктов перед показом меню.
///
/// По умолчанию — [EditorMenuDefaults.standardItems]. Можно добавить
/// [EditorCustomMenuItem] и [EditorMenuDividerItem] между стандартными действиями.
typedef EditorMenuItemsBuilder =
    List<EditorMenuItem> Function(EditorMenuBuildContext context);

/// Конфигурация контекстного меню для [EditorView].
///
/// Держит [actionConfiguration] (в первую очередь подписи для [labels]) и [buildItems].
/// Если в [EditorView] [menuConfiguration] == `null`, меню создаётся из
/// [EditorView.actionConfiguration].
///
/// При показе меню [EditorScrollable] кладёт в [EditorMenuBuildContext]:
/// [EditorMenuBuildContext.labels] — из [labels] этого объекта;
/// [EditorMenuBuildContext.actionConfiguration] — из [EditorView.actionConfiguration]
/// (disabled, registry). Чтобы всё совпадало, задайте [EditorMenuConfiguration.fromAction].
final class EditorMenuConfiguration {
  /// Меню с подписями [labels] и стандартным набором пунктов.
  EditorMenuConfiguration({
    EditorActionLabels labels = const EditorActionLabels(),
    EditorMenuItemsBuilder? buildItems,
    EditorActionConfiguration? actionConfiguration,
  }) : buildItems = buildItems ?? EditorMenuDefaults.standardItems,
       actionConfiguration =
           actionConfiguration ?? EditorActionConfiguration(labels: labels);

  /// Явная [EditorActionConfiguration] (удобно, если меню и клавиши настраиваются вместе).
  EditorMenuConfiguration.fromAction(
    this.actionConfiguration, {
    EditorMenuItemsBuilder? buildItems,
  }) : buildItems = buildItems ?? EditorMenuDefaults.standardItems;

  /// То же, что [fromAction]; имя подчёркивает слияние с уже готовой конфигурацией действий.
  EditorMenuConfiguration.merge({
    required this.actionConfiguration,
    EditorMenuItemsBuilder? buildItems,
  }) : buildItems = buildItems ?? EditorMenuDefaults.standardItems;

  /// Клавиши, подписи, disabled и реестр — общие с [EditorInputHandler].
  final EditorActionConfiguration actionConfiguration;

  /// Сборщик пунктов при каждом открытии меню.
  final EditorMenuItemsBuilder buildItems;

  /// Сокращение для [actionConfiguration.labels].
  EditorActionLabels get labels => actionConfiguration.labels;
}

/// Вспомогательный вызов действия из меню (обёртка над [EditorActions.perform]).
abstract final class EditorMenuActions {
  EditorMenuActions._();

  /// Выполняет [action] на [controller] с опциональным [registry] и [context].
  static Future<void> perform(
    EditorController controller,
    EditorActionId action, {
    EditorActionRegistry? registry,
    EditorActionContext? context,
  }) async {
    final ctx = context ?? EditorActionContext(controller: controller);
    await EditorActions.perform(
      ctx,
      EditorActionInvocation(action),
      registry: registry ?? controller.actionRegistry,
    );
  }
}

/// Стандартный набор пунктов контекстного меню.
abstract final class EditorMenuDefaults {
  EditorMenuDefaults._();

  /// Порядок на десктопе: Undo → Redo → Cut → Copy → Paste → Select all.
  ///
  /// При [EditorMenuBuildContext.presentAsMobileToolbar] (Android/iOS) undo/redo
  /// не добавляются (ограничение [ContextMenuButtonType]). Paste показывается только если буфер уже
  /// известен ([ClipboardStatus] не [ClipboardStatus.unknown]).
  /// Пункты из [EditorActionConfiguration.disabledActions] пропускаются.
  static List<EditorMenuItem> standardItems(EditorMenuBuildContext ctx) {
    final c = ctx.capabilities;
    final disabled = ctx.actionConfiguration.disabledActions;
    final items = <EditorMenuItem>[];

    if (!ctx.presentAsMobileToolbar) {
      _addIf(items, EditorActionId.undo, c.canUndo, ctx.labels.undo, disabled);
      _addIf(items, EditorActionId.redo, c.canRedo, ctx.labels.redo, disabled);
    }

    _addStandard(items, EditorActionId.cut, c.canCut, disabled);
    _addStandard(items, EditorActionId.copy, c.canCopy, disabled);
    if (c.canPaste && ctx.clipboardStatus != ClipboardStatus.unknown) {
      _addStandard(items, EditorActionId.paste, true, disabled);
    }
    _addStandard(items, EditorActionId.selectAll, c.canSelectAll, disabled);

    return items;
  }

  static void _addIf(
    List<EditorMenuItem> items,
    EditorActionId action,
    bool enabled,
    String label,
    Set<EditorActionId> disabled,
  ) {
    if (!enabled || disabled.contains(action)) return;
    items.add(EditorStandardMenuItem(action: action, label: label));
  }

  static void _addStandard(
    List<EditorMenuItem> items,
    EditorActionId action,
    bool enabled,
    Set<EditorActionId> disabled,
  ) {
    if (!enabled || disabled.contains(action)) return;
    items.add(EditorStandardMenuItem(action: action));
  }
}
