import 'dart:async';

import 'package:editor/src/api/editor_action.dart';
import 'package:editor/src/api/editor_host.dart';
import 'package:editor/src/api/editor_language_service.dart';
import 'package:editor/src/api/selection_change.dart';
import 'package:editor/src/diagnostics/diagnostic_decorations.dart';
import 'package:editor/src/diagnostics/editor_diagnostic.dart';
import 'package:editor/src/diagnostics/inline_diagnostic_label.dart';
import 'package:editor/src/editing/clipboard_text.dart';
import 'package:editor/src/editing/command_registry.dart';
import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/highlight/caret_highlights.dart';
import 'package:editor/src/highlight/highlight_kind.dart';
import 'package:editor/src/highlight/highlight_span.dart';
import 'package:editor/src/highlight/word_bounds.dart';
import 'package:editor/src/inlay/editor_inlay_hint.dart';
import 'package:editor/src/inlay/inlay_viewport.dart';
import 'package:editor/src/layout/viewport.dart';
import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/document_change.dart';
import 'package:editor/src/model/position.dart';
import 'package:editor/src/model/text_edit.dart';
import 'package:editor/src/navigation/editor_document_location.dart';
import 'package:editor/src/navigation/url_link.dart';
import 'package:editor/src/selection/caret_desired_column.dart';
import 'package:editor/src/selection/selection.dart';
import 'package:editor/src/selection/selection_merge.dart';
import 'package:editor/src/styling/editor_theme.dart';
import 'package:editor/src/styling/layers/base_style_layer.dart';
import 'package:editor/src/styling/layers/decoration_style_layer.dart';
import 'package:editor/src/styling/layers/transient_style_layer.dart';
import 'package:editor/src/styling/style_layer.dart';
import 'package:editor/src/styling/style_resolver.dart';
import 'package:editor/src/styling/style_span.dart';
import 'package:editor/src/styling/viewport_style_scope.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Центральный фасад для хост-приложений: документ, редактирование, выделение и стилизация.
///
/// [EditorController] владеет редактируемым [document], направляет команды клавиатуры
/// через [Transaction], объединяет стилевые слои для отрисовки и уведомляет
/// слушателей [Listenable] (обычно [EditorView]) при каждом изменении состояния.
///
/// ## Обязанности
///
/// - **Editing** — [apply], [executeCommand], [undo], [redo].
/// - **Selection** — одиночный и мультикурсор через [setSelection], [addCursorAt].
/// - **Styling** — строит [resolver] из темы, слоёв хоста, диагностики и подсветки.
/// - **Language features** — необязательный [EditorLanguageService] для LSP-подсветки/inlay.
/// - **Diagnostics** — [setDiagnostics] для подчёркиваний и inline «призрачных» сообщений.
///
/// ## Пример
///
/// ```dart
/// final controller = EditorController(
///   initialText: 'hello',
///   readOnly: false,
///   fallbackWordOccurrence: true,
/// );
///
/// controller.setDiagnostics([
///   EditorDiagnostic(
///     range: Range(0, 5),
///     message: 'Typo',
///     severity: DiagnosticSeverity.warning,
///   ),
/// ]);
///
/// controller.executeCommand('typeCharacter', character: '!');
/// ```
///
/// ## Режим только чтения
///
/// Когда [readOnly] равен `true`, [apply] и большинство вызовов [executeCommand]
/// возвращают `null` без изменения документа. Исключение в [executeCommand] — имя
/// `undo`. [undo]/[redo] и [perform] при этом не блокируются; клавиатура в read-only
/// фильтруется в [EditorInputHandler].
final class EditorController extends ChangeNotifier {
  /// Создаёт контроллер с необязательным начальным документом или текстом.
  ///
  /// Укажите [document] или [initialText]; если оба опущены, создаётся пустой
  /// документ. [config] и [theme] по умолчанию — константы библиотеки.
  ///
  /// [fallbackWordOccurrence] включает локальную подсветку по границам слова, когда
  /// [languageService] не подключён или не возвращает вхождения.
  EditorController({
    String? initialText,
    Document? document,
    EditorConfig? config,
    EditorTheme? theme,
    this._host,
    this.languageService,
    this.readOnly = false,
    this.fallbackWordOccurrence = true,
    EditorActionRegistry? actionRegistry,
  }) : document = document ?? Document.fromText(initialText ?? ''),
       actionRegistry = actionRegistry ?? EditorActionRegistry(),
       config = config ?? const EditorConfig(),
       _theme = theme ?? const EditorTheme.dark() {
    engine = Transaction(document: this.document);
    commands = CommandRegistry(config: config);
    transientLayer = TransientStyleLayer(
      documentVersion: this.document.version,
      theme: _theme,
    );
    _rebuildResolver();
    _refreshCaretHighlights();
  }

