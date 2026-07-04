import 'dart:async';

import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/editing/clipboard_text.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/selection/caret_desired_column.dart';
import 'package:editor/src/selection/cursor.dart'
    show
        cursorLineEnd,
        cursorLineStart,
        cursorMoveDown,
        cursorMoveLeft,
        cursorMoveRight,
        cursorMoveUp;
import 'package:editor/src/selection/selection.dart';
import 'package:editor/src/selection/selection_merge.dart';
import 'package:flutter/material.dart' show ClipboardStatus;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show ShortcutActivator, SingleActivator;

/// Идентификатор действия редактора — единая точка для меню, клавиш и API.
///
/// Все изменения текста и операции с буфером обмена проходят через
/// [EditorActions.perform] с [EditorActionInvocation]. Это позволяет:
///
/// - показывать одни и те же действия в контекстном меню и на клавиатуре;
/// - отключать действия централизованно через [EditorActionConfiguration.disabledActions];
/// - проверять доступность через [EditorActionCapabilities] / [EditorController.canPerform].
///
/// Часть идентификаторов не попадает в стандартное меню ([EditorActionDefaults.menuHidden]),
/// но доступна с клавиатуры и программно.
enum EditorActionId {
  /// Отмена последней транзакции ([EditorController.undo]).
  undo,

  /// Повтор отменённой транзакции ([EditorController.redo]).
  redo,

  /// Вырезать выделение в буфер и удалить из документа.
  cut,

  /// Копировать выделение в буфер без изменения документа.
  copy,

  /// Вставить из буфера (или из [EditorActionInvocation.pasteText]).
  paste,

  /// Выделить весь документ ([EditorController.selectAll]).
  selectAll,

  /// Удалить символ слева от каретки (команда `backspace`).
  backspace,

  /// Удалить символ справа от каретки (команда `delete`).
  delete,

  /// Вставить перевод строки (команда `insertNewline`).
  insertNewline,

  /// Вставить табуляцию (команда `insertTab`).
  insertTab,

  /// Вставить один символ; символ передаётся в [EditorActionInvocation.character].
  typeCharacter,

  /// Сдвинуть каретку на один символ влево; с Shift — расширить выделение.
  moveCaretLeft,

  /// Сдвинуть каретку на один символ вправо; с Shift — расширить выделение.
  moveCaretRight,

  /// Сдвинуть каретку на строку вверх; с Shift — расширить выделение.
  moveCaretUp,

  /// Сдвинуть каретку на строку вниз; с Shift — расширить выделение.
  moveCaretDown,

  /// Перейти к началу текста строки с учётом отступов (Home); с Shift — расширить выделение.
  moveCaretLineStart,

  /// Перейти к концу содержимого текущей строки (End); с Shift — расширить выделение.
  moveCaretLineEnd,
}

/// Параметры одного вызова [EditorActions.perform].
///
/// Создаётся из привязок клавиш ([EditorKeyBindings.resolve]),
/// печатного ввода ([EditorKeyBindings.resolveTypedCharacter])
/// или вручную при программном вызове действия.
final class EditorActionInvocation {
  /// [id] обязателен; остальные поля зависят от типа действия.
  const EditorActionInvocation(
    this.id, {
    this.character,
    this.pasteText,
    this.extendSelection = false,
  });

  /// Какое действие выполнить.
  final EditorActionId id;

  /// Для [EditorActionId.typeCharacter]: один печатный символ (не управляющий).
  final String? character;

  /// Для [EditorActionId.paste]: явный текст вместо чтения системного буфера.
  final String? pasteText;

  /// Для [EditorActionId.moveCaret*]: при `true` якорь выделения сохраняется,
  /// двигается только «голова» ([Selection.withHead]); при `false` — одиночная каретка.
  final bool extendSelection;

