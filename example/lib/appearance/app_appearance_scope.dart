import 'package:example/appearance/app_appearance_controller.dart';
import 'package:flutter/material.dart';

/// Доступ к [AppAppearanceController] из дерева виджетов example.
class AppAppearanceScope extends InheritedNotifier<AppAppearanceController> {
  const AppAppearanceScope({
    required AppAppearanceController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppAppearanceController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppAppearanceScope>();
    assert(scope != null, 'AppAppearanceScope not found in context');
    return scope!.notifier!;
  }

  /// Без подписки на изменения (в [dispose] и одноразовых колбэках).
  static AppAppearanceController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppAppearanceScope>();
    assert(scope != null, 'AppAppearanceScope not found in context');
    return scope!.notifier!;
  }
}