  /// Редактируемый текстовый буфер.
  final Document document;

  /// Флаги поведения редактора (перенос слов, размер таба и т.д.).
  final EditorConfig config;

  EditorTheme _theme;

  /// Цвета, шрифты и токены темы для диагностики/inlay.
  EditorTheme get theme => _theme;

  /// При `true` блокирует правки, кроме undo.
  final bool readOnly;

  /// Подсвечивает слово под кареткой, когда language service ничего не возвращает.
  final bool fallbackWordOccurrence;

  /// Колбэки и стилевые слои от хоста; обновляется через [setHost].
  EditorHost? _host;

  /// Необязательный LSP/анализаторный бэкенд; задаётся через [setLanguageService].
  EditorLanguageService? languageService;

  /// Низкоуровневый движок правок (транзакции, стек undo, хранение выделения).
  late final Transaction engine;

  /// Именованные команды редактирования (`backspace`, `insertNewline`, `typeCharacter`, …).
  late final CommandRegistry commands;

  /// Реестр кастомных действий ([EditorActionRegistry.registerCustom]).
  ///
  /// Используется [EditorCustomMenuItem] с [EditorCustomMenuItem.actionId]
  /// и [performCustom]. Если [EditorActionConfiguration.registry] не задан,
  /// меню и [EditorInputHandler] используют этот экземпляр.
  final EditorActionRegistry actionRegistry;

  /// Временный слой подсветки (скобки, вхождения, IME preedit).
  late TransientStyleLayer transientLayer;

  /// Объединённый style resolver, используемый представлением для отрисовки текста.
  late StyleResolver resolver;

  var _resolverInitialized = false;

  /// Focus node, подключённый к [EditorScrollable] для клавиатуры и IME.
  final FocusNode focusNode = FocusNode();

  /// Состояние прокрутки и видимых строк, общее с painter представления.
  final ViewportState viewport = ViewportState();

  /// Видимый диапазон для [EditorHost.styleLayersFor] (обновляется из [EditorScrollable]).
  ViewportStyleScope? _styleViewport;

  /// Текущий viewport для стилевых слоёв хоста или `null` (полный snapshot).
  ViewportStyleScope? get styleViewport => _styleViewport;

  /// Обновляет viewport hint для хоста; при смене диапазона пересобирает resolver.
  ///
  /// При прокрутке передавайте `notify: false` — repaint даст scroll listenable,
  /// а [EditorScrollable] инвалидирует кэш строк viewport'а.
  void updateStyleViewport(ViewportStyleScope scope, {bool notify = true}) {
    final prev = _styleViewport;
    if (prev == scope) return;
    _styleViewport = scope;
    resolver.applyViewportHint(scope);
    final viewportLinesChanged =
        prev == null ||
        prev.firstLine != scope.firstLine ||
        prev.lastLineExclusive != scope.lastLineExclusive;
    if (viewportLinesChanged && languageService != null) {
      _requestInlayHints();
    }
    if (notify) notifyListeners();
  }

  /// Scope для syntax: scroll-окно + [ViewportStyleScope.caretSearchRange] вне экрана.
  ViewportStyleScope computeStyleViewportScope() =>
      ViewportStyleScope.fromViewport(
        document: document,
        viewport: viewport,
        lineHeightPx: theme.lineHeightPx,
        caretLine: document.lineCount > 0
            ? document.positionAt(selection.primary.head).line
            : null,
      );

  /// Синхронизирует [_styleViewport] с текущими scroll и кареткой.
  void syncStyleViewportFromEditorState({bool notify = true}) {
    updateStyleViewport(computeStyleViewportScope(), notify: notify);
  }

  /// Текущее выделение (основное + дополнительные каретки для мультикурсора).
  SelectionState get selection => engine.selection;

  /// Временная подсветка: пары скобок, вхождения символов, связанное редактирование.
  ///
  /// Производится из [transientLayer]; возвращаемый список неизменяем.
  List<HighlightSpan> get highlights =>
      List<HighlightSpan>.unmodifiable(transientLayer.highlights);

  /// Есть ли записи в стеке undo.
  bool get canUndo => engine.undoStack.canUndo;

  /// Есть ли записи в стеке redo.
  bool get canRedo => engine.undoStack.canRedo;

  /// Последний [DocumentChange] от правки, команды, undo или redo.
  DocumentChange? get lastChange => _lastChange;

  /// Последнее зафиксированное изменение документа (для хоста/отладки).
  DocumentChange? _lastChange;

