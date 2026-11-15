/// Source-scan guards for rules that were only tested at their existing call
/// sites. Each [_guard] cites the rule it enforces, scans `lib/` (or `test/`)
/// and fails when a new call site breaks it. Known old violations sit in
/// `baseline.yaml` (shrink-only, see `ratchet.dart`); legitimate sites are in
/// the guard's `allow`, each with its reason.
///
/// Comments never count. A pattern runs over a comment-free view of the file
/// (`SourceFile.text` keeps string literals, `SourceFile.code` blanks them).
/// The `architecture-guards` skill says how to add a rule and prove it fails.
library;

import 'package:flutter_test/flutter_test.dart';

import 'ratchet.dart';
import 'source_scan.dart';

String _text(SourceFile f) => f.text;
String _code(SourceFile f) => f.code;

/// A guard that is one pattern over one view of the files under [root].
Rule _guard({
  required String name,
  required String message,
  required RegExp pattern,
  String root = 'lib',
  String Function(SourceFile) view = _text,
  Map<String, String> allow = const {},
  bool Function(SourceFile)? where,
}) {
  List<Hit>? hits;
  List<Hit> run() => hits ??= scanPattern(
    root,
    pattern,
    view: view,
    allow: allow.keys,
    where: where,
  );
  return Rule(
    id: 'arch.$name',
    message: message,
    scan: () => countByPath(run()),
    locate: (path) => hitLines(run(), path),
  );
}

/// A guard with its own scan.
Rule _custom({
  required String name,
  required String message,
  required List<Hit> Function() hits,
}) {
  List<Hit>? cached;
  List<Hit> run() => cached ??= hits();
  return Rule(
    id: 'arch.$name',
    message: message,
    scan: () => countByPath(run()),
    locate: (path) => hitLines(run(), path),
  );
}

/// Names that are an error in any scope.
const _errorNames = [
  'err',
  'error',
  'exception',
  'cause',
  'failure',
  'stackTrace',
  'stack',
];

/// Calls that reach telemetry or logs: app events, breadcrumbs, span
/// attributes, `debugPrint`.
final _telemetryCall = RegExp(
  r'\b(?:debugPrint|print|events|breadcrumbs|crumb|crumbs|setAttribute|'
  r'setAttributes|startSpan|addEvent)\s*\(',
);

final _catchClause = RegExp(r'\bcatch\s*\(([^)]*)\)\s*\{');

/// Matches the end of the brace block that opens at [open] in [code].
int _blockEnd(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if (code[i] == '{') depth++;
    if (code[i] == '}' && --depth == 0) return i;
  }
  return code.length;
}