  /// Копия с другим флагом расширения выделения (используется при Shift+стрелки).
  EditorActionInvocation withExtendSelection(bool value) =>
      EditorActionInvocation(
        id,
        character: character,
        pasteText: pasteText,
        extendSelection: value,
      );
}

/// Контекст выполнения действия.
///
/// Передаётся в [EditorActions.perform], [EditorActions.canExecute]
/// и в колбэки [EditorActionRegistry.registerCustom].
///
/// [clipboardStatus] влияет на [EditorActionCapabilities.canPaste]:
/// при [ClipboardStatus.notPasteable] вставка недоступна даже в режиме редактирования.
final class EditorActionContext {
  const EditorActionContext({
    required this.controller,
    this.clipboardStatus = ClipboardStatus.unknown,
  });

  /// Контроллер, над документом которого выполняется действие.
  final EditorController controller;

  /// Состояние буфера обмена на момент проверки/выполнения (актуально для меню paste).
  final ClipboardStatus clipboardStatus;
}

/// Подписи стандартных действий для контекстного меню.
///
/// Используется [EditorMenuPresenter] на десктопе и при сборке пунктов
/// [EditorStandardMenuItem]. Для cut/copy/paste/select all допускается `null` —
/// тогда подставляются английские значения по умолчанию.
///
/// Готовая локализация из Material: [editorActionLabelsFromMaterial].
final class EditorActionLabels {
  const EditorActionLabels({
    this.undo = 'Undo',
    this.redo = 'Redo',
    this.cut,
    this.copy,
    this.paste,
    this.selectAll,
  });

  /// Подпись «Отменить» (в Material нет стандартной строки).
  final String undo;

  /// Подпись «Повторить».
  final String redo;

  /// Подпись «Вырезать»; `null` → `'Cut'`.
  final String? cut;

  /// Подпись «Копировать»; `null` → `'Copy'`.
  final String? copy;

  /// Подпись «Вставить»; `null` → `'Paste'`.
  final String? paste;

  /// Подпись «Выделить всё»; `null` → `'Select all'`.
  final String? selectAll;

  /// Текст для [EditorActionId], отображаемого в стандартном меню.
  String labelFor(EditorActionId action) => switch (action) {
    EditorActionId.undo => undo,
    EditorActionId.redo => redo,
    EditorActionId.cut => cut ?? 'Cut',
    EditorActionId.copy => copy ?? 'Copy',
    EditorActionId.paste => paste ?? 'Paste',
    EditorActionId.selectAll => selectAll ?? 'Select all',
    _ => '',
  };
}

/// Снимок доступности действий на текущий момент.
///
/// Строится из состояния [EditorController] (undo/redo, readOnly, выделение,
/// длина документа) и опционально [ClipboardStatus]. Используется при сборке
/// [EditorMenuBuildContext] и в [EditorActions.canExecute].
final class EditorActionCapabilities {
  const EditorActionCapabilities({
    required this.canUndo,
    required this.canRedo,
    required this.canCut,
    required this.canCopy,
    required this.canPaste,
    required this.canSelectAll,
    required this.canEdit,
  });

  /// Вычисляет возможности по контроллеру.
  ///
  /// [selectionForMenu] позволяет передать выделение «как для меню» (например,
  /// после переноса каретки по ПКМ), не дожидаясь следующего кадра контроллера.
  factory EditorActionCapabilities.of(
    EditorController controller, {
    ClipboardStatus clipboardStatus = ClipboardStatus.unknown,
    SelectionState? selectionForMenu,
  }) {
    final selections =
        selectionForMenu?.selections ?? controller.selection.selections;
    final hasCopy = hasCopyableSelection(selections);
    final docLen = controller.document.length;
    final canPaste =
        !controller.readOnly && clipboardStatus != ClipboardStatus.notPasteable;

    return EditorActionCapabilities(
      canUndo: controller.canUndo,
      canRedo: controller.canRedo,
      canCut: hasCopy && !controller.readOnly,
      canCopy: hasCopy,
      canPaste: canPaste,
      canSelectAll: docLen > 0,
      canEdit: !controller.readOnly,
    );
  }