  /// Последние span'ы от [languageService] (вхождения + linked editing).
  List<HighlightSpan> _languageHighlights = const [];

  /// Счётчик async-запросов подсветки; устаревшие ответы отбрасываются.
  var _highlightRequestGeneration = 0;

  /// Таймер debounce перед [_requestLanguageHighlights] (LSP `documentHighlight` +
  /// `linkedEditingRange`); снижает нагрузку на analyzer при быстром вводе.
  Timer? _languageHighlightDebounce;

  /// Длительность debounce LSP-подсветки каретки (VS Code «word highlight» ≈ 100–150 мс).
  static const _languageHighlightsDebounceDuration = Duration(
    milliseconds: 120,
  );

  List<EditorDiagnostic> _diagnostics = const [];
  List<StyleSpan> _cachedDiagnosticSpans = const [];
  List<InlineDiagnosticLabel> _inlineDiagnosticLabels = const [];
  List<EditorInlayHint> _inlayHints = const [];

  /// Счётчик async-запросов inlay hints.
  var _inlayRequestGeneration = 0;

  /// Таймер debounce перед [_fetchInlayHintsNow].
  Timer? _inlayDebounce;

  EditorLinkTarget? _linkTarget;
  var _linkRequestGeneration = 0;
  Timer? _linkDebounce;
  TextOffset? _lastLinkHoverOffset;
  Range? _linkHoverDebounceWord;
  TextOffset? _pendingReveal;

  /// Активна ли ссылка под Ctrl/Cmd+hover.
  bool get hasActiveLink => _linkTarget != null;

  /// Диапазон подчёркивания ссылки или `null`.
  Range? get linkHighlightRange => _linkTarget?.highlightRange;

  /// Диагностика от LSP или хоста (волнистые подчёркивания + фон строк).
  List<EditorDiagnostic> get diagnostics =>
      List<EditorDiagnostic>.unmodifiable(_diagnostics);

  /// «Призрачные» сообщения после кода на каждой строке; производятся из [diagnostics].
  List<InlineDiagnosticLabel> get inlineDiagnosticLabels =>
      _inlineDiagnosticLabels;

  /// Виртуальные аннотации (типы, имена параметров) из LSP inlay hints.
  ///
  /// Возвращает только hints в текущем scroll-окне ([styleViewport]), как
  /// viewport-aware spans у стилевых слоёв.
  List<EditorInlayHint> get inlayHints {
    final scope = _styleViewport;
    if (scope == null) {
      return List<EditorInlayHint>.unmodifiable(_inlayHints);
    }
    return List<EditorInlayHint>.unmodifiable(
      inlayHintsInViewport(_inlayHints, scope),
    );
  }

  /// Заменяет inlay hints и уведомляет слушателей.
  ///
  /// Обычно вызывается внутренне после завершения [EditorLanguageService.inlayHints];
  /// хосты могут также задавать hints напрямую для тестирования.
  void setInlayHints(List<EditorInlayHint> value) {
    _inlayHints = List<EditorInlayHint>.of(value);
    notifyListeners();
  }

  /// Заменяет диагностику, пересобирает inline-метки и decoration spans.
  ///
  /// Вызывает [notifyListeners] и [_rebuildResolver], чтобы подчёркивания и
  /// фон строк с ошибками появились при следующей отрисовке.
  void setDiagnostics(List<EditorDiagnostic> value) {
    _diagnostics = List<EditorDiagnostic>.of(value);
    _refreshDiagnosticDecorations();
    _rebuildResolver();
    notifyListeners();
  }

  /// Пересобирает decoration spans и inline-метки из [_diagnostics] и текущего [document].
  ///
  /// Вызывается после [setDiagnostics] и при каждой правке документа, чтобы номера
  /// строк и диапазоны не устаревали до следующего ответа LSP.
  void _refreshDiagnosticDecorations() {
    if (_diagnostics.isEmpty) {
      _cachedDiagnosticSpans = const [];
      _inlineDiagnosticLabels = const [];
      return;
    }
    _cachedDiagnosticSpans = diagnosticDecorationSpans(
      document: document,
      diagnostics: _diagnostics,
      theme: theme,
    );
    _inlineDiagnosticLabels = diagnosticInlineLabels(
      document: document,
      diagnostics: _diagnostics,
    );
  }

  /// Подключает или отключает [EditorHost] для стилевых слоёв и колбэков.
  ///
  /// Передача `null` удаляет синтаксические/токенные слои хоста. Немедленно
  /// пересобирает [resolver].
  void setHost(EditorHost? host) {
    _host = host;
    _rebuildResolver();
    notifyListeners();
  }

