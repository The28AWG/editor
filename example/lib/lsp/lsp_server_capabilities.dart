/// Parsed [initialize] server capabilities used by the example LSP client.
final class LspServerCapabilities {
  const LspServerCapabilities({
    this.documentHighlight = false,
    this.semanticTokens = false,
    this.semanticTokensRange = false,
    this.semanticTokensFullDelta = false,
    this.linkedEditing = false,
    this.inlayHints = false,
    this.definition = false,
    this.documentLink = false,
    this.completion = false,
    this.completionResolve = false,
    this.hover = false,
    this.signatureHelp = false,
  });

  factory LspServerCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LspServerCapabilities();

    final provider = json['semanticTokensProvider'] as Map<String, dynamic>?;
    var semanticTokensRange = false;
    var semanticTokensFullDelta = false;
    if (provider != null) {
      final requests = provider['requests'] as Map<String, dynamic>?;
      if (requests != null) {
        semanticTokensRange = requests['range'] == true;
        final full = requests['full'];
        if (full is Map<String, dynamic>) {
          semanticTokensFullDelta = full['delta'] == true;
        }
      }
    }

    final completionProvider = json['completionProvider'];
    var completionResolve = false;
    if (completionProvider is Map<String, dynamic>) {
      completionResolve = completionProvider['resolveProvider'] == true;
    }

    return LspServerCapabilities(
      documentHighlight: json['documentHighlightProvider'] == true,
      semanticTokens: provider != null,
      semanticTokensRange: semanticTokensRange,
      semanticTokensFullDelta: semanticTokensFullDelta,
      linkedEditing: json['linkedEditingRangeProvider'] == true,
      inlayHints: json['inlayHintProvider'] != null,
      definition: json['definitionProvider'] == true,
      documentLink:
          json['documentLinkProvider'] != null &&
          json['documentLinkProvider'] != false,
      completion: completionProvider != null && completionProvider != false,
      completionResolve: completionResolve,
      hover: json['hoverProvider'] == true,
      signatureHelp: json['signatureHelpProvider'] != null,
    );
  }

  final bool documentHighlight;
  final bool semanticTokens;
  final bool semanticTokensRange;
  final bool semanticTokensFullDelta;
  final bool linkedEditing;
  final bool inlayHints;
  final bool definition;
  final bool documentLink;
  final bool completion;
  final bool completionResolve;
  final bool hover;
  final bool signatureHelp;
}