  /// Есть ли что отменять в стеке undo.
  final bool canUndo;

  /// Есть ли что повторить в стеке redo.
  final bool canRedo;

  /// Вырезание: непустое копируемое выделение и не [readOnly].
  final bool canCut;

  /// Копирование: непустое копируемое выделение.
  final bool canCopy;

  /// Вставка: не [readOnly] и буфер не [ClipboardStatus.notPasteable].
  final bool canPaste;

  /// «Выделить всё»: документ не пуст.
  final bool canSelectAll;

  /// Редактирование текста (ввод, backspace, delete и т.д.).
  final bool canEdit;

  /// Можно ли выполнить [action] с учётом полей выше.
  bool enabledFor(EditorActionId action) => switch (action) {
    EditorActionId.undo => canUndo,
    EditorActionId.redo => canRedo,
    EditorActionId.cut => canCut,
    EditorActionId.copy => canCopy,
    EditorActionId.paste => canPaste,
    EditorActionId.selectAll => canSelectAll,
    EditorActionId.backspace ||
    EditorActionId.delete ||
    EditorActionId.insertNewline ||
    EditorActionId.insertTab ||
    EditorActionId.typeCharacter => canEdit,
    EditorActionId.moveCaretLeft ||
    EditorActionId.moveCaretRight ||
    EditorActionId.moveCaretUp ||
    EditorActionId.moveCaretDown ||
    EditorActionId.moveCaretLineStart ||
    EditorActionId.moveCaretLineEnd => true,
  };
}

/// Одна привязка клавиши к [EditorActionId].
///
/// Список обрабатывается [EditorKeyBindings.resolve] сверху вниз:
/// [EditorActionConfiguration.prependedBindings] идут первыми и перекрывают
/// стандартные сочетания из [EditorActionDefaults.bindings].
final class EditorKeyBinding {
  const EditorKeyBinding({required this.action, required this.activator});

  /// Действие при срабатывании [activator].
  final EditorActionId action;

  /// Условие срабатывания (обычно [SingleActivator]).
  final ShortcutActivator activator;
}

/// Реестр пользовательских действий со строковым идентификатором.
///
/// Пункты [EditorCustomMenuItem] с [EditorCustomMenuItem.actionId] вызывают
/// [performCustom] / [canExecuteCustom]. Встроенные [EditorActionId] реестр
/// не затрагивает.
final class EditorActionRegistry {
  EditorActionRegistry();

  final Map<String, _CustomActionEntry> _custom = {};

  /// Регистрирует действие с уникальным [id].
  ///
  /// [perform] вызывается из меню и [EditorController.performCustom];
  /// [canExecute] опционально скрывает пункт или блокирует вызов.
  void registerCustom(
    String id, {
    required Future<bool> Function(EditorActionContext ctx) perform,
    bool Function(EditorActionContext ctx)? canExecute,
  }) {
    _custom[id] = _CustomActionEntry(perform: perform, canExecute: canExecute);
  }

  /// Удаляет ранее зарегистрированное действие.
  void unregisterCustom(String id) => _custom.remove(id);

  /// `false`, если [id] не зарегистрирован или [canExecute] вернул `false`.
  bool canExecuteCustom(String id, EditorActionContext ctx) {
    final entry = _custom[id];
    if (entry == null) return false;
    return entry.canExecute?.call(ctx) ?? true;
  }

  /// Выполняет кастомное действие; `false`, если [id] не найден.
  Future<bool> performCustom(String id, EditorActionContext ctx) async {
    final entry = _custom[id];
    if (entry == null) return false;
    return entry.perform(ctx);
  }
}

final class _CustomActionEntry {
  _CustomActionEntry({required this.perform, this.canExecute});

