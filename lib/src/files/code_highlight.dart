import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/val_highlight.dart';

/// The classes of token the code palette tells apart. A token the grammar
/// names but the palette does not (an operator, a bracket) stays plain.
enum CodeToken { keyword, string, comment, number, function, type }

/// A stretch of code and its token class; `null` is plain text. Plain data, so
/// a list of them crosses an isolate boundary.
typedef CodeRun = (String text, CodeToken? token);

/// Code longer than this many characters is shown plain: the server sends at
/// most 512 KB of a file, and anything above that would only be a file the
/// client was not meant to colour.
const int kCodeHighlightMaxChars = 512 * 1024;

/// `val_highlight` 0.1.1 is not linear on every input: a few thousand
/// characters of one whitespace run take hundreds of milliseconds in about
/// twenty grammars, and 20,000 take seconds. A file is untrusted, so the
/// highlighter runs on the UI isolate only for a text this small and plain
/// shaped ([isInlineSafe]); anything else goes to a [CodeHighlightWorker] that
/// can be killed, or stays plain.
const int kCodeHighlightInlineChars = 2000;

/// The longest line, in characters, that is coloured on the UI isolate.
const int kCodeHighlightInlineLine = 300;

/// The longest run of spaces and tabs that is coloured on the UI isolate.
const int kCodeHighlightInlineSpaceRun = 200;

/// How long a [CodeHighlightWorker] may take before the text stays plain.
const Duration kCodeHighlightTimeout = Duration(seconds: 2);

/// Whether [text] is small and plain shaped enough to colour on the UI
/// isolate: at most [kCodeHighlightInlineChars] characters, no line over
/// [kCodeHighlightInlineLine] and no run of blanks over
/// [kCodeHighlightInlineSpaceRun].
bool isInlineSafe(String text) {
  if (text.length > kCodeHighlightInlineChars) return false;
  var line = 0;
  var blanks = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    line = unit == 0x0A ? 0 : line + 1;
    blanks = unit == 0x20 || unit == 0x09 ? blanks + 1 : 0;
    if (line > kCodeHighlightInlineLine ||
        blanks > kCodeHighlightInlineSpaceRun) {
      return false;
    }
  }
  return true;
}

/// What the colouring of all the fenced blocks of one Markdown document may
/// cost: they share it, so twenty-six fences cannot add up to twenty-six
/// times the work. A block over the budget stays plain; none goes to a worker.
class CodeHighlightBudget {
  CodeHighlightBudget({this.chars = 4000, this.blocks = 8});

  int chars;
  int blocks;

  /// Takes [text]'s share of the budget; false when it is spent or [text] is
  /// not [isInlineSafe].
  bool take(String text) {
    if (blocks <= 0 || text.length > chars || !isInlineSafe(text)) {
      return false;
    }
    blocks--;
    chars -= text.length;
    return true;
  }
}

/// Every grammar `val_highlight` ships, by name and alias (`python`, `py`,
/// `shell`, `sh`, `yml` ...). The server's `language` is a name from its own
/// fixed map; a name not here is shown plain. There is no fallback grammar.
final LanguageRegistry _registry = LanguageRegistry(allLanguages);

/// Whether [language] names a grammar the app has.
bool hasCodeGrammar(String? language) => _grammarOf(language) != null;

/// The grammar of [language]; null for no name, an unknown one and plain text
/// (`text`, `plaintext`), which need no highlighter at all.
Grammar? _grammarOf(String? language) {
  final grammar = language == null ? null : _registry.lookup(language);
  return grammar == null || grammar.name == 'plaintext' ? null : grammar;
}