  /// Подключает или заменяет [languageService].
  ///
  /// При установке ненулевого сервиса inlay hints запрашиваются сразу.
  /// При отключении inlay hints сбрасываются в пустой список.
  void setLanguageService(EditorLanguageService? service) {
    languageService = service;
    _refreshCaretHighlights();
    if (service != null) {
      _fetchInlayHintsNow();
    } else {
      setInlayHints(const []);
    }
  }

  /// Заменяет [theme] и пересобирает resolver, диагностику и transient-слой.
  void updateTheme(EditorTheme newTheme) {
    if (_theme == newTheme) return;
    _theme = newTheme;
    final prev = transientLayer;
    transientLayer = TransientStyleLayer(
      theme: newTheme,
      documentVersion: document.version,
      preeditRange: prev.preeditRange,
      preeditColor: prev.preeditColor,
      highlights: prev.highlights,
      linkHoverRange: prev.linkHoverRange,
    );
    _refreshDiagnosticDecorations();
    _resolverInitialized = false;
    _rebuildResolver();
    notifyListeners();
  }

  /// Пересобирает [resolver] из текущих слоёв хоста без изменения документа.
  ///
  /// Вызывайте после завершения асинхронной токенизации, когда [EditorHost.styleLayersFor]
  /// может вернуть обновлённые spans для текущей [document.version].
  void refreshStyleLayers() {
    syncStyleViewportFromEditorState(notify: false);
    _rebuildResolver();
    notifyListeners();
  }

  /// Задаёт spans подсветки от language service (вхождения, связанное редактирование).
  ///
  /// Подсветка скобок объединяется автоматически в [_refreshCaretHighlights].
  /// Не заменяет подсветку скобок из [caretHighlightsFor].
  void setLanguageHighlights(List<HighlightSpan> spans) {
    _languageHighlights = spans;
    _refreshCaretHighlights();
  }

  /// Очищает language highlights.
  ///
  /// Если указан [kind], удаляются только spans этого [HighlightKind];
  /// иначе очищаются все language highlights. Если задано [cancelPendingRequest],
  /// отменяет также не запущенный debounce LSP-подсветки.
  void clearLanguageHighlights([HighlightKind? kind]) {
    if (kind == null) {
      _languageHighlightDebounce?.cancel();
      _languageHighlightDebounce = null;
      _highlightRequestGeneration++;
    }
    _languageHighlights = kind == null
        ? const []
        : [
            for (final s in _languageHighlights)
              if (s.kind != kind) s,
          ];
    _refreshCaretHighlights();
  }

  /// Пересобирает [StyleResolver] из темы, хоста, диагностики и временных слоёв.
  ///
  /// Порядок слоёв (от низкого к высокому приоритету):
  /// 1. [BaseStyleLayer] — цвет текста по умолчанию из темы.
  /// 2. Слои хоста из [_host?.styleLayersFor].
  /// 3. [DecorationStyleLayer] — подчёркивания диагностики (при наличии diagnostics).
  /// 4. [transientLayer] — подсветка каретки и диапазон IME preedit.
  void _rebuildResolver() {
    final layers = <StyleLayer>[
      BaseStyleLayer(theme, documentVersion: document.version),
      ...?_host?.styleLayersFor(document.version, viewport: _styleViewport),
      if (_diagnostics.isNotEmpty)
        DecorationStyleLayer(
          documentVersion: document.version,
          spans: _cachedDiagnosticSpans,
        ),
      transientLayer,
    ];
    transientLayer
      ..documentVersion = document.version
      ..preeditRange = _compositionRange;
    if (!_resolverInitialized) {
      resolver = StyleResolver(theme: theme, layers: layers);
      _resolverInitialized = true;
    } else {
      resolver.replaceLayers(layers);
    }
  }

  /// Диапазон IME preedit в документе или `null`, если композиции нет.
  Range? _compositionRange;

  /// Активный диапазон IME-композиции (preedit) или `null`.
  Range? get compositionRange => _compositionRange;

  /// Задаёт диапазон IME-композиции (preedit) для стиля подчёркивания.
  ///
  /// Вызывается [EditorTextInputClient] на мобильных платформах. Передача `null`
  /// очищает подсветку preedit.
  void setCompositionRange(Range? range) {
    _compositionRange = range;
    transientLayer.preeditRange = range;
    resolver.styleEpoch++;
    notifyListeners();
  }

  /// Применяет список операций [TextEdit] как одну отменяемую транзакцию.
  ///
  /// Возвращает получившийся [DocumentChange] или `null`, когда [readOnly] равен
  /// `true` или список правок пуст/некорректен.
  DocumentChange? apply(List<TextEdit> edits) {
    if (readOnly) return null;
    final change = engine.apply(edits);
    _afterChange(change);
    return change;
  }

