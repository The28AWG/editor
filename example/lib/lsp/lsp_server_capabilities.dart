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
}
