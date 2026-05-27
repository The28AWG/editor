import 'package:example/appearance/dart_editor_appearance.dart';
import 'package:example/appearance/editor_appearance_palette.dart';
import 'package:flutter/material.dart';

/// Глобальное состояние цветовой схемы: редактор + Material.
final class AppAppearanceController extends ChangeNotifier {
  AppAppearanceController({DartEditorAppearance? initial})
    : _appearance = initial ?? DartEditorAppearance.vscodeLight;

  DartEditorAppearance _appearance;

  /// Текущая схема (редактор + синтаксис).
  DartEditorAppearance get appearance => _appearance;

  /// Согласованная Material-тема для [MaterialApp.theme].
  ThemeData get materialTheme => materialThemeFromChrome(_appearance.chrome);

  /// `true`, если активна светлая схема.
  bool get isLight => _appearance.chrome.light;

  /// Все встроенные схемы.
  List<DartEditorAppearance> get catalog => DartEditorAppearance.catalog;

  /// Переключает схему и уведомляет слушателей ([MaterialApp], [EditorDemoPage]).
  void setAppearance(DartEditorAppearance value) {
    if (_appearance.name == value.name) return;
    _appearance = value;
    notifyListeners();
  }
}