  final Future<bool> Function(EditorActionContext ctx) perform;
  final bool Function(EditorActionContext ctx)? canExecute;
}

/// Выполнение и проверка встроенных [EditorActionId].
///
/// Единая точка для [EditorInputHandler], контекстного меню
/// ([EditorMenuPresenter]) и [EditorController.perform].
abstract final class EditorActions {
  EditorActions._();

  /// `true` для стрелок перемещения каретки (особая обработка Shift в [EditorKeyBindings]).
  static bool isCaretMove(EditorActionId id) => switch (id) {
    EditorActionId.moveCaretLeft ||
    EditorActionId.moveCaretRight ||
    EditorActionId.moveCaretUp ||
    EditorActionId.moveCaretDown ||
    EditorActionId.moveCaretLineStart ||
    EditorActionId.moveCaretLineEnd => true,
    _ => false,
  };

  /// Действие может попасть в [EditorMenuDefaults.standardItems] (если не в [EditorActionConfiguration.disabledActions]).
  static bool showsInStandardMenu(EditorActionId id) => switch (id) {
    EditorActionId.undo ||
    EditorActionId.redo ||
    EditorActionId.cut ||
    EditorActionId.copy ||
    EditorActionId.paste ||
    EditorActionId.selectAll => true,
    _ => false,
  };

  /// Проверяет, можно ли выполнить вызов сейчас.
  ///
  /// Для встроенных действий — [EditorActionCapabilities.enabledFor];
  /// для [customActionId] — [EditorActionRegistry.canExecuteCustom].
  static bool canExecute(
    EditorActionContext ctx,
    EditorActionInvocation invocation, {
    EditorActionRegistry? registry,
    String? customActionId,
  }) {
    if (customActionId != null) {
      return registry?.canExecuteCustom(customActionId, ctx) ?? false;
    }
    return EditorActionCapabilities.of(
      ctx.controller,
      clipboardStatus: ctx.clipboardStatus,
    ).enabledFor(invocation.id);
  }

  /// Выполняет действие. Возвращает `true`, если операция имела эффект
  /// (например, undo вернул [DocumentChange], paste изменил текст).
  ///
  /// При [customActionId] делегирует в [EditorActionRegistry.performCustom].
  static Future<bool> perform(
    EditorActionContext ctx,
    EditorActionInvocation invocation, {
    EditorActionRegistry? registry,
    String? customActionId,
  }) async {
    if (customActionId != null) {
      return registry?.performCustom(customActionId, ctx) ?? false;
    }
    if (!canExecute(ctx, invocation, registry: registry)) {
      return false;
    }

    final c = ctx.controller;
    switch (invocation.id) {
      case EditorActionId.undo:
        return c.undo() != null;
      case EditorActionId.redo:
        return c.redo() != null;
      case EditorActionId.cut:
        return c.cut();
      case EditorActionId.copy:
        return c.copy();
      case EditorActionId.paste:
        return c.paste(invocation.pasteText);
      case EditorActionId.selectAll:
        c.selectAll();
        return true;
      case EditorActionId.backspace:
        return c.executeCommand('backspace') != null;
      case EditorActionId.delete:
        return c.executeCommand('delete') != null;
      case EditorActionId.insertNewline:
        return c.executeCommand('insertNewline') != null;
      case EditorActionId.insertTab:
        return c.executeCommand('insertTab') != null;
      case EditorActionId.typeCharacter:
        final ch = invocation.character;
        if (ch == null || ch.isEmpty) return false;
        return c.executeCommand('typeCharacter', character: ch) != null;
      case EditorActionId.moveCaretLeft:
      case EditorActionId.moveCaretRight:
      case EditorActionId.moveCaretUp:
      case EditorActionId.moveCaretDown:
      case EditorActionId.moveCaretLineStart:
      case EditorActionId.moveCaretLineEnd:
        return _moveCaret(c, invocation);
    }
  }