  /// Выполняет зарегистрированную команду редактирования по [name].
  ///
  /// Некоторые команды принимают [character] (`typeCharacter`) или [pasteText] (`paste`).
  /// Возвращает `null`, когда [readOnly] равен `true` (кроме `undo`) или команда неизвестна.
  DocumentChange? executeCommand(
    String name, {
    String? character,
    String? pasteText,
  }) {
    if (readOnly && name != 'undo') return null;
    final change = commands.execute(
      engine,
      name,
      character: character,
      pasteText: pasteText,
    );
    _afterChange(change);
    return change;
  }

  /// Есть ли несхлопнутое выделение для копирования.
  bool get canCopy => hasCopyableSelection(selection.selections);

  /// Вырезание: [canCopy] и не [readOnly].
  bool get canCut => canCopy && !readOnly;

  /// Вставка разрешена, когда редактор не только для чтения.
  bool get canPaste => !readOnly;

  /// Копирует выделенный текст в системный буфер.
  ///
  /// При нескольких каретках фрагменты разделяются `\n` (см. [copyTextForSelections]).
  /// Работает в [readOnly]. Возвращает `false`, если нечего копировать.
  Future<bool> copy() async {
    final text = copyTextForSelections(document, selection.selections);
    if (text.isEmpty) return false;
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  /// Копирует выделение в буфер и удаляет его.
  Future<bool> cut() async {
    if (!canCut) return false;
    final text = copyTextForSelections(document, selection.selections);
    if (text.isEmpty) return false;
    await Clipboard.setData(ClipboardData(text: text));
    return executeCommand('cut') != null;
  }

  /// Вставляет [text] или содержимое буфера в позиции кареток.
  ///
  /// Заменяет выделение на каждой каретке. Если число строк буфера совпадает с числом
  /// кареток, строки распределяются по одной на каретку; иначе весь текст вставляется
  /// в каждую позицию. Триггеры: [EditorActionConfiguration], [EditorActions.perform].
  Future<bool> paste([String? text]) async {
    if (!canPaste) return false;
    final data = text ?? (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (data == null || data.isEmpty) return false;
    return executeCommand('paste', pasteText: data) != null;
  }

  /// Выделяет весь документ.
  void selectAll() {
    final len = document.length;
    setPrimarySelection(Selection(0, len));
  }

  /// Выполняет встроенное [EditorActionId].
  ///
  /// Обёртка над [EditorActions.perform]. Для [EditorActionId.typeCharacter]
  /// передайте [character]; для [EditorActionId.paste] — опционально [pasteText].
  /// [clipboardStatus] учитывается при проверке paste.
  Future<bool> perform(
    EditorActionId action, {
    String? character,
    String? pasteText,
    bool extendSelection = false,
    ClipboardStatus clipboardStatus = ClipboardStatus.unknown,
  }) => EditorActions.perform(
    EditorActionContext(controller: this, clipboardStatus: clipboardStatus),
    EditorActionInvocation(
      action,
      character: character,
      pasteText: pasteText,
      extendSelection: extendSelection,
    ),
    registry: actionRegistry,
  );

  /// Проверяет доступность [action] (кнопки тулбара, условное меню хоста).
  ///
  /// Учитывает [readOnly], undo/redo, выделение и [clipboardStatus] для paste.
  bool canPerform(
    EditorActionId action, {
    ClipboardStatus clipboardStatus = ClipboardStatus.unknown,
  }) => EditorActions.canExecute(
    EditorActionContext(controller: this, clipboardStatus: clipboardStatus),
    EditorActionInvocation(action),
    registry: actionRegistry,
  );

  /// Выполняет кастомное действие по [actionId] из [actionRegistry].
  ///
  /// Возвращает `false`, если id не зарегистрирован или [canExecute] запретил вызов.
  Future<bool> performCustom(String actionId) => actionRegistry.performCustom(
    actionId,
    EditorActionContext(controller: this),
  );

  /// Отменяет последнюю транзакцию.
  ///
  /// Возвращает [DocumentChange], описывающий откат, или `null`, если стек undo пуст.
  DocumentChange? undo() {
    final change = engine.undo();
    _afterChange(change);
    return change;
  }

  /// Повторяет последнюю отменённую транзакцию.
  DocumentChange? redo() {
    final change = engine.redo();
    _afterChange(change);
    return change;
  }

  /// Заменяет полное состояние выделения и уведомляет хост/слушателей.
  ///
  /// При [syncDesiredFromHeads] желаемые столбцы берутся из позиции каждой каретки
  /// (клик, ←→, ввод). Иначе сохраняются [SelectionState.desiredColumns], если заданы.
  ///
  /// Вызывает [_host?.onSelectionChanged] и обновляет подсветку каретки.
  void setSelection(SelectionState value, {bool syncDesiredFromHeads = false}) {
    final normalized = _normalizeSelectionDesired(value, syncDesiredFromHeads);
    final old = selection;
    engine.selection = normalized;
    final sc = SelectionChange(oldValue: old, newValue: normalized);
    _host?.onSelectionChanged(sc);
    _refreshCaretHighlights();
    notifyListeners();
  }

  SelectionState _normalizeSelectionDesired(
    SelectionState value,
    bool syncFromHeads,
  ) {
    final sels = value.selections;
    if (syncFromHeads) {
      return value.withDesiredColumns(
        CaretDesiredColumn.fromHeads(document, sels),
      );
    }
    if (value.hasDesiredColumns) {
      return value;
    }
    return value.withDesiredColumns(
      CaretDesiredColumn.align(document, sels, value.desiredColumns),
    );
  }

  /// Обновляет только основное выделение, сохраняя дополнительные каретки.
  void setPrimarySelection(Selection selection) {
    setSelection(
      engine.selection.withPrimary(selection),
      syncDesiredFromHeads: true,
    );
  }

  /// Добавляет свёрнутую каретку в [offset] для мультикурсорного редактирования.
  ///
  /// Удерживайте Alt при клике в представлении — это вызывается из [EditorScrollable].
  void addCursorAt(TextOffset offset) {
    final next = List<Selection>.of(selection.selections)
      ..add(Selection(offset, offset));
    setSelection(SelectionState(mergeOverlappingSelections(next)));
  }

  /// Сворачивает к одной каретке в [offset], удаляя лишние курсоры.
  void setSingleCursor(TextOffset offset) {
    setSelection(
      SelectionState([Selection(offset, offset)]),
      syncDesiredFromHeads: true,
    );
  }

  /// URI открытого документа ([EditorHost.editorDocumentUri]).
  String? get documentUri => _host?.editorDocumentUri;

  /// Запрашивает подсветку ссылки при Ctrl/Cmd+hover ([offset] или сброс при `null`).
  void updateLinkHover(TextOffset? offset) {
    if (offset == null) {
      _linkDebounce?.cancel();
      _lastLinkHoverOffset = null;
      _linkHoverDebounceWord = null;
      _clearLinkHover();
      return;
    }

    if (offset == _lastLinkHoverOffset) return;
    _lastLinkHoverOffset = offset;

    final active = _linkTarget;
    if (active != null && _containsOffset(active.highlightRange, offset)) {
      return;
    }

    final text = document.text;

    // URL подчёркивается сразу, без ожидания LSP.
    final urlRange = urlRangeAt(text, offset);
    if (urlRange != null) {
      final url = text.characters
          .getRange(urlRange.start, urlRange.end)
          .toString();
      _setLinkTarget(
        EditorLinkTarget(
          highlightRange: urlRange,
          destination: EditorDocumentLocation(uri: url, range: urlRange),
        ),
      );
    }

    // Debounce только при смене «зоны» (слово); движение внутри слова не сбрасывает таймер.
    final word = wordRangeAt(text, offset);
    if (word != null &&
        word == _linkHoverDebounceWord &&
        _linkDebounce?.isActive == true) {
      return;
    }
    _linkHoverDebounceWord = word;
    _linkDebounce?.cancel();
    _linkDebounce = Timer(const Duration(milliseconds: 80), () {
      final at = _lastLinkHoverOffset;
      if (at != null) _fetchLinkTargetAt(at);
    });
  }

  /// Сбрасывает подсветку ссылки (отпускание модификатора / уход мыши).
  void clearLinkHover() => _clearLinkHover();

  /// Переход по ссылке в [offset] (Ctrl/Cmd+клик). Возвращает `true`, если переход выполнен.
  Future<bool> followLinkAt(TextOffset offset) async {
    final target =
        _linkTarget != null &&
            _containsOffset(_linkTarget!.highlightRange, offset)
        ? _linkTarget!
        : await _resolveLinkTarget(offset);
    if (target == null) return false;

    if (_isSameDocumentUri(target.destination.uri) &&
        !isWebNavigationUri(target.destination.uri)) {
      _jumpToLocationInOpenDocument(target.destination);
    }
    _host?.onNavigate(target.destination);
    _clearLinkHover();
    return true;
  }

  /// Смещение для прокрутки viewport после навигации; забирается представлением.
  TextOffset? consumePendingReveal() {
    final value = _pendingReveal;
    _pendingReveal = null;
    return value;
  }

  void _clearLinkHover({bool notify = true}) {
    _linkRequestGeneration++;
    _linkDebounce?.cancel();
    _linkHoverDebounceWord = null;
    if (_linkTarget == null && transientLayer.linkHoverRange == null) return;
    _linkTarget = null;
    transientLayer.linkHoverRange = null;
    resolver.styleEpoch++;
    if (notify) notifyListeners();
  }

  void _setLinkTarget(EditorLinkTarget target) {
    final prev = _linkTarget;
    if (prev != null &&
        prev.highlightRange == target.highlightRange &&
        prev.destination.uri == target.destination.uri) {
      return;
    }
    _linkTarget = target;
    transientLayer.linkHoverRange = target.highlightRange;
    resolver.styleEpoch++;
    notifyListeners();
  }

  void _fetchLinkTargetAt(TextOffset offset) {
    final gen = ++_linkRequestGeneration;
    final text = document.text;
    final version = document.version;

    Future<void> load() async {
      final target = await _resolveLinkTarget(
        offset,
        text: text,
        documentVersion: version,
      );
      if (gen != _linkRequestGeneration) return;
      if (document.version != version) return;

      if (target == null) {
        if (_linkTarget != null) _clearLinkHover();
        return;
      }

      _setLinkTarget(target);
    }

    load();
  }

  Future<EditorLinkTarget?> _resolveLinkTarget(
    TextOffset offset, {
    String? text,
    int? documentVersion,
  }) async {
    final buffer = text ?? document.text;
    final version = documentVersion ?? document.version;
    final service = languageService;

    if (service != null) {
      final fromLsp = await service.linkTargetAt(
        text: buffer,
        documentVersion: version,
        offset: offset,
      );
      if (fromLsp != null) return fromLsp;
    }

    final urlRange = urlRangeAt(buffer, offset);
    if (urlRange == null) return null;
    final url = buffer.characters
        .getRange(urlRange.start, urlRange.end)
        .toString();
    return EditorLinkTarget(
      highlightRange: urlRange,
      destination: EditorDocumentLocation(uri: url, range: urlRange),
    );
  }

  /// Сравнивает [open] с [documentUri] контроллера (нормализация через [Uri.parse]).
  bool _isSameDocumentUri(String targetUri) {
    final open = documentUri;
    if (open == null) return false;
    return Uri.parse(open) == Uri.parse(targetUri);
  }

  /// Переносит каретку на [location.range.start] и планирует reveal для [EditorScrollable].
  void _jumpToLocationInOpenDocument(EditorDocumentLocation location) {
    final len = document.length;
    var start = location.range.start;
    if (start < 0) start = 0;
    if (start > len) start = len;
    setSingleCursor(start);
    _pendingReveal = start;
  }

  /// Полуоткрытый диапазон: [offset] на [range.end] не входит.
  static bool _containsOffset(Range range, TextOffset offset) =>
      offset >= range.start && offset < range.end;

  /// Хук после правки: колбэк хоста, пересборка resolver, подсветка, debounce inlay.
  ///
  /// [EditorHost.onDocumentChanged] вызывается до [_rebuildResolver], чтобы хост успел
  /// обновить данные стилевых слоёв (например, dirty-маску до ответа LSP).
  void _afterChange(DocumentChange? change) {
    if (change == null) return;
    engine.selection = _normalizeSelectionDesired(engine.selection, true);
    _clearLinkHover(notify: false);
    _lastChange = change;
    _host?.onDocumentChanged(change);
    syncStyleViewportFromEditorState(notify: false);
    _refreshDiagnosticDecorations();
    _rebuildResolver();
    _refreshCaretHighlights();
    _requestInlayHints();
    notifyListeners();
  }

  /// Планирует запрос inlay hints через 300 мс бездействия после правок.
  void _requestInlayHints() {
    final service = languageService;
    if (service == null) return;

    _inlayDebounce?.cancel();
    _inlayDebounce = Timer(
      const Duration(milliseconds: 300),
      _fetchInlayHintsNow,
    );
  }

  /// Запрашивает inlay hints для всего документа, отбрасывая устаревшие ответы.
  ///
  /// Использует защиту [_inlayRequestGeneration] и [document.version], чтобы поздние
  /// async-завершения не перезаписывали hints для более нового состояния документа.
  void _fetchInlayHintsNow() {
    final service = languageService;
    if (service == null) return;

    final gen = ++_inlayRequestGeneration;
    final text = document.text;
    final version = document.version;
    final scope = _styleViewport ?? computeStyleViewportScope();
    final fetchRange = inlayHintFetchRange(scope);

    /// Async-загрузка hints; отменяется при смене [document.version] или поколения.
    Future<void> load() async {
      final hints = await service.inlayHints(
        text: text,
        documentVersion: version,
        range: fetchRange,
      );
      if (gen != _inlayRequestGeneration) return;
      if (document.version != version) return;
      setInlayHints(filterInlayHintsForRange(hints, fetchRange));
    }

    load();
  }

  /// Пересчитывает временную подсветку для текущей позиции каретки.
  ///
  /// Когда основное выделение не свёрнуто, подсветка очищается.
  /// Иначе объединяет подсветку скобок, [_languageHighlights] и необязательный
  /// fallback по вхождениям слова, затем запрашивает async language highlights.
  void _refreshCaretHighlights() {
    final caret = selection.primary;
    if (!caret.isCollapsed) {
      if (transientLayer.highlights.isNotEmpty) {
        transientLayer.highlights = const [];
        transientLayer.documentVersion = document.version;
        resolver.styleEpoch++;
      } else {
        transientLayer.documentVersion = document.version;
      }
      return;
    }

    final offset = caret.head;
    final scope = _styleViewport ?? computeStyleViewportScope();
    final fetchRange = inlayHintFetchRange(scope);
    final slice = (
      text: document.getText(fetchRange),
      baseOffset: fetchRange.start,
    );
    final next = caretHighlightsFor(
      text: slice.text,
      textBaseOffset: slice.baseOffset,
      offset: offset,
      searchRange: fetchRange,
      languageSpans: _languageHighlights,
      fallbackWordOccurrence: fallbackWordOccurrence,
    );
    transientLayer.documentVersion = document.version;
    if (!_highlightsEqual(transientLayer.highlights, next)) {
      transientLayer.highlights = next;
      resolver.styleEpoch++;
    }
    _requestLanguageHighlights(offset);
  }

  /// Побайтовое сравнение списков подсветки — без лишнего [notifyListeners].
  static bool _highlightsEqual(List<HighlightSpan> a, List<HighlightSpan> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].range != b[i].range || a[i].kind != b[i].kind) return false;
    }
    return true;
  }

  /// Планирует LSP-запрос подсветки (`documentHighlight` + `linkedEditingRange`)
  /// с debounce; ранее запланированный запрос отменяется.
  ///
  /// Без debounce два LSP-вызова уходили на КАЖДУЮ клавишу и конкурировали за
  /// тот же analyzer с `semanticTokens/full`, удлиняя «лаг» подсветки.
  void _requestLanguageHighlights(TextOffset offset) {
    final service = languageService;
    if (service == null) return;

    _languageHighlightDebounce?.cancel();
    _languageHighlightDebounce = Timer(
      _languageHighlightsDebounceDuration,
      () => _fetchLanguageHighlightsNow(service, offset),
    );
  }

  /// Запрашивает подсветку документа и связанного редактирования у [service].
  ///
  /// Отбрасывает результаты, если поколение, версия документа или смещение каретки
  /// больше не совпадают со снимком запроса.
  void _fetchLanguageHighlightsNow(
    EditorLanguageService service,
    TextOffset offset,
  ) {
    if (selection.primary.head != offset) return;

    final gen = ++_highlightRequestGeneration;
    final text = document.text;
    final version = document.version;

    /// Два последовательных LSP-запроса; отбрасывает результат при смене каретки/версии.
    Future<void> load() async {
      final occurrences = await service.documentHighlights(
        text: text,
        documentVersion: version,
        offset: offset,
      );
      if (gen != _highlightRequestGeneration) return;
      if (document.version != version) return;

      final linked = await service.linkedEditingHighlights(
        text: text,
        documentVersion: version,
        offset: offset,
      );
      if (gen != _highlightRequestGeneration) return;
      if (document.version != version) return;
      if (selection.primary.head != offset) return;

      _languageHighlights = [...occurrences, ...linked];
      final scope = _styleViewport ?? computeStyleViewportScope();
      final fetchRange = inlayHintFetchRange(scope);
      final slice = (
        text: document.getText(fetchRange),
        baseOffset: fetchRange.start,
      );
      transientLayer.highlights = caretHighlightsFor(
        text: slice.text,
        textBaseOffset: slice.baseOffset,
        offset: offset,
        searchRange: fetchRange,
        languageSpans: _languageHighlights,
        fallbackWordOccurrence: fallbackWordOccurrence,
      );
      resolver.styleEpoch++;
      notifyListeners();
    }

    load();
  }

  @override
  void dispose() {
    _inlayDebounce?.cancel();
    _linkDebounce?.cancel();
    _languageHighlightDebounce?.cancel();
    focusNode.dispose();
    super.dispose();
  }
}