/// The end offset of the call whose `(` just before [from] opened.
int _callEnd(String code, int from) {
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

/// Arguments (from the `text` view) of every call in [file] whose callee
/// matches [callee], as (callee offset, argument text).
List<(int, String)> callArguments(SourceFile file, RegExp callee) => [
  for (final call in callee.allMatches(file.code))
    (call.start, file.text.substring(call.end, _callEnd(file.code, call.end))),
];

/// Hits of the telemetry-error rule in one file: a telemetry call whose
/// arguments carry an error's message or stack. Names bound by an enclosing
/// `catch (e, st)` count in that block; `error`, `err`, `exception`, `cause`,
/// `failure`, `stackTrace` and `stack` count anywhere. A bare `e`, `ex` or
/// `st` outside a catch block (a loop variable, say) does not.
List<Hit> errorInterpolationHits(SourceFile file) {
  final catches = <(int, int, Set<String>)>[];
  for (final m in _catchClause.allMatches(file.code)) {
    final bound = {
      for (final name in m.group(1)!.split(','))
        if (RegExp(r'(\w+)\s*$').firstMatch(name.trim()) case final n?)
          n.group(1)!,
    };
    catches.add((m.end - 1, _blockEnd(file.code, m.end - 1), bound));
  }
  final hits = <Hit>[];
  for (final (offset, args) in callArguments(file, _telemetryCall)) {
    final names = {
      ..._errorNames,
      for (final (start, end, bound) in catches)
        if (offset > start && offset < end) ...bound,
    };
    final n = '(?:${names.join('|')})';
    final bad = RegExp(
      // `$e`, `$error` (the rest of the name is literal text)
      '\\\$$n\\b'
      // `${error}`, `${error.message}`, `${e.toString()}`, not `${e.runtimeType}`
      '|\\\$\\{\\s*$n\\b(?!\\.runtimeType)'
      // `error.toString()`, `error.message` passed as an argument
      '|\\b$n\\.(?:toString\\(\\)|message\\b)'
      // `'text' + error`, `error + 'text'`
      '|\\+\\s*$n\\b(?!\\.runtimeType)|\\b$n\\s*\\+\\s*[\'"]',
    );
    if (bad.hasMatch(args)) {
      final line = file.lineOf(offset);
      hits.add(Hit(file.path, line, file.lineText(line)));
    }
  }
  return hits;
}

List<Hit> _errorInterpolation() => [
  for (final file in dartFiles('lib')) ...errorInterpolationHits(file),
];

/// `--fix` anywhere, and `fix: true` or a `'fix'` key in a call that names
/// the doctor.
List<Hit> _doctorFix() {
  const allow = ['lib/src/server_care/widgets/server_check_body.dart'];
  final hits = <Hit>[];
  final flag = RegExp(r'--fix');
  final fixArg = RegExp(r"""\bfix\s*:\s*true\b|['"]fix['"]""");
  final doctorCall = RegExp(r'\b\w*[Dd]octor\w*\s*\(');
  for (final file in dartFiles('lib')) {
    if (isAllowed(file.path, allow)) continue;
    void add(int offset) {
      final line = file.lineOf(offset);
      hits.add(Hit(file.path, line, file.lineText(line)));
    }

    for (final m in flag.allMatches(file.text)) {
      add(m.start);
    }
    for (final (offset, args) in callArguments(file, doctorCall)) {
      if (fixArg.hasMatch(args)) add(offset);
    }
  }
  return hits;
}

final _fileRead = RegExp(
  r'\b(?:File|Directory)\(|\.readAs(?:String|Lines|Bytes)(?:Sync)?\(|rootBundle',
);
final _docsPath = RegExp(
  r"""['"](?:\.{1,2}/)*(?:docs|openspec)(?:/[^'"]*)?['"]"""
  r"""|['"][^'"]*/(?:openspec|docs/(?:architecture|roadmap|design-briefs))[^'"]*['"]""",
);

List<Hit> _testsReadingDocs() {
  final hits = <Hit>[];
  for (final file in dartFiles('test')) {
    if (file.path.startsWith('test/architecture/')) continue;
    if (!_fileRead.hasMatch(file.code)) continue;
    for (final m in _docsPath.allMatches(file.text)) {
      if (m.group(0)!.contains('http')) continue;
      final line = file.lineOf(m.start);
      hits.add(Hit(file.path, line, file.lineText(line)));
    }
  }
  return hits;
}

/// Every guard of this file.
final guardRules = <Rule>[
  // CLAUDE.md "Architecture" > Deep links; docs/architecture/deep-links.md.
  _guard(
    name: 'deep-link-literal',
    message:
        'build the link with deepLinkUri and read it with parseDeepLink '
        '(lib/src/deep_links/), never a hand-written hermes: URL.',
    pattern: RegExp(
      r"""hermes://|['"]hermes:(?:['"]|[A-Za-z])|scheme\s*(?:==|:)\s*['"]hermes['"]""",
    ),
    allow: {
      'lib/src/deep_links/': 'owns the scheme: deepLinkUri, parseDeepLink',
    },
  ),

  // docs/architecture/headless-runtime.md: work without a screen goes
  // through withHeadlessHermes, never its own AuthController.
  _guard(
    name: 'auth-controller-construction',
    message:
        'headless work goes through withHeadlessHermes '
        '(lib/src/background/headless_hermes.dart); the one AuthController '
        'is created by the provider tree.',
    pattern: RegExp(r'\bAuthController\('),
    view: _code,
    allow: {
      'lib/src/auth/': 'the controller itself',
      'lib/src/app/providers/': 'auth_providers.dart creates the one instance',
    },
  ),

  // docs/architecture/settings-screens.md: a saved key is never revealed.
  _guard(
    name: 'env-reveal',
    message:
        'a saved key is never revealed: show that it is set, and let the '
        'user type a new value to replace it.',
    pattern: RegExp(r'env/reveal'),
  ),

  // CLAUDE.md "Server files": Files uses /api/fs, never /api/files.
  _guard(
    name: 'managed-files-route',
    message:
        'the Files page reads /api/fs through HermesFilesRepository '
        '(lib/src/files/); /api/files is only for MEDIA attachments via '
        'HermesApiClient.fetchManagedFile.',
    pattern: RegExp(r'/api/files|\w*Managed\w*ApiFiles\w*'),
    allow: {
      'lib/src/api/hermes_api_client.dart':
          'fetchManagedFile, the MEDIA: attachment download',
    },
  ),

  // CLAUDE.md "Server care": doctor never runs with --fix.
  _custom(
    name: 'doctor-fix',
    message:
        'doctor never runs with --fix: call '
        'ServerCareRepository.startDoctor (profile only) and show the footer '
        'tip; strip --fix from copied commands as server_check_body.dart does.',
    hits: _doctorFix,
  ),

  // CLAUDE.md "Two API layers": reach the client through
  // authController.api!.raw, which shares the managed Dio.
  _guard(
    name: 'raw-dio',
    message:
        'do not construct a Dio: use authController.api!.raw (the managed '
        'Dio with auth, retry and telemetry).',
    pattern: RegExp(r'\bDio\('),
    view: _code,
    allow: {
      'lib/src/api/': 'the generated-client wrapper',
      'lib/src/auth/': 'AuthController and the login flow own the Dio',
      'lib/src/background/headless_hermes.dart': 'withHeadlessHermes',
      'lib/src/windows/window_api_client.dart':
          'a conversation window has its own isolate and client',
    },
  ),

  // CLAUDE.md "Server care": copied commands are never run.
  _guard(
    name: 'process-run-server-care',
    root: 'lib/src/server_care',
    message:
        'copied commands are never run: offer a copy button '
        '(Clipboard.setData), do not start a process.',
    pattern: RegExp(r'\bProcess\.(?:run|runSync|start)\('),
    view: _code,
  ),

  // CLAUDE.md "Commands" (CI skips tests on docs-only PRs).
  _custom(
    name: 'tests-read-docs',
    message:
        'CI skips the test shards on docs-only changes: take docs/ or '
        'openspec/ out of the docs-only filter in .github/workflows/ci.yml '
        'first, or do not read those paths from a test.',
    hits: _testsReadingDocs,
  ),

  // CLAUDE.md "Testing conventions": a widget under widgets/ is a
  // plain-model widget, so it can have a Widgetbook use case.
  _guard(
    name: 'widget-layer-imports',
    message:
        'a widgets/ file takes models and callbacks only: move the '
        'repository, controller or hermes_api use to the screen that builds '
        'the widget, or move the model type out of that file '
        '(component-catalog skill).',
    pattern: RegExp(
      '''^\\s*(?:import|export)\\s+['"][^'"]*'''
      r'''(?:_repository\.dart|_controller\.dart|package:hermes_api/)[^'"]*['"]''',
      multiLine: true,
    ),
    where: (f) => f.path.startsWith('lib/src/') && f.path.contains('/widgets/'),
  ),

  // component-catalog skill: icon buttons are NamedIconButton.
  _guard(
    name: 'raw-icon-button',
    message:
        'use NamedIconButton (lib/src/widgets/named_icon_button.dart): it '
        'carries the tooltip, semantic label and tap target.',
    pattern: RegExp(r'\bIconButton(?:\.(?:filled|filledTonal|outlined))?\('),
    view: _code,
    allow: {'lib/src/widgets/named_icon_button.dart': 'the implementation'},
  ),

  // docs/architecture/telemetry.md: events, breadcrumbs, span attributes and
  // debugPrint carry error.runtimeType, never the message.
  _custom(
    name: 'error-interpolation-in-telemetry',
    message:
        'log only the type: \'\${error.runtimeType}\'. The crash reporter '
        '(reportBug) is the one place that keeps the full message.',
    hits: _errorInterpolation,
  ),
];

void main() {
  ratchetTests(guardRules, namespace: 'arch');

  group('error-interpolation scan', () {
    int count(String body) =>
        errorInterpolationHits(SourceFile('lib/x.dart', body)).length;

    test('flags the message and stack of a caught error', () {
      expect(count("f() { try {} catch (e) { debugPrint('x \$e'); } }"), 1);
      expect(
        count("f() { try {} on X catch (ex, st) { debugPrint('\$st'); } }"),
        1,
      );
      expect(
        count("f() { try {} catch (p, q) { debugPrint('\${p.message}'); } }"),
        1,
      );
      expect(count("f(Object error) { debugPrint('a' + error.message); }"), 1);
      expect(count("f(Object err) { events('x', {'m': err.toString()}); }"), 1);
      expect(count("f(Object stackTrace) { debugPrint('\$stackTrace'); }"), 1);
      expect(count("f(Object failure) { debugPrint('\${failure}'); }"), 1);
    });

    test('lets the type through, and a loop variable named e', () {
      expect(
        count("f(Object error) { debugPrint('\${error.runtimeType}'); }"),
        0,
      );
      expect(count("f(xs) { for (final e in xs) { debugPrint('\$e'); } }"), 0);
      expect(count("f(xs) { xs.map((e) => events('n', {'v': '\$e'})); }"), 0);
      expect(count("f() { debugPrint('a // \$e comment-like'); }"), 0);
    });
  });
}
