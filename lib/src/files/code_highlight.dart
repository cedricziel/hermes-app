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

/// Code up to this many characters is coloured while the frame builds; more
/// goes to a background isolate, so a large file never holds up a frame.
const int kCodeHighlightInlineChars = 20000;

/// Every grammar `val_highlight` ships, by name and alias (`python`, `py`,
/// `shell`, `sh`, `yml` ...). The server's `language` is a name from its own
/// fixed map; a name not here is shown plain. There is no fallback grammar.
final LanguageRegistry _registry = LanguageRegistry(allLanguages);

/// Whether [language] names a grammar the app has.
bool hasCodeGrammar(String? language) =>
    language != null && _registry.lookup(language) != null;

/// [text] as runs of one token class each, by the grammar of [language]; one
/// plain run when there is none, when [text] is above
/// [kCodeHighlightMaxChars] or when the grammar fails. The runs, joined,
/// are always [text].
List<CodeRun> highlightCode(String text, String? language) {
  final plain = <CodeRun>[(text, null)];
  final grammar = language == null ? null : _registry.lookup(language);
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

/// [highlightCode] for [compute]: one argument, a record the isolate can take.
List<CodeRun> highlightCodeIn((String, String?) request) =>
    highlightCode(request.$1, request.$2);

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
