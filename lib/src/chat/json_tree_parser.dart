import 'dart:convert';

/// What a node of the tree is.
enum JsonTreeKind { object, array, string, number, literal }

/// One entry of a parsed JSON text, in document order.
///
/// [text] is what the node shows: a string decoded (display only), a number or
/// `true`, `false`, `null` exactly as it was written, so `1.50`, `1e3` and
/// `12345678901234567890` are never rewritten. [key] is the object key
/// decoded, null for the root and for an array item.
class JsonTreeNode {
  JsonTreeNode({
    required this.kind,
    required this.depth,
    required this.key,
    required this.text,
  });

  final JsonTreeKind kind;
  final int depth;
  final String? key;
  final String text;

  /// The number of entries of an object or array; 0 for any other node.
  int count = 0;

  /// The index after the last descendant: where the next sibling is.
  int end = 0;

  bool get isContainer =>
      kind == JsonTreeKind.object || kind == JsonTreeKind.array;
}

/// Why [parseJsonTree] gave no tree.
enum JsonTreeFailure { invalid, tooDeep, tooManyNodes }

/// The result of [parseJsonTree]: [nodes] or the reason there are none.
class JsonTreeParse {
  const JsonTreeParse.ok(List<JsonTreeNode> this.nodes) : failure = null;
  const JsonTreeParse.failed(JsonTreeFailure this.failure) : nodes = null;

  final List<JsonTreeNode>? nodes;
  final JsonTreeFailure? failure;
}

/// Parses [text], a JSON object or array, into a flat list of nodes without
/// recursion, giving up as soon as it nests deeper than [maxDepth] or has more
/// than [maxNodes] nodes, so a hostile text costs no more than the caps allow.
/// Object keys keep their order and duplicates stay.
JsonTreeParse parseJsonTree(
  String text, {
  required int maxDepth,
  required int maxNodes,
}) {
  const invalid = JsonTreeParse.failed(JsonTreeFailure.invalid);
  final nodes = <JsonTreeNode>[];
  final open = <int>[];
  var i = 0;
  final n = text.length;

  int skip(int from) {
    while (from < n) {
      final u = text.codeUnitAt(from);
      if (u == 0x20 || u == 0x09 || u == 0x0A || u == 0x0D) {
        from++;
      } else {
        break;
      }
    }
    return from;
  }

  /// The end of the string literal opening at [from], or -1.
  int stringEnd(int from) {
    var j = from + 1;
    while (j < n) {
      final u = text.codeUnitAt(j);
      if (u == 0x22) return j + 1;
      if (u < 0x20) return -1;
      j += u == 0x5C ? 2 : 1;
    }
    return -1;
  }

  String? decode(int from, int to) {
    try {
      return jsonDecode(text.substring(from, to)) as String;
    } on FormatException {
      return null;
    }
  }

  bool digit(int j) =>
      j < n && text.codeUnitAt(j) >= 0x30 && text.codeUnitAt(j) <= 0x39;

  /// The end of the number lexeme at [from], or -1.
  int numberEnd(int from) {
    var j = from;
    if (j < n && text.codeUnitAt(j) == 0x2D) j++;
    if (!digit(j)) return -1;
    if (text.codeUnitAt(j) == 0x30) {
      j++;
    } else {
      while (digit(j)) {
        j++;
      }
    }
    if (j < n && text.codeUnitAt(j) == 0x2E) {
      j++;
      if (!digit(j)) return -1;
      while (digit(j)) {
        j++;
      }
    }
    if (j < n && (text.codeUnitAt(j) | 0x20) == 0x65) {
      j++;
      if (j < n && (text.codeUnitAt(j) == 0x2B || text.codeUnitAt(j) == 0x2D)) {
        j++;
      }
      if (!digit(j)) return -1;
      while (digit(j)) {
        j++;
      }
    }
    return j;
  }

  // Reads one object key and its colon at [i]; null on a malformed one.
  String? key() {
    i = skip(i);
    if (i >= n || text.codeUnitAt(i) != 0x22) return null;
    final to = stringEnd(i);
    if (to < 0) return null;
    final k = decode(i, to);
    i = skip(to);
    if (k == null || i >= n || text.codeUnitAt(i) != 0x3A) return null;
    i++;
    return k;
  }

  var expectValue = true;
  String? pendingKey;
  var first = true;

  while (true) {
    if (expectValue) {
      i = skip(i);
      if (i >= n) return invalid;
      final u = text.codeUnitAt(i);
      if (first && u != 0x7B && u != 0x5B) return invalid;
      first = false;
      if (u == 0x7B || u == 0x5B) {
        if (open.length + 1 > maxDepth) {
          return const JsonTreeParse.failed(JsonTreeFailure.tooDeep);
        }
        if (nodes.length + 1 > maxNodes) {
          return const JsonTreeParse.failed(JsonTreeFailure.tooManyNodes);
        }
        final isObject = u == 0x7B;
        if (open.isNotEmpty) nodes[open.last].count++;
        nodes.add(
          JsonTreeNode(
            kind: isObject ? JsonTreeKind.object : JsonTreeKind.array,
            depth: open.length,
            key: pendingKey,
            text: '',
          ),
        );
        pendingKey = null;
        open.add(nodes.length - 1);
        i = skip(i + 1);
        final close = isObject ? 0x7D : 0x5D;
        if (i < n && text.codeUnitAt(i) == close) {
          // Empty: closed at once.
          nodes[open.removeLast()].end = nodes.length;
          i++;
          expectValue = false;
          continue;
        }
        if (isObject) {
          pendingKey = key();
          if (pendingKey == null) return invalid;
        }
        continue;
      }
      if (nodes.length + 1 > maxNodes) {
        return const JsonTreeParse.failed(JsonTreeFailure.tooManyNodes);
      }
      JsonTreeKind kind;
      String shown;
      if (u == 0x22) {
        final to = stringEnd(i);
        if (to < 0) return invalid;
        final decoded = decode(i, to);
        if (decoded == null) return invalid;
        kind = JsonTreeKind.string;
        shown = decoded;
        i = to;
      } else if (u == 0x2D || (u >= 0x30 && u <= 0x39)) {
        final to = numberEnd(i);
        if (to < 0) return invalid;
        kind = JsonTreeKind.number;
        shown = text.substring(i, to);
        i = to;
      } else {
        String? word;
        for (final w in const ['true', 'false', 'null']) {
          if (text.startsWith(w, i)) word = w;
        }
        if (word == null) return invalid;
        kind = JsonTreeKind.literal;
        shown = word;
        i += word.length;
      }
      nodes[open.last].count++;
      nodes.add(
        JsonTreeNode(
          kind: kind,
          depth: open.length,
          key: pendingKey,
          text: shown,
        ),
      );
      nodes.last.end = nodes.length;
      pendingKey = null;
      expectValue = false;
      continue;
    }

    // After a value: a comma, or the end of the container.
    i = skip(i);
    if (open.isEmpty) return i == n ? JsonTreeParse.ok(nodes) : invalid;
    if (i >= n) return invalid;
    final top = nodes[open.last];
    final u = text.codeUnitAt(i);
    if (u == 0x2C) {
      i++;
      if (top.kind == JsonTreeKind.object) {
        pendingKey = key();
        if (pendingKey == null) return invalid;
      }
      expectValue = true;
    } else if (u == (top.kind == JsonTreeKind.object ? 0x7D : 0x5D)) {
      nodes[open.removeLast()].end = nodes.length;
      i++;
    } else {
      return invalid;
    }
  }
}
