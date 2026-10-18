import 'chat_models.dart';

/// Display-only names: never replace the protocol name used to settle a call.
extension ToolCallPresentation on ToolCall {
  bool get isToolBridge =>
      name == 'tool_call' || name == 'tool_search' || name == 'tool_describe';

  List<ToolLabel> get displayTools {
    if (labels.isNotEmpty) return labels;
    if (name != 'tool_call') return const [];
    final raw = args?['calls'];
    final entries = raw is List ? raw : [if (args != null) args];
    return [
      for (final entry in entries)
        if (entry is Map) _target(entry['name'], entry['arguments']),
    ];
  }

  /// Inner argument sets for a deferred invocation, in batch order.
  List<({String title, Map<String, Object?> arguments})> get argumentGroups {
    if (name != 'tool_call') return const [];
    final raw = args?['calls'];
    final entries = raw is List ? raw : [if (args != null) args];
    return [
      for (final entry in entries)
        if (entry case {'arguments': final Map arguments})
          (
            title:
                labels
                    .where((label) => label.name == entry['name'])
                    .firstOrNull
                    ?.text ??
                _target(entry['name'], arguments).text,
            arguments: {
              for (final entry in arguments.entries)
                if (entry.key is String) entry.key as String: entry.value,
            },
          ),
    ];
  }

  String get displayName {
    final tools = displayTools;
    if (tools.isNotEmpty) {
      return '${tools.first.text}${tools.length > 1 ? ' +${tools.length - 1}' : ''}';
    }
    return switch (name) {
      'tool_call' => 'Tool call',
      'tool_search' => 'Search tools',
      'tool_describe' => 'Tool details',
      '' => 'Tool',
      _ => name,
    };
  }

  String get displaySummary {
    if (preparing) return 'Preparing…';
    final tools = displayTools;
    if (tools.length == 1 && tools.first.preview.trim().isNotEmpty) {
      return tools.first.preview;
    }
    if (name == 'tool_search' || name == 'tool_describe') {
      final value = args?[name == 'tool_search' ? 'queries' : 'names'];
      if (value is String && value.trim().isNotEmpty) return value;
      if (value is List) {
        final text = value.whereType<String>().join(', ');
        if (text.isNotEmpty) return text;
      }
    }
    // New gateways may put the same friendly label in context as in labels.
    return summary.trim() == displayName ? '' : summary;
  }
}

ToolLabel _target(Object? rawName, Object? arguments) {
  final name = rawName is String ? rawName.trim() : '';
  var text = name.isEmpty ? 'Unnamed tool' : name;
  if (name.startsWith('mcp__') || name.startsWith('connectors__')) {
    final parts = name.split('__');
    if (parts.length >= 3 && parts[1].isNotEmpty) {
      text = '${parts[1]} · ${parts.skip(2).join('__').replaceAll('_', ' ')}';
    }
  }
  var preview = '';
  if (arguments is Map) {
    for (final key in const ['command', 'path', 'query', 'url', 'pattern']) {
      if (arguments[key] case final String value when value.trim().isNotEmpty) {
        preview = value.trim();
        break;
      }
    }
  }
  return ToolLabel(name: name, text: text, preview: preview);
}
