import 'package:editor/src/api/editor_action.dart';
import 'package:editor/src/api/editor_controller.dart';
import 'package:editor/src/api/editor_host.dart';
import 'package:editor/src/api/editor_menu.dart';
import 'package:editor/src/overlay/editor_overlay_presenter.dart';
import 'package:editor/src/view/editor_scrollable.dart';
import 'package:flutter/widgets.dart';

/// Верхнеуровневый встраиваемый виджет редактора для Flutter-приложений.
///
/// Оборачивает [EditorScrollable] в [ListenableBuilder] по [controller], поэтому
/// перерисовка следует за изменениями документа, выделения и стилей.
///
/// Overlay ([EditorOverlayCoordinator]) рисуется через [OverlayPortal] поверх
/// overlay-хоста приложения; [EditorOverlayLayoutPolicy.clampToViewport] удерживает
/// панель внутри viewport редактора.
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
  final OverlayPortalController _overlayPortal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    if (widget.host != null) {
      widget.controller.setHost(widget.host);
    }
    widget.controller.overlays.addListener(_syncOverlayPortal);
    _syncOverlayPortal();
  }

  @override
  void didUpdateWidget(EditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.host != oldWidget.host) {
      widget.controller.setHost(widget.host);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.overlays.removeListener(_syncOverlayPortal);
      widget.controller.overlays.addListener(_syncOverlayPortal);
      _syncOverlayPortal();
    }
  }

  @override
  void dispose() {
    widget.controller.overlays.removeListener(_syncOverlayPortal);
    if (_overlayPortal.isShowing) _overlayPortal.hide();
    super.dispose();
  }

  void _syncOverlayPortal() {
    final show = widget.controller.overlays.isNotEmpty;
    if (show && !_overlayPortal.isShowing) {
      _overlayPortal.show();
    } else if (!show && _overlayPortal.isShowing) {
      _overlayPortal.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu =
        widget.menuConfiguration ??
        EditorMenuConfiguration(
          actionConfiguration: widget.actionConfiguration,
        );

    return OverlayPortal(
      controller: _overlayPortal,
      overlayChildBuilder: _buildOverlayLayer,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => EditorScrollable(
          controller: widget.controller,
          showGutter: widget.showGutter,
          actionConfiguration: widget.actionConfiguration,
          menuConfiguration: menu,
        ),
      ),
    );
  }

  Widget _buildOverlayLayer(BuildContext context) {
    final geo = widget.controller.overlayGeometry;
    if (geo == null || widget.controller.overlays.isEmpty) {
      return const SizedBox.shrink();
    }

    final overlaySize = MediaQuery.sizeOf(context);
    widget.controller.overlays.overlayHostSize = overlaySize;

    return ListenableBuilder(
      listenable: widget.controller.overlays,
      builder: (context, _) {
        if (widget.controller.overlays.isEmpty) {
          return const SizedBox.shrink();
        }
        return EditorOverlayStack(
          coordinator: widget.controller.overlays,
          geometry: geo,
          overlayHostSize: overlaySize,
        );
      },
    );
  }
}
