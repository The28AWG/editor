import 'package:editor/src/api/editor_action.dart';
import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/api/editor_host.dart';
import 'package:editor/src/api/editor_menu.dart';
import 'package:editor/src/view/editor_scrollable.dart';
import 'package:flutter/widgets.dart';

/// Верхнеуровневый встраиваемый виджет редактора для Flutter-приложений.
///
/// Оборачивает [EditorScrollable] в [ListenableBuilder] по [controller], поэтому
/// перерисовка следует за изменениями документа, выделения и стилей.
///
/// ## Действия и меню
///
/// - [actionConfiguration] — привязки клавиш ([EditorInputHandler]),
///   подписи, [EditorActionConfiguration.disabledActions] и [EditorActionRegistry].
/// - [menuConfiguration] — какие пункты показывать при ПКМ / long-press / IME toolbar.
///   Если `null`, создаётся [EditorMenuConfiguration] с тем же [actionConfiguration].
///   При отдельном [menuConfiguration] подписи берутся из него ([EditorMenuConfiguration.labels]),
///   а [EditorActionConfiguration.disabledActions] и реестр — из [actionConfiguration] виджета;
///   для согласованности используйте [EditorMenuConfiguration.fromAction].
///
/// ## Хост и gutter
///
/// - [host] подключается к [EditorController.setHost] для асинхронных стилевых слоёв.
/// - [showGutter] резервирует колонку номеров строк в [EditorLayersPainter].
///
/// ```dart
/// final actionConfiguration = EditorActionConfiguration(
///   labels: editorActionLabelsFromMaterial(context),
/// );
/// EditorView(
///   controller: controller,
///   showGutter: true,
///   actionConfiguration: actionConfiguration,
///   menuConfiguration: EditorMenuConfiguration.fromAction(
///     actionConfiguration,
///     buildItems: (ctx) => [
///       ...EditorMenuDefaults.standardItems(ctx),
///       EditorMenuDividerItem(),
///       EditorCustomMenuItem(label: 'Format', onPressed: format),
///     ],
///   ),
/// );
/// ```
class EditorView extends StatefulWidget {
  const EditorView({
    required this.controller,
    this.host,
    this.showGutter = false,
    this.actionConfiguration = const EditorActionConfiguration(),
    this.menuConfiguration,
    super.key,
  });

  /// Состояние документа, выделения, undo и стилей.
  final EditorController controller;

  /// Необязательные колбэки токенизации и стилевых слоёв от приложения.
  final EditorHost? host;

  /// Показывать ли колонку номеров строк слева от текста.
  final bool showGutter;

  /// Клавиатура и общие настройки [EditorActionId].
  final EditorActionConfiguration actionConfiguration;

  /// Контекстное меню; `null` — стандартные пункты из [actionConfiguration].
  final EditorMenuConfiguration? menuConfiguration;

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  @override
  void initState() {
    super.initState();
    if (widget.host != null) {
      widget.controller.setHost(widget.host);
    }
  }

  @override
  void didUpdateWidget(EditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.host != oldWidget.host) {
      widget.controller.setHost(widget.host);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu =
        widget.menuConfiguration ??
        EditorMenuConfiguration(
          actionConfiguration: widget.actionConfiguration,
        );

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => EditorScrollable(
        controller: widget.controller,
        showGutter: widget.showGutter,
        actionConfiguration: widget.actionConfiguration,
        menuConfiguration: menu,
      ),
    );
  }
}