  static bool _isVerticalCaretMove(EditorActionId id) => switch (id) {
    EditorActionId.moveCaretUp || EditorActionId.moveCaretDown => true,
    _ => false,
  };

  static bool _moveCaret(
    EditorController controller,
    EditorActionInvocation invocation,
  ) {
    final doc = controller.document;
    final state = controller.selection;
    final selections = state.selections;
    final desiredIn = state.hasDesiredColumns
        ? state.desiredColumns
        : CaretDesiredColumn.fromHeads(doc, selections);
    final vertical = _isVerticalCaretMove(invocation.id);

    TextOffset? movedHead(TextOffset head, int desiredColumn) =>
        switch (invocation.id) {
          EditorActionId.moveCaretLeft => cursorMoveLeft(doc, head),
          EditorActionId.moveCaretRight => cursorMoveRight(doc, head),
          EditorActionId.moveCaretUp => cursorMoveUp(doc, head, desiredColumn),
          EditorActionId.moveCaretDown => cursorMoveDown(
            doc,
            head,
            desiredColumn,
          ),
          EditorActionId.moveCaretLineStart => cursorLineStart(doc, head),
          EditorActionId.moveCaretLineEnd => cursorLineEnd(doc, head),
          _ => null,
        };

    final nextSels = <Selection>[];
    final nextDesired = <int>[];
    var anyMoved = false;

    for (var i = 0; i < selections.length; i++) {
      final sel = selections[i];
      final col = desiredIn[i];
      final nextHead = movedHead(sel.head, col);
      if (nextHead == null) {
        nextSels.add(sel);
        nextDesired.add(col);
        continue;
      }
      anyMoved = true;
      nextSels.add(
        invocation.extendSelection
            ? sel.withHead(nextHead)
            : Selection.collapsed(nextHead),
      );
      nextDesired.add(vertical ? col : CaretDesiredColumn.at(doc, nextHead));
    }

    if (!anyMoved) return false;

    final merged = mergeOverlappingSelections(nextSels);
    final mergedDesired = CaretDesiredColumn.afterMerge(
      doc,
      nextSels,
      nextDesired,
      merged,
    );
    controller.setSelection(
      SelectionState(merged, mergedDesired),
      syncDesiredFromHeads: false,
    );
    return true;
  }
}

/// Сопоставление [KeyEvent] с [EditorActionInvocation].
///
/// Используется [EditorInputHandler] перед печатным вводом.
/// Порядок: legacy-сочетания (Insert/Shift+Delete) → список [bindings].
abstract final class EditorKeyBindings {
  EditorKeyBindings._();

  /// Возвращает вызов для [KeyDownEvent] / [KeyRepeatEvent] или `null`.
  static EditorActionInvocation? resolve(
    KeyEvent event,
    List<EditorKeyBinding> bindings,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;

    final hw = HardwareKeyboard.instance;
    final logical = event.logicalKey;

    final legacy = _resolveLegacy(logical, hw);
    if (legacy != null) return legacy;

    for (final binding in bindings) {
      final matches = EditorActions.isCaretMove(binding.action)
          ? _acceptsCaretMove(event, binding.activator, hw)
          : binding.activator.accepts(event, hw);
      if (!matches) continue;

      var inv = EditorActionInvocation(binding.action);
      if (EditorActions.isCaretMove(binding.action) && hw.isShiftPressed) {
        inv = inv.withExtendSelection(true);
      }
      return inv;
    }

    return null;
  }

