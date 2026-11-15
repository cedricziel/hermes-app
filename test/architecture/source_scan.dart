/// Reads Dart sources once and offers two comment-free views of each file.
///
/// - [SourceFile.text]: comments blanked, string literals kept. For rules that
///   look for a literal (`hermes://`, `/api/files`).
/// - [SourceFile.code]: comments blanked and the contents of string literals
///   blanked too (interpolated code is kept). For rules that look for a call
///   (`IconButton(`, `Dio(`), so text in a string never counts.
///
/// Both views have the length and line breaks of the original, so an offset
/// gives the same line in all three.
library;

import 'dart:io';

/// One scanned file.
class SourceFile {
  SourceFile(this.path, this.raw);

  /// Repo-relative, with `/` separators.
  final String path;
  final String raw;

  late final _Views _views = _Views.of(raw);
  String get text => _views.text;
  String get code => _views.code;

  List<int>? _lineStarts;

  /// 1-based line of [offset].
  int lineOf(int offset) {
    final starts = _lineStarts ??= [
      0,
      for (var i = 0; i < raw.length; i++)
        if (raw.codeUnitAt(i) == 10) i + 1,
    ];
    var lo = 0;
    var hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }

  /// The original text of the 1-based [line], trimmed.
  String lineText(int line) {
    final lines = raw.split('\n');
    return lines[line - 1].trim();
  }
}

/// The end of the call whose `(` just before [from] opened, in [code].
int callEnd(String code, int from) {
  var depth = 1;
  var end = from;
  while (end < code.length && depth > 0) {
    final c = code[end];
    if (c == '(') depth++;
    if (c == ')') depth--;
    end++;
  }
  return end;
}

/// The offset of the `}` that closes the block opened at [open] in [code].
int blockEnd(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if (code[i] == '{') depth++;
    if (code[i] == '}' && --depth == 0) return i;
  }
  return code.length;
}

/// Arguments (from the `text` view, balanced by parenthesis depth in the
/// `code` view) of every call in [file] whose callee matches [callee], as
/// (callee offset, argument text).
List<(int, String)> callArguments(SourceFile file, RegExp callee) => [
  for (final call in callee.allMatches(file.code))
    (call.start, file.text.substring(call.end, callEnd(file.code, call.end))),
];

/// One match of a rule.
class Hit {
  const Hit(this.path, this.line, this.snippet);
  final String path;
  final int line;
  final String snippet;

  @override
  String toString() => '$path:$line: $snippet';
}

final _cache = <String, List<SourceFile>>{};

/// Every `.dart` file under [root] (repo-relative), sorted by path. Generated
/// localizations are skipped. Read once per run.
List<SourceFile> dartFiles(String root) => _cache.putIfAbsent(root, () {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  final files = <SourceFile>[];
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.startsWith('lib/l10n/generated/')) continue;
    files.add(SourceFile(path, entity.readAsStringSync()));
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
});

/// True when [path] is one of [allow]: an exact file, or a directory prefix
/// that ends in `/`.
bool isAllowed(String path, Iterable<String> allow) => allow.any(
  (entry) => entry.endsWith('/') ? path.startsWith(entry) : path == entry,
);

/// Hits of [pattern] in [view] of every file under [root] not in [allow].
List<Hit> scanPattern(
  String root,
  RegExp pattern, {
  required String Function(SourceFile) view,
  Iterable<String> allow = const [],
  bool Function(SourceFile)? where,
}) {
  final hits = <Hit>[];
  for (final file in dartFiles(root)) {
    if (isAllowed(file.path, allow)) continue;
    if (where != null && !where(file)) continue;
    final body = view(file);
    for (final m in pattern.allMatches(body)) {
      final line = file.lineOf(m.start);
      hits.add(Hit(file.path, line, file.lineText(line)));
    }
  }
  return hits;
}

