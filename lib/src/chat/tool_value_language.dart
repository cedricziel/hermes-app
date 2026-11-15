import 'dart:convert';

/// The most characters of a tool input or output that are parsed to tell
/// whether it is JSON. A parse of this size took about 10 ms on the UI
/// isolate in a debug test run (less in a release build); a larger text stays
/// plain.
const int kToolJsonSniffMaxChars = 64 * 1024;

/// Whether [text] is a JSON object or array, by a parse of at most
/// [kToolJsonSniffMaxChars] characters. A bare string, number or `null` is not
/// worth colouring as JSON, a text that fails to parse is not JSON, and a text
/// above the bound is not asked.
bool isJsonContainerText(String text) => tryDecodeJsonContainer(text) != null;

/// The decoded object or array of [text] under the rules of
/// [isJsonContainerText]; null when it is not one.
Object? tryDecodeJsonContainer(String text) {
  if (text.length > kToolJsonSniffMaxChars) return null;
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
  try {
    final decoded = jsonDecode(text);
    return decoded is Map || decoded is List ? decoded : null;
  } on FormatException {
    return null;
  }
}

const _byExtension = <String, String>{
  'py': 'python',
  'js': 'javascript',
  'mjs': 'javascript',
  'cjs': 'javascript',
  'jsx': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'json': 'json',
  'yaml': 'yaml',
  'yml': 'yaml',
  'toml': 'ini',
  'sh': 'bash',
  'bash': 'bash',
  'zsh': 'bash',
  'xml': 'xml',
  'html': 'xml',
  'htm': 'xml',
  'svg': 'xml',
  'css': 'css',
  'scss': 'scss',
  'sql': 'sql',
  'rs': 'rust',
  'go': 'go',
  'java': 'java',
  'kt': 'kotlin',
  'swift': 'swift',
  'c': 'c',
  'h': 'c',
  'cc': 'cpp',
  'cpp': 'cpp',
  'hpp': 'cpp',
  'rb': 'ruby',
  'php': 'php',
  'dart': 'dart',
  'lua': 'lua',
  'md': 'markdown',
  'markdown': 'markdown',
};

/// The grammar name to colour [text] with, or null to show it plain. Decided
/// on the client from what the call itself says, never from the server:
///
/// - [isCommand], the `command` argument of a terminal call: shell.
/// - [path], the `path` argument of a file tool: its extension.
/// - otherwise the text, when it parses as a JSON object or array.
///
/// An extension this does not know, a [path] without one and a text that is
/// none of these give null.
String? toolValueLanguage(String text, {String? path, bool isCommand = false}) {
  if (isCommand) return 'bash';
  if (path != null) {
    final name = path.substring(path.lastIndexOf('/') + 1).toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1) {
      final language = _byExtension[name.substring(dot + 1)];
      if (language != null) return language;
    }
  }
  return isJsonContainerText(text) ? 'json' : null;
}