  /// [SingleActivator] с `shift: false` (по умолчанию) отклоняет Shift+стрелка;
  /// для каретки Shift означает расширение выделения, не отдельный shortcut.
  static bool _acceptsCaretMove(
    KeyEvent event,
    ShortcutActivator activator,
    HardwareKeyboard hw,
  ) {
    if (activator is! SingleActivator) {
      return activator.accepts(event, hw);
    }
    final a = activator;
    if (a.shift || a.control || a.alt || a.meta) {
      return a.accepts(event, hw);
    }
    final isTrigger =
        event is KeyDownEvent || (a.includeRepeats && event is KeyRepeatEvent);
    if (!isTrigger || event.logicalKey != a.trigger) return false;
    if (hw.isControlPressed || hw.isMetaPressed || hw.isAltPressed) {
      return false;
    }
    return true;
  }

  static EditorActionInvocation? _resolveLegacy(
    LogicalKeyboardKey logical,
    HardwareKeyboard hw,
  ) {
    if (logical == LogicalKeyboardKey.insert) {
      if (hw.isShiftPressed && !hw.isControlPressed && !hw.isAltPressed) {
        return const EditorActionInvocation(EditorActionId.paste);
      }
      if (hw.isControlPressed && !hw.isShiftPressed) {
        return const EditorActionInvocation(EditorActionId.copy);
      }
    }
    if (logical == LogicalKeyboardKey.delete &&
        hw.isShiftPressed &&
        !hw.isControlPressed &&
        !hw.isAltPressed) {
      return const EditorActionInvocation(EditorActionId.cut);
    }
    return null;
  }

  /// Обрабатывает печатный ввод, если модификаторы shortcut не зажаты.
  static EditorActionInvocation? resolveTypedCharacter(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
    final hw = HardwareKeyboard.instance;
    if (_isShortcutModifier(hw)) return null;

    final ch = event.character;
    if (ch == null || ch.isEmpty || ch.length != 1) return null;
    final code = ch.codeUnitAt(0);
    if (code < 32 || code == 127) return null;

    return EditorActionInvocation(EditorActionId.typeCharacter, character: ch);
  }

  static bool _isShortcutModifier(HardwareKeyboard hw) =>
      hw.isControlPressed || hw.isMetaPressed;
}

/// Стандартные привязки клавиш для desktop/web.
///
/// Переопределение: [EditorActionConfiguration.bindingsOverride] (полная замена)
/// или [EditorActionConfiguration.prependedBindings] (приоритет над отдельными клавишами).
abstract final class EditorActionDefaults {
  EditorActionDefaults._();