/// Hit counts per path.
Map<String, int> countByPath(Iterable<Hit> hits) {
  final out = <String, int>{};
  for (final hit in hits) {
    out[hit.path] = (out[hit.path] ?? 0) + 1;
  }
  return out;
}

/// The hits of one path as `path:line: snippet` strings.
List<String> hitLines(Iterable<Hit> hits, String path) => [
  for (final hit in hits)
    if (hit.path == path) '$hit',
];

class _Views {
  _Views(this.text, this.code);
  final String text;
  final String code;

  static _Views of(String s) {
    final text = StringBuffer();
    final code = StringBuffer();
    // Frames: null is plain code; a _Str is a string literal; an int is the
    // brace depth inside an interpolation `${...}`.
    final stack = <Object?>[null];

    void both(String c) {
      text.write(c);
      code.write(c);
    }

    String blank(String c) => c == '\n' ? '\n' : ' ';

    bool isIdent(int cu) =>
        (cu >= 48 && cu <= 57) ||
        (cu >= 65 && cu <= 90) ||
        (cu >= 97 && cu <= 122) ||
        cu == 95 ||
        cu == 36;

    var i = 0;
    while (i < s.length) {
      final c = s[i];
      final top = stack.last;
      if (top is _Str) {
        if (!top.raw && c == r'\') {
          final next = i + 1 < s.length ? s[i + 1] : '';
          text
            ..write(c)
            ..write(next);
          code
            ..write(' ')
            ..write(blank(next));
          i += 2;
          continue;
        }
        if (top.triple ? s.startsWith(top.quote * 3, i) : c == top.quote) {
          final q = top.triple ? top.quote * 3 : top.quote;
          both(q);
          i += q.length;
          stack.removeLast();
          continue;
        }
        if (!top.raw && c == r'$') {
          if (i + 1 < s.length && s[i + 1] == '{') {
            text.write(r'${');
            code.write('  ');
            stack.add(0);
            i += 2;
            continue;
          }
          var j = i + 1;
          while (j < s.length && isIdent(s.codeUnitAt(j))) {
            j++;
          }
          text.write(s.substring(i, j));
          code.write(' ' * (j - i));
          i = j;
          continue;
        }
        text.write(c);
        code.write(blank(c));
        i++;
        continue;
      }
      // Code (top level, or inside an interpolation).
      if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
        while (i < s.length && s[i] != '\n') {
          text.write(' ');
          code.write(' ');
          i++;
        }
        continue;
      }
      if (c == '/' && i + 1 < s.length && s[i + 1] == '*') {
        var depth = 0;
        while (i < s.length) {
          if (s.startsWith('/*', i)) {
            depth++;
            text.write('  ');
            code.write('  ');
            i += 2;
          } else if (s.startsWith('*/', i)) {
            depth--;
            text.write('  ');
            code.write('  ');
            i += 2;
            if (depth == 0) break;
          } else {
            text.write(blank(s[i]));
            code.write(blank(s[i]));
            i++;
          }
        }
        continue;
      }
      if (c == "'" || c == '"') {
        final raw =
            i > 0 &&
            s[i - 1] == 'r' &&
            (i < 2 || !isIdent(s.codeUnitAt(i - 2)));
        final triple = s.startsWith(c * 3, i);
        stack.add(_Str(c, triple, raw));
        final q = triple ? c * 3 : c;
        both(q);
        i += q.length;
        continue;
      }
      if (top is int) {
        if (c == '{') {
          stack[stack.length - 1] = top + 1;
        } else if (c == '}') {
          if (top == 0) {
            stack.removeLast();
            text.write('}');
            code.write(' ');
            i++;
            continue;
          }
          stack[stack.length - 1] = top - 1;
        }
      }
      both(c);
      i++;
    }
    return _Views(text.toString(), code.toString());
  }
}

class _Str {
  const _Str(this.quote, this.triple, this.raw);
  final String quote;
  final bool triple;
  final bool raw;
}
