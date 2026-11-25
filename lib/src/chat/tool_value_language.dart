import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../files/code_highlight.dart'
    show hasCodeGrammar, kCodeHighlightMaxChars;
import 'json_tree_parser.dart';

/// The most characters of a tool input or output that are parsed to tell
/// whether it is JSON, and so the most the Tree view is offered for ("64 KB",
/// counted in characters). A parse of this size took about 10 ms on the UI
/// isolate in a debug test run (less in a release build). A JSON text above it
/// is coloured flat with no Tree and says so
/// ([ToolValueNotice.tooLongForTree]).
const int kToolJsonSniffMaxChars = 64 * 1024;

/// The most characters of a tool text that are coloured at all ("512 KB"):
/// the Files limit, [kCodeHighlightMaxChars]. Above it the text is plain and
/// says so ([ToolValueNotice.tooLongToColour]).
const int kToolValueColourMaxChars = kCodeHighlightMaxChars;

/// How many JSON parses tool values have made (sniffing, the tree). A test
/// reads it to see that a closed card parses nothing.
@visibleForTesting
int debugToolValueParses = 0;

/// Whether [text] is a JSON object or array, by a parse of at most
/// [kToolJsonSniffMaxChars] characters. A bare string, number or `null` is not
/// worth colouring as JSON, a text that fails to parse is not JSON, and a text
/// above the bound is not asked.
bool isJsonContainerText(String text) => tryDecodeJsonContainer(text) != null;

/// The deepest nesting the Tree view is offered for. The tree's widgets nest
/// one level per level of JSON and a few thousand levels overflow the stack,
/// so deeper JSON shows as flat text only.
const int kToolJsonTreeMaxDepth = 64;

/// The most nodes (every object, array and scalar, the root included) the
/// Tree view is offered for. The tree keeps one entry per node and builds a
/// row only for what is in view, but a JSON of 64 KB can still hold tens of
/// thousands of values; past this it is coloured flat and says "Too long for
/// the tree view." Checked on the decoded value, before any widget exists.
const int kToolJsonTreeMaxNodes = 2000;

/// How deep [text] nests brackets outside string literals, counted without
/// recursion and given up on once it passes [kToolJsonTreeMaxDepth]
/// (the result is then [kToolJsonTreeMaxDepth] + 1).
int jsonNestingDepth(String text) {
  var depth = 0;
  var deepest = 0;
  var inString = false;
  var escaped = false;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (unit == 0x5C) {
        escaped = true;
      } else if (unit == 0x22) {
        inString = false;
      }
    } else if (unit == 0x22) {
      inString = true;
    } else if (unit == 0x7B || unit == 0x5B) {
      if (++depth > deepest) deepest = depth;
      if (deepest > kToolJsonTreeMaxDepth) return deepest;
    } else if (unit == 0x7D || unit == 0x5D) {
      depth--;
    }
  }
  return deepest;
}

/// [tryDecodeJsonContainer] for the Tree view: null as well when [text] nests
/// deeper than [kToolJsonTreeMaxDepth], checked before anything is decoded.
Object? tryDecodeJsonTree(String text) =>
    jsonNestingDepth(text) > kToolJsonTreeMaxDepth
    ? null
    : tryDecodeJsonContainer(text);

/// The decoded object or array of [text] under the rules of
/// [isJsonContainerText]; null when it is not one.
Object? tryDecodeJsonContainer(String text) {
  if (text.length > kToolJsonSniffMaxChars) return null;
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
  debugToolValueParses++;
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
/// - [fence], the tag of a fenced block: that grammar, or null when the app
///   has none by that name.
/// - [isCommand], the `command` argument of a terminal call: shell.
/// - [path], the `path` argument of a file tool: its extension.
/// - otherwise the text, when it parses as a JSON object or array; a text
///   above [kToolJsonSniffMaxChars] is not parsed and counts as JSON when it
///   has the outline of one ([looksLikeJsonContainer]).
///
/// An extension this does not know, a [path] without one and a text that is
/// none of these give null.
String? toolValueLanguage(
  String text, {
  String? path,
  bool isCommand = false,
  String? fence,
}) {
  if (fence != null) return fenceLanguage(fence);
  if (isCommand) return 'bash';
  if (path != null) {
    final name = path.substring(path.lastIndexOf('/') + 1).toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1) {
      final language = _byExtension[name.substring(dot + 1)];
      if (language != null) return language;
    }
  }
  if (text.length > kToolJsonSniffMaxChars) {
    return looksLikeJsonContainer(text) ? 'json' : null;
  }
  return isJsonContainerText(text) ? 'json' : null;
}