  /// Ctrl+Z/Y, Ctrl+C/X/V/A, стрелки, Backspace, Enter, Tab и т.д.
  static const List<EditorKeyBinding> bindings = [
    EditorKeyBinding(
      action: EditorActionId.undo,
      activator: SingleActivator(LogicalKeyboardKey.keyZ, control: true),
    ),
    EditorKeyBinding(
      action: EditorActionId.redo,
      activator: SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: true,
        shift: true,
      ),
    ),
    EditorKeyBinding(
      action: EditorActionId.redo,
      activator: SingleActivator(LogicalKeyboardKey.keyY, control: true),
    ),
    EditorKeyBinding(
      action: EditorActionId.copy,
      activator: SingleActivator(LogicalKeyboardKey.keyC, control: true),
    ),
    EditorKeyBinding(
      action: EditorActionId.cut,
      activator: SingleActivator(LogicalKeyboardKey.keyX, control: true),
    ),
    EditorKeyBinding(
      action: EditorActionId.paste,
      activator: SingleActivator(LogicalKeyboardKey.keyV, control: true),
    ),
    EditorKeyBinding(
      action: EditorActionId.selectAll,
      activator: SingleActivator(LogicalKeyboardKey.keyA, control: true),
    ),
    EditorKeyBinding(
      action: EditorActionId.backspace,
      activator: SingleActivator(LogicalKeyboardKey.backspace),
    ),
    EditorKeyBinding(
      action: EditorActionId.delete,
      activator: SingleActivator(LogicalKeyboardKey.delete),
    ),
    EditorKeyBinding(
      action: EditorActionId.insertNewline,
      activator: SingleActivator(LogicalKeyboardKey.enter),
    ),
    EditorKeyBinding(
      action: EditorActionId.insertTab,
      activator: SingleActivator(LogicalKeyboardKey.tab),
    ),
    EditorKeyBinding(
      action: EditorActionId.moveCaretLeft,
      activator: SingleActivator(LogicalKeyboardKey.arrowLeft),
    ),
    EditorKeyBinding(
      action: EditorActionId.moveCaretRight,
      activator: SingleActivator(LogicalKeyboardKey.arrowRight),
    ),
    EditorKeyBinding(
      action: EditorActionId.moveCaretUp,
      activator: SingleActivator(LogicalKeyboardKey.arrowUp),
    ),
    EditorKeyBinding(
      action: EditorActionId.moveCaretDown,
      activator: SingleActivator(LogicalKeyboardKey.arrowDown),
    ),
    EditorKeyBinding(
      action: EditorActionId.moveCaretLineStart,
      activator: SingleActivator(LogicalKeyboardKey.home),
    ),
    EditorKeyBinding(
      action: EditorActionId.moveCaretLineEnd,
      activator: SingleActivator(LogicalKeyboardKey.end),
    ),
  ];

  /// Действия, скрытые из стандартного меню (только клавиатура / API).
  static const Set<EditorActionId> menuHidden = {
    EditorActionId.backspace,
    EditorActionId.delete,
    EditorActionId.insertNewline,
    EditorActionId.insertTab,
    EditorActionId.typeCharacter,
    EditorActionId.moveCaretLeft,
    EditorActionId.moveCaretRight,
    EditorActionId.moveCaretUp,
    EditorActionId.moveCaretDown,
    EditorActionId.moveCaretLineStart,
    EditorActionId.moveCaretLineEnd,
  };
}

/// Настройка действий редактора для [EditorView] / [EditorScrollable].
///
/// Объединяет подписи меню, клавиатурные привязки, отключённые действия
/// и опциональный [registry] (иначе используется [EditorController.actionRegistry]).
///
/// ```dart
/// EditorView(
///   controller: controller,
///   actionConfiguration: EditorActionConfiguration(
///     labels: editorActionLabelsFromMaterial(context),
///     prependedBindings: [
///       EditorKeyBinding(
///         action: EditorActionId.undo,
///         activator: SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
///       ),
///     ],
///     disabledActions: {EditorActionId.cut},
///   ),
/// );
/// ```
final class EditorActionConfiguration {
  const EditorActionConfiguration({
    this.labels = const EditorActionLabels(),
    this.bindings = EditorActionDefaults.bindings,
    this.bindingsOverride,
    this.prependedBindings = const [],
    this.disabledActions = const {},
    this.registry,
  });

  /// Подписи пунктов стандартного контекстного меню.
  final EditorActionLabels labels;

  /// Базовый список привязок (по умолчанию [EditorActionDefaults.bindings]).
  final List<EditorKeyBinding> bindings;

  /// Если не `null` — игнорирует [bindings] и [prependedBindings], используется только этот список.
  final List<EditorKeyBinding>? bindingsOverride;

  /// Вставляется в начало [effectiveBindings] — перекрывает совпадающие клавиши из [bindings].
  final List<EditorKeyBinding> prependedBindings;

  /// Не выполняются с клавиатуры ([EditorInputHandler]) и не попадают в
  /// [EditorMenuDefaults.standardItems]. Собственный [EditorMenuItemsBuilder]
  /// может добавить те же id — presenter их не скрывает.
  final Set<EditorActionId> disabledActions;

  /// Отдельный реестр кастомных действий; `null` → [EditorController.actionRegistry].
  final EditorActionRegistry? registry;

  /// Итоговый список для [EditorKeyBindings.resolve] и [EditorInputHandler].
  List<EditorKeyBinding> get effectiveBindings =>
      bindingsOverride ?? [...prependedBindings, ...bindings];
}
