import 'dart:async';

import 'package:editor/src/api/editor_action.dart';
import 'package:editor/src/api/editor_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

/// Обработчик клавиатуры desktop/web для [EditorScrollable].
///
/// Порядок разбора [KeyEvent]:
///
/// 1. [EditorKeyBindings.resolve] по [EditorActionConfiguration.effectiveBindings].
/// 2. Если действие в [EditorActionConfiguration.disabledActions] — игнор.
/// 3. [EditorActions.canExecute] / [EditorActions.perform] для привязанных клавиш.
/// 4. В [readOnly] часть клавиш поглощается без эффекта (см. [_isReadOnlyBlocked]).
/// 5. [EditorKeyBindings.resolveTypedCharacter] для печатных символов без Ctrl/Meta.
///
/// Реестр: [EditorActionConfiguration.registry] ?? [EditorController.actionRegistry].
final class EditorInputHandler {
  EditorInputHandler(
    this.controller, {
    this.configuration = const EditorActionConfiguration(),
  });

  /// Контроллер, над которым выполняются действия.
  final EditorController controller;

  /// Привязки, disabled и опциональный реестр кастомных действий.
  final EditorActionConfiguration configuration;

  /// Обрабатывает событие клавиатуры; возвращает [KeyEventResult.handled], если событие использовано редактором.
  KeyEventResult handleKeyEvent(KeyEvent event) {
    final ctx = EditorActionContext(controller: controller);

    final bound = EditorKeyBindings.resolve(
      event,
      configuration.effectiveBindings,
    );
    if (bound != null && !configuration.disabledActions.contains(bound.id)) {
      if (EditorActions.canExecute(ctx, bound, registry: _registry)) {
        unawaited(EditorActions.perform(ctx, bound, registry: _registry));
        return KeyEventResult.handled;
      }
      if (_isReadOnlyBlocked(bound.id)) {
        return KeyEventResult.handled;
      }
    }

    final typed = EditorKeyBindings.resolveTypedCharacter(event);
    if (typed != null && !configuration.disabledActions.contains(typed.id)) {
      if (EditorActions.canExecute(ctx, typed, registry: _registry)) {
        unawaited(EditorActions.perform(ctx, typed, registry: _registry));
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  EditorActionRegistry? get _registry =>
      configuration.registry ?? controller.actionRegistry;

  bool _isReadOnlyBlocked(EditorActionId id) {
    if (!controller.readOnly) return false;
    return switch (id) {
      EditorActionId.copy => false,
      EditorActionId.selectAll => false,
      EditorActionId.moveCaretLeft ||
      EditorActionId.moveCaretRight ||
      EditorActionId.moveCaretUp ||
      EditorActionId.moveCaretDown ||
      EditorActionId.moveCaretLineStart ||
      EditorActionId.moveCaretLineEnd => false,
      _ => true,
    };
  }
}
