/// Source-scan guards for rules that were only tested at their existing call
/// sites. Each [_guard] cites the rule it enforces, scans `lib/` (or `test/`)
/// and fails when a new call site breaks it. Known old violations sit in
/// `baseline/arch.yaml` (shrink-only, see `ratchet.dart`); legitimate sites are in
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
];

/// Calls that reach telemetry or logs: app events, breadcrumbs, span
/// attributes, `debugPrint`.
final _telemetryCall = RegExp(
  r'\b(?:debugPrint|print|events|breadcrumbs|crumb|crumbs|setAttribute|'
  r'setAttributes|startSpan|addEvent)\s*\(',
);

final _catchClause = RegExp(r'\bcatch\s*\(([^)]*)\)\s*\{');

/// The names a parameter list binds: `(e, st)`, `(Object e, StackTrace st)`.
Set<String> _paramNames(String params) => {
  for (final part in params.split(','))
    if (RegExp(r'(\w+)\s*$').firstMatch(part.trim()) case final m?) m.group(1)!,
};

/// The end of the closure or function body that starts at [from] (just after
/// its parameter list): `{ ... }`, or `=> expr` up to the `,` or `)` that ends
/// it.
int _bodyEnd(String code, int from) {
  var i = from;
  while (i < code.length && ' \n\t'.contains(code[i])) {
    i++;
  }
  if (code.startsWith('async', i)) i += 5;
  while (i < code.length && ' \n\t'.contains(code[i])) {
    i++;
  }
  if (i < code.length && code[i] == '{') return blockEnd(code, i);
  if (!code.startsWith('=>', i)) return from;
  var depth = 0;
  for (i += 2; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      if (depth == 0) return i;
      depth--;
    }
    if ((c == ',' || c == ';') && depth == 0) return i;
  }
  return code.length;
}

/// Parameters typed [types] (a regex alternation), each visible in its own
/// function or closure body: (start, end, {name}).
List<(int, int, Set<String>)> _typedParamRanges(String code, String types) {
  final out = <(int, int, Set<String>)>[];
  for (final m in RegExp('\\b(?:$types)\\??\\s+(\\w+)').allMatches(code)) {
    var depth = 0;
    var i = m.end;
    for (; i < code.length; i++) {
      if (code[i] == '(') depth++;
      if (code[i] == ')' && depth-- == 0) break;
    }
    out.add((m.start, _bodyEnd(code, i + 1), {m.group(1)!}));
  }
  return out;
}

/// Where an error name is bound as a parameter or catch variable:
/// (start, end, names) of the code the names are visible in.
List<(int, int, Set<String>)> _errorBindings(String code) {
  final out = <(int, int, Set<String>)>[];
  // catch (e, st) { ... }
  for (final m in _catchClause.allMatches(code)) {
    out.add((m.end - 1, blockEnd(code, m.end - 1), _paramNames(m.group(1)!)));
  }
  // fut.catchError((e) => ...), stream.handleError((e, st) {...}),
  // listen(.., onError: (e, st) {...}), X.onError = (e, st) {...}
  final handler = RegExp(
    r'\b(?:catchError|handleError)\s*\(\s*\(([^)]*)\)'
    r'|\bonError\s*:\s*\(([^)]*)\)'
    r'|\b(?:FlutterError|[\w.]*[Pp]latformDispatcher(?:\.instance)?)'
    r'\.onError\s*=\s*\(([^)]*)\)',
  );
  for (final m in handler.allMatches(code)) {
    final params = m.group(1) ?? m.group(2) ?? m.group(3)!;
    out.add((m.end, _bodyEnd(code, m.end), _paramNames(params)));
  }
  // runZonedGuarded(body, (e, st) {...}): every closure with parameters in
  // the call is the error handler (the body takes none).
  final closure = RegExp(r'\(([^()]+)\)\s*(?:async\s*)?(?:\{|=>)');
  for (final z in RegExp(r'\brunZonedGuarded\s*\(').allMatches(code)) {
    final end = callEnd(code, z.end);
    for (final m in closure.allMatches(code.substring(z.end, end))) {
      final from = z.end + m.end - (m.group(0)!.endsWith('{') ? 1 : 2);
      final bodyFrom = z.end + m.start + m.group(1)!.length + 2;
      out.add((from, _bodyEnd(code, bodyFrom), _paramNames(m.group(1)!)));
    }
  }
  // Any parameter typed StackTrace or FlutterErrorDetails, in its function.
  out.addAll(_typedParamRanges(code, 'StackTrace|FlutterErrorDetails'));
  return out;
}