/// Whether [text] has the outline of a JSON object or array, by its first and
/// last characters outside blanks. No parse: it is for a text too long to
/// parse, which is coloured as JSON all the same (a text that is not JSON
/// loses nothing but its colour).
bool looksLikeJsonContainer(String text) {
  var start = 0;
  var end = text.length - 1;
  bool blank(int unit) =>
      unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x0D;
  while (start <= end && blank(text.codeUnitAt(start))) {
    start++;
  }
  while (end > start && blank(text.codeUnitAt(end))) {
    end--;
  }
  if (start >= end) return false;
  final first = text.codeUnitAt(start);
  final last = text.codeUnitAt(end);
  final isObject = first == 0x7B && last == 0x7D;
  if (!isObject && !(first == 0x5B && last == 0x5D)) return false;
  // What follows the opener must be able to start a JSON entry, so a log
  // such as `[INFO] ...` that ends in `]` is not taken for JSON.
  var next = start + 1;
  while (next < end && blank(text.codeUnitAt(next))) {
    next++;
  }
  final c = text.codeUnitAt(next);
  if (isObject) return c == 0x22 || c == 0x7D;
  return c == 0x22 ||
      c == 0x7B ||
      c == 0x5B ||
      c == 0x5D ||
      c == 0x2D ||
      (c >= 0x30 && c <= 0x39) ||
      c == 0x74 ||
      c == 0x66 ||
      c == 0x6E;
}

const _fenceAliases = <String, String>{
  'py': 'python',
  'python3': 'python',
  'js': 'javascript',
  'ts': 'typescript',
  'sh': 'bash',
  'shell': 'bash',
  'zsh': 'bash',
  'console': 'bash',
  'yml': 'yaml',
  'html': 'xml',
  'rs': 'rust',
  'rb': 'ruby',
  'kt': 'kotlin',
  'md': 'markdown',
  'jsonc': 'json',
};

/// The grammar name a fence tag (`python`, `py`, `json title="x"`) stands for,
/// or null when it names none the app has.
String? fenceLanguage(String? tag) {
  if (tag == null) return null;
  final word = tag.trim().toLowerCase().split(RegExp(r'[\s{]')).first;
  if (word.isEmpty) return null;
  final name = _fenceAliases[word] ?? word;
  return hasCodeGrammar(name) && name != 'text' && name != 'plaintext'
      ? name
      : null;
}

/// What a settled tool text says about how it is shown, besides the view.
enum ToolValueNotice {
  /// Nothing to explain.
  none,

  /// Above [kToolValueColourMaxChars]: plain text, no switch.
  tooLongToColour,

  /// JSON above [kToolJsonSniffMaxChars] characters or [kToolJsonTreeMaxNodes]
  /// nodes: coloured flat, no switch.
  tooLongForTree,

  /// JSON nested deeper than [kToolJsonTreeMaxDepth]: coloured flat, no
  /// switch.
  tooDeepForTree,

  /// Within the limits of one text, but the open cards of the chat have used
  /// up the colouring they share ([ToolValueBudget]): plain, tree kept.
  colourBudgetSpent,
}

/// How one tool text is shown: its [language] (null is plain and names no
/// content), the decoded JSON when the Tree is on offer ([tree]) and the
/// [notice] for a text shown plainer than its content could be.
class ToolValueShape {
  const ToolValueShape({this.language, this.tree, required this.notice});

  /// The grammar the text is coloured with; null for plain text.
  final String? language;

  /// The nodes of the object or array, non-null only when the Tree is
  /// offered. Numbers are kept as written.
  final List<JsonTreeNode>? tree;

  final ToolValueNotice notice;

  bool get offersTree => tree != null;
}

/// The shape of [text] given the [language] [toolValueLanguage] found.
///
/// - A running call ([settled] false) is plain: its text grows with every
///   delta, and nothing is decided until it settles.
/// - Above [kToolValueColourMaxChars] it stays plain and says so.
/// - JSON above [kToolJsonSniffMaxChars], or nested deeper than
///   [kToolJsonTreeMaxDepth], is coloured flat with no Tree and says so; JSON
///   that does not parse is plain and unnamed.
/// - Code gets no Tree.
ToolValueShape toolValueShape(
  String text, {
  String? language,
  bool settled = true,
}) {
  const plain = ToolValueShape(notice: ToolValueNotice.none);
  if (!settled || language == null) return plain;
  if (text.length > kToolValueColourMaxChars) {
    // Nothing is coloured, so the text has no tag either.
    return const ToolValueShape(notice: ToolValueNotice.tooLongToColour);
  }
  if (language != 'json') {
    return ToolValueShape(language: language, notice: ToolValueNotice.none);
  }
  if (text.length > kToolJsonSniffMaxChars) {
    return const ToolValueShape(
      language: 'json',
      notice: ToolValueNotice.tooLongForTree,
    );
  }
  if (tryDecodeJsonContainer(text) == null) return plain;
  debugToolValueParses++;
  final parsed = parseJsonTree(
    text,
    maxDepth: kToolJsonTreeMaxDepth,
    maxNodes: kToolJsonTreeMaxNodes,
  );
  final nodes = parsed.nodes;
  if (nodes != null) {
    return ToolValueShape(
      language: 'json',
      tree: nodes,
      notice: ToolValueNotice.none,
    );
  }
  return ToolValueShape(
    language: 'json',
    notice: parsed.failure == JsonTreeFailure.tooDeep
        ? ToolValueNotice.tooDeepForTree
        : ToolValueNotice.tooLongForTree,
  );
}
