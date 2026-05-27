import 'package:editor/editor.dart';
import 'package:flutter_test/flutter_test.dart';

final class _StubLanguageService implements EditorLanguageService {
  _StubLanguageService(this.target);

  final EditorLinkTarget? target;

  @override
  Future<List<HighlightSpan>> documentHighlights({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) async => const [];

  @override
  Future<List<HighlightSpan>> linkedEditingHighlights({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) async => const [];

  @override
  Future<List<EditorInlayHint>> inlayHints({
    required String text,
    required int documentVersion,
    required Range range,
  }) async => const [];

  @override
  Future<EditorLinkTarget?> linkTargetAt({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) async {
    if (target == null) return null;
    if (offset >= target!.highlightRange.start &&
        offset < target!.highlightRange.end) {
      return target;
    }
    return null;
  }
}

final class _NavHost with EditorHost {
  _NavHost(this.uri);

  final String uri;
  EditorDocumentLocation? lastNavigate;

  @override
  List<StyleLayer> styleLayersFor(
    int documentVersion, {
    ViewportStyleScope? viewport,
  }) => const [];

  @override
  String? get editorDocumentUri => uri;

  @override
  void onNavigate(EditorDocumentLocation location) {
    lastNavigate = location;
  }
}

void main() {
  test('followLinkAt jumps within same document', () async {
    const uri = 'file:///proj/test.dart';
    const text = 'void foo() {}\nvoid bar() { foo(); }';
    final controller = EditorController(initialText: text);
    final host = _NavHost(uri);
    controller
      ..setHost(host)
      ..setLanguageService(
        _StubLanguageService(
          EditorLinkTarget(
            highlightRange: Range(26, 29),
            destination: const EditorDocumentLocation(
              uri: uri,
              range: Range(6, 9),
            ),
          ),
        ),
      );

    final ok = await controller.followLinkAt(27);
    expect(ok, isTrue);
    expect(controller.selection.primary.head, 6);
    expect(host.lastNavigate?.uri, uri);
    expect(host.lastNavigate?.range, const Range(6, 9));
  });

  test('updateLinkHover sets highlight range from language service', () async {
    const uri = 'file:///a.dart';
    final controller = EditorController(initialText: 'abc def')
      ..setHost(_NavHost(uri))
      ..setLanguageService(
        _StubLanguageService(
          const EditorLinkTarget(
            highlightRange: Range(4, 7),
            destination: EditorDocumentLocation(uri: uri, range: Range(0, 3)),
          ),
        ),
      )
      ..updateLinkHover(5);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(controller.linkHighlightRange, const Range(4, 7));
    expect(controller.hasActiveLink, isTrue);

    controller.clearLinkHover();
    expect(controller.hasActiveLink, isFalse);
  });

  test('urlRangeAt finds https links', () {
    const text = 'see https://dart.dev now';
    expect(urlRangeAt(text, 6), const Range(4, 20));
  });

  test('updateLinkHover highlights URL without debounce', () {
    const text = 'see https://dart.dev now';
    final controller = EditorController(initialText: text)..updateLinkHover(6);
    expect(controller.linkHighlightRange, const Range(4, 20));
    expect(controller.hasActiveLink, isTrue);
  });

  test('updateLinkHover skips duplicate offset', () async {
    var calls = 0;
    final _ = EditorController(initialText: 'abc def')
      ..setHost(_NavHost('file:///a.dart'))
      ..setLanguageService(
        _CountingLinkService(
          () => calls++,
          const EditorLinkTarget(
            highlightRange: Range(4, 7),
            destination: EditorDocumentLocation(
              uri: 'file:///a.dart',
              range: Range(0, 3),
            ),
          ),
        ),
      )
      ..updateLinkHover(5)
      ..updateLinkHover(5);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(calls, 1);
  });
}

final class _CountingLinkService implements EditorLanguageService {
  _CountingLinkService(this.onCall, this.target);

  final void Function() onCall;
  final EditorLinkTarget target;

  @override
  Future<List<HighlightSpan>> documentHighlights({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) async => const [];

  @override
  Future<List<HighlightSpan>> linkedEditingHighlights({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) async => const [];

  @override
  Future<List<EditorInlayHint>> inlayHints({
    required String text,
    required int documentVersion,
    required Range range,
  }) async => const [];

  @override
  Future<EditorLinkTarget?> linkTargetAt({
    required String text,
    required int documentVersion,
    required TextOffset offset,
  }) async {
    onCall();
    if (offset >= target.highlightRange.start &&
        offset < target.highlightRange.end) {
      return target;
    }
    return null;
  }
}
