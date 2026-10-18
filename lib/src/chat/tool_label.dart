/// Hermes' human-readable identity for a tool behind its deferred-tool bridge.
/// The protocol name stays on the call so starts, results and approvals match.
class ToolLabel {
  const ToolLabel({required this.name, required this.text, this.preview = ''});

  final String name;
  final String text;
  final String preview;

  static List<ToolLabel> decodeList(Object? value) {
    if (value is! List) return const [];
    return List.unmodifiable([
      for (final entry in value)
        if (entry case {'text': final String text} when text.trim().isNotEmpty)
          ToolLabel(
            name: entry['name'] is String ? entry['name'] as String : '',
            text: text.trim(),
            preview: entry['preview'] is String
                ? entry['preview'] as String
                : '',
          ),
    ]);
  }
}
