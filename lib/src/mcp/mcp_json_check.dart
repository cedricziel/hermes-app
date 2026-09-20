import 'dart:convert';

/// The result of checking the JSON editor's text on the device.
sealed class McpJsonCheck {
  const McpJsonCheck();
}

/// An object whose values are all objects: the shape of `mcp_servers`.
class McpJsonValid extends McpJsonCheck {
  const McpJsonValid(this.servers);

  final Map<String, Map<String, Object?>> servers;
}

/// [message] says what is wrong and where. It never quotes the text, which
/// can hold secrets.
class McpJsonInvalid extends McpJsonCheck {
  const McpJsonInvalid(this.message);

  final String message;
}

McpJsonCheck checkMcpServersJson(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    final offset = (e.offset ?? 0).clamp(0, text.length);
    final line = '\n'.allMatches(text.substring(0, offset)).length + 1;
    return McpJsonInvalid('Line $line: ${_reason(e.message)}');
  }
  if (decoded is! Map) {
    return const McpJsonInvalid(
      'The top level must be an object keyed by server name, and each '
      'server must be an object.',
    );
  }
  final servers = <String, Map<String, Object?>>{};
  for (final entry in decoded.entries) {
    final value = entry.value;
    if (value is! Map) {
      return McpJsonInvalid('"${entry.key}" must be an object.');
    }
    servers['${entry.key}'] = Map<String, Object?>.from(value);
  }
  return McpJsonValid(servers);
}

/// The first line of the parser's message without its position, which the
/// screen reports as a line number.
String _reason(String message) => message
    .split('\n')
    .first
    .replaceAll(RegExp(r'\s*\(at [^)]*\)'), '')
    .replaceAll(RegExp(r'\s+at (position|character) \d+'), '')
    .trim();