/// [text] as runs of one token class each, by the grammar of [language]; one
/// plain run when there is none, when [text] is above
/// [kCodeHighlightMaxChars] or when the grammar fails. The runs, joined,
/// are always [text].
List<CodeRun> highlightCode(String text, String? language) {
  final plain = <CodeRun>[(text, null)];
  final grammar = _grammarOf(language);
  if (grammar == null || text.isEmpty || text.length > kCodeHighlightMaxChars) {
    return plain;
  }
  try {
    final result = const Highlighter().highlight(text, language: grammar);
    final table = result.scopes;
    final runs = <CodeRun>[];
    final cache = <int, CodeToken?>{};
    for (var i = 0; i < result.tokenCount; i++) {
      final slice = text.substring(result.tokenStart(i), result.tokenEnd(i));
      if (slice.isEmpty) continue;
      final token = cache.putIfAbsent(result.tokenStack(i), () {
        // The innermost scope the palette knows: a `punctuation` inside a
        // `string` is part of the string.
        var stack = result.tokenStack(i);
        while (stack != ScopeTable.root) {
          final scope = table.scopeOf(stack);
          final mapped = scope == null ? null : tokenOfScope(scope);
          if (mapped != null) return mapped;
          stack = table.parentOf(stack);
        }
        return null;
      });
      if (runs.isNotEmpty && runs.last.$2 == token) {
        runs[runs.length - 1] = (runs.last.$1 + slice, token);
      } else {
        runs.add((slice, token));
      }
    }
    // A grammar that drops or repeats text is worse than none.
    return runs.map((run) => run.$1).join() == text ? runs : plain;
  } on Object {
    return plain;
  }
}

/// Colours one text in a separate isolate that [kill] ends, so a pathological
/// file costs at most [kCodeHighlightTimeout] of one core and nothing after
/// the preview that asked has gone. One worker colours one text; it owns its
/// isolate and nothing else.
class CodeHighlightWorker {
  /// Workers whose isolate has not exited yet; for tests.
  @visibleForTesting
  static int alive = 0;

  Isolate? _isolate;
  ReceivePort? _results;
  Timer? _timer;
  final Completer<List<CodeRun>?> _done = Completer();
  var _killed = false;

  /// The runs for [text], or null when the isolate failed, the time ran out
  /// or [kill] came first: the caller shows the text plain.
  Future<List<CodeRun>?> highlight(
    String text,
    String? language, {
    Duration timeout = kCodeHighlightTimeout,
  }) async {
    if (_killed) return null;
    final results = _results = ReceivePort();
    final exit = ReceivePort();
    results.listen((message) {
      // A result is a list of runs; an error is a list of two strings.
      if (message is List && message.isNotEmpty && message.first is CodeRun) {
        _finish(List<CodeRun>.from(message));
      } else if (message is List && message.isEmpty) {
        _finish(<CodeRun>[]);
      } else {
        _finish(null);
      }
    });
    exit.listen((_) {
      alive--;
      exit.close();
      _finish(null);
    });
    _timer = Timer(timeout, kill);
    try {
      alive++;
      _isolate = await Isolate.spawn(
        _work,
        (results.sendPort, text, language),
        onExit: exit.sendPort,
        onError: results.sendPort,
        errorsAreFatal: true,
      );
      if (_killed) _isolate?.kill(priority: Isolate.immediate);
    } on Object {
      alive--;
      exit.close();
      _finish(null);
    }
    return _done.future;
  }

  static void _work((SendPort, String, String?) request) {
    request.$1.send(highlightCode(request.$2, request.$3));
  }

  void _finish(List<CodeRun>? runs) {
    _timer?.cancel();
    _results?.close();
    if (!_done.isCompleted) _done.complete(runs);
  }

  /// Ends the isolate now; a pending [highlight] answers null.
  void kill() {
    _killed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _finish(null);
  }
}

/// The class of a grammar scope (`keyword`, `type.builtin`, `string`), by its
/// first part; null for a scope the palette leaves plain.
@visibleForTesting
CodeToken? tokenOfScope(String scope) {
  final dot = scope.indexOf('.');
  return switch (dot < 0 ? scope : scope.substring(0, dot)) {
    Scopes.keyword ||
    Scopes.literal ||
    Scopes.meta ||
    Scopes.tag => CodeToken.keyword,
    Scopes.string || Scopes.regexp || Scopes.addition => CodeToken.string,
    Scopes.comment || Scopes.quote || Scopes.deletion => CodeToken.comment,
    Scopes.number => CodeToken.number,
    Scopes.function || Scopes.heading => CodeToken.function,
    Scopes.type || Scopes.property || Scopes.attribute => CodeToken.type,
    _ => null,
  };
}