/// Hits of the telemetry-error rule in one file: a telemetry call whose
/// arguments carry an error's message or stack. `error`, `err`, `exception`,
/// `cause`, `failure` and `stackTrace` count anywhere. Any other name counts
/// only where it is bound as an error: by `catch (e, st)`, by the closure
/// given to `catchError(`, `handleError(` or `onError:`, or as a parameter
/// typed `StackTrace` or `FlutterErrorDetails`, or the handler of
/// `runZonedGuarded(` or a `FlutterError.onError` / `PlatformDispatcher.instance
/// .onError` assignment. `details.exception` and `details.stack` count for a
/// `FlutterErrorDetails`-typed parameter or inside a `FlutterError.onError`
/// handler. So a loop variable `e`, or `${stack.length}` on an
/// unrelated `stack`, is not a hit.
List<Hit> errorInterpolationHits(SourceFile file) {
  final bindings = _errorBindings(file.code);
  // `details.exception` / `details.stack` of a FlutterErrorDetails: a
  // parameter typed so, or the parameter of a FlutterError.onError handler.
  final typedDetails = _typedParamRanges(file.code, 'FlutterErrorDetails');
  final flutterHandlers = <(int, int, Set<String>)>[
    for (final m in RegExp(
      r'\bFlutterError\.onError\s*=\s*\(([^)]*)\)',
    ).allMatches(file.code))
      (m.end, _bodyEnd(file.code, m.end), _paramNames(m.group(1)!)),
  ];
  final hits = <Hit>[];
  for (final (offset, args) in callArguments(file, _telemetryCall)) {
    final names = {
      ..._errorNames,
      for (final (start, end, bound) in bindings)
        if (offset > start && offset < end) ...bound,
    };
    final n = '(?:${names.join('|')})';
    final detailNames = {
      for (final (start, end, bound) in [...typedDetails, ...flutterHandlers])
        if (offset > start && offset < end) ...bound,
    };
    final details = detailNames.isEmpty
        ? '(?!)'
        : '\\b(?:${detailNames.join('|')})\\.(?:exception|stack|exceptionAsString\\(\\))';
    final bad = RegExp(
      // `$e`, `$error` (the rest of the name is literal text)
      '\\\$$n\\b'
      // `${error}`, `${error.message}`, `${e.toString()}`, not `${e.runtimeType}`
      '|\\\$\\{\\s*$n\\b(?!\\.runtimeType)'
      // `error.toString()`, `error.message` passed as an argument
      '|\\b$n\\.(?:toString\\(\\)|message\\b)'
      // `'text' + error`, `error + 'text'`
      '|\\+\\s*$n\\b(?!\\.runtimeType)|\\b$n\\s*\\+\\s*[\'"]'
      '|$details',
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

/// `--fix` anywhere, and `fix: true` or a `'fix'` key in a call that names the
/// doctor or whose arguments contain `/api/ops/doctor`.
List<Hit> _doctorFix() {
  const allow = ['lib/src/server_care/widgets/server_check_body.dart'];
  final hits = <Hit>[];
  final flag = RegExp(r'--fix');
  final fixArg = RegExp(r"""\bfix\s*:\s*true\b|['"]fix['"]|[?&]fix=""");
  final doctorCall = RegExp(r'\b\w*[Dd]octor\w*\s*\(');
  final anyCall = RegExp(r'\b[\w.]+\s*\(');
  for (final file in dartFiles('lib')) {
    if (isAllowed(file.path, allow)) continue;
    final lines = <int>{};
    for (final m in flag.allMatches(file.text)) {
      lines.add(file.lineOf(m.start));
    }
    final calls = [
      ...callArguments(file, doctorCall),
      if (file.text.contains('/api/ops/doctor'))
        for (final call in callArguments(file, anyCall))
          if (call.$2.contains('/api/ops/doctor')) call,
    ];
    for (final (offset, args) in calls) {
      if (fixArg.hasMatch(args)) lines.add(file.lineOf(offset));
    }
    for (final line in lines.toList()..sort()) {
      hits.add(Hit(file.path, line, file.lineText(line)));
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

    test('binds closure parameters of catchError, handleError, onError', () {
      expect(count(r"f(fut) { fut.catchError((e) => debugPrint('$e')); }"), 1);
      expect(
        count(
          r"f(s) { s.listen(null, onError: (e, st) { debugPrint('$e'); }); }",
        ),
        1,
      );
      expect(
        count(r"f(s) { s.handleError((x) { events('a', {'m': '$x'}); }); }"),
        1,
      );
      expect(
        count(r"f(Object o, StackTrace trace) { debugPrint('$trace'); }"),
        1,
      );
    });

    test('binds runZonedGuarded handlers and onError assignments', () {
      expect(
        count(
          r"f() { runZonedGuarded(() { run(); }, (e, st) { debugPrint('$e'); }); }",
        ),
        1,
      );
      expect(
        count(
          r"f() { PlatformDispatcher.instance.onError = (e, st) { debugPrint('$st'); return true; }; }",
        ),
        1,
      );
      expect(
        count(
          r"f() { runZonedGuarded(() { var e = 1; debugPrint('$e'); }, (x, y) {}); }",
        ),
        0,
      );
    });

    test('flags details.exception and details.stack', () {
      expect(
        count(
          r"f() { FlutterError.onError = (details) { debugPrint('${details.exception}'); }; }",
        ),
        1,
      );
      expect(
        count(r"f(Object details) { debugPrint('${details.exception}'); }"),
        0,
      );
      expect(count(r"f(FlutterErrorDetails d) { debugPrint('$d'); }"), 1);
      expect(
        count(r"f(Object details) { debugPrint('${details.runtimeType}'); }"),
        0,
      );
    });

    test('binds the platform dispatcher through any receiver', () {
      expect(
        count(
          r"f() { WidgetsBinding.instance.platformDispatcher.onError = (e, st) { debugPrint('$e'); return true; }; }",
        ),
        1,
      );
      expect(
        count(
          r"f(b) { b.platformDispatcher.onError = (e, st) { debugPrint('$st'); return true; }; }",
        ),
        1,
      );
      expect(
        count(r"f(b) { b.other.onError = (e, st) { debugPrint('$e'); }; }"),
        0,
      );
    });

    test('a FlutterErrorDetails parameter is scoped to its own function', () {
      expect(
        count(r"f(FlutterErrorDetails d) { debugPrint('${d.exception}'); }"),
        1,
      );
      expect(
        count(
          r"f(FlutterErrorDetails d) { } g(Object d) { debugPrint('${d.exception}'); }",
        ),
        0,
      );
    });

    test('stack counts only where it is bound as an error', () {
      expect(count(r"f(List stack) { debugPrint('n=${stack.length}'); }"), 0);
      expect(
        count(r"f() { try {} catch (e, stack) { debugPrint('$stack'); } }"),
        1,
      );
      expect(
        count(r"f(Object o, StackTrace stack) { debugPrint('$stack'); }"),
        1,
      );
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
