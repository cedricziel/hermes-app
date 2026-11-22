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
  Map<String, ExactAllow> exact = const {},
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
  if (exact.isNotEmpty) {
    _exactChecks['arch.$name'] = (
      allowed: {for (final e in exact.entries) e.key: e.value.count},
      counts: () => countByPath(run()),
    );
  }
  return Rule(
    id: 'arch.$name',
    message: message,
    scan: () {
      final counts = countByPath(run());
      // A file within its exact allowance is clean; above it, every hit of
      // the file is reported.
      return {
        for (final e in counts.entries)
          if (e.value > (exact[e.key]?.count ?? 0)) e.key: e.value,
      };
    },
    locate: (path) => hitLines(run(), path),
  );
}

/// How many hits of a guard one file may keep, and why. Exact: a file above
/// it fails, and so does a file below it, so the list shrinks with the code.
class ExactAllow {
  const ExactAllow(this.count, this.reason);
  final int count;
  final String reason;
}

/// The exact allowances of the guards that have them, by rule id.
final _exactChecks =
    <
      String,
      ({Map<String, int> allowed, Map<String, int> Function() counts})
    >{};

/// The files that have fewer hits than their exact allowance: the list must
/// shrink with them.
List<String> exactShortfalls(
  String id,
  Map<String, int> actual,
  Map<String, int> allowed,
) => [
  for (final e in allowed.entries)
    if ((actual[e.key] ?? 0) < e.value)
      '$id: ${e.key} has ${actual[e.key] ?? 0}, its allowance is '
          '${e.value}. Shrink the allowlist to ${actual[e.key] ?? 0}'
          '${(actual[e.key] ?? 0) == 0 ? ' (remove the entry)' : ''}.',
];

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

/// A Material list tile built outside a `FocusRing(`: the tile's shape is not
/// state-aware, so the ring is a wrapper. `\b` keeps `MacSourceListTile` out.
final _bareListTile = RegExp(
  r'(?<!FocusRing\(\s*(?:child:\s*)?)\b(?:Checkbox|Switch|Radio)?ListTile'
  r'(?:<[^()]*>)?(?:\.adaptive)?\(',
);

/// A chip built with its own `shape:`, which replaces the theme's and the ring.
final _chipCall = RegExp(
  r'\b(?:Raw|Filter|Choice|Input|Action)?Chip(?:\.elevated)?\(',
);

/// A chip theme with its own shape below the app theme replaces the ring the
/// same way; only `hermes_theme.dart` sets one.
final _chipThemeCall = RegExp(r'\bChipThemeData(?:\.\w+)?\(');
final _shapeArgument = RegExp(r'(?<![\w.])shape\s*:');

List<Hit> chipShapeHitsIn(SourceFile file) => [
  for (final (at, args) in callArguments(file, _chipCall))
    if (_shapeArgument.hasMatch(args))
      Hit(file.path, file.lineOf(at), file.lineText(file.lineOf(at))),
  if (file.path != 'lib/src/theme/hermes_theme.dart')
    for (final (at, args) in callArguments(file, _chipThemeCall))
      if (_shapeArgument.hasMatch(args))
        Hit(file.path, file.lineOf(at), file.lineText(file.lineOf(at))),
];

/// The sliding segmented control, the Material segmented button, the
/// expansion tile and a floating button, each of which draws its own focus
/// state that a wrapper or a helper turns into the keyboard ring.
final _rawSlidingControl = RegExp(
  r'(?<!FocusRing\.outside\(\s*radius:\s*9,\s*child:\s*)'
  r'(?<![\w.])(?:\w+\.)*\bCupertinoSlidingSegmentedControl(?:\s*[<(]|\.new\b)',
);
final _rawSegmentedButton = RegExp(
  r'(?<!\w)(?:\w+\.)?\bSegmentedButton(?:\s*[<(]|\.\w+)',
);
final _rawExpansionTile = RegExp(
  r'(?<![\w.])(?:\w+\.)*\bExpansionTile(?:\s*[<(]|\.\w+)',
);

/// A floating button not directly inside `FocusRing.outside(radius: ..., child:`.
final _bareFloatingButton = RegExp(
  r'(?<!FocusRing\.outside\(\s*radius:\s*[^,()]+,\s*child:\s*)'
  r'(?<![\w.])(?:\w+\.)*\bFloatingActionButton(?:(?:\.\w+)?\s*[<(]|\.\w+)',
);

/// A raw popup menu: `PopupMenuButton<T>(`, the inferred `PopupMenuButton(`,
/// or `showMenu`.
final _rawPopupMenu = RegExp(
  r'(?<![\w.])(?:PopupMenuButton\s*[<(]|showMenu\s*[<(])',
);

List<Hit> _chipShapeHits() => [
  for (final file in dartFiles('lib')) ...chipShapeHitsIn(file),
];

/// A use of the catalog's keyboard override, a call or a tear-off.
final _keyboardOverride = RegExp(r'\bmarkFocusRingKeyboardInput\b');

/// A call of the ring helpers, not a name that merely starts with theirs.
final _ringCall = RegExp(r'^focusRingShape(?:Of)?\(');

/// The theme's own `buttonShape`, exactly.
final _themeButtonShape = RegExp(r'^buttonShape(?![\w$])');

final _buttonStyleCall = RegExp(r'\b(?:\w*Button\.styleFrom|ButtonStyle)\(');
final _copyWithCall = RegExp(r'\.copyWith\(');

/// `shape:` of a `copyWith` that is not a button style's: the paths and why.
/// A button's `copyWith(shape: ...)` is the style's own and must have the
/// ring; these are other widgets' themes.
const _nonButtonCopyWithShape = <String, String>{};

/// Every `shape:` argument of a button style (`styleFrom`, `ButtonStyle`) or
/// of a `copyWith` in [file] that does not go through `focusRingShape` or
/// `focusRingShapeOf`, or the theme's `buttonShape` (in `hermes_theme.dart`
/// only). A leading `const` is ignored; a variable is not ringed.
List<Hit> buttonShapeHitsIn(SourceFile file) {
  final hits = <Hit>[];
  void scan(RegExp call) {
    for (final m in call.allMatches(file.code)) {
      final code = file.code;
      var depth = 1;
      for (var i = m.end; i < code.length && depth > 0; i++) {
        final c = code[i];
        if ('([{'.contains(c)) {
          depth++;
        } else if (')]}'.contains(c)) {
          depth--;
        } else if (depth == 1 &&
            code.startsWith('shape:', i) &&
            (i == 0 || !RegExp(r'\w').hasMatch(code[i - 1]))) {
          var value = code.substring(i + 6).trimLeft();
          if (value.startsWith('const ')) value = value.substring(6).trimLeft();
          final ringed =
              _ringCall.hasMatch(value) ||
              (file.path == 'lib/src/theme/hermes_theme.dart' &&
                  _themeButtonShape.hasMatch(value));
          if (!ringed) {
            hits.add(
              Hit(file.path, file.lineOf(i), file.lineText(file.lineOf(i))),
            );
          }
        }
      }
    }
  }

  scan(_buttonStyleCall);
  if (!_nonButtonCopyWithShape.containsKey(file.path)) scan(_copyWithCall);
  return hits;
}

List<Hit> _buttonShapeHits() => [
  for (final file in dartFiles('lib')) ...buttonShapeHitsIn(file),
];

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

/// A string literal as the `title:` of a `MacCommandHandler(`, or as the label
/// of a `MenuEntry(` or `MenuSection(`, and in the menu code itself any literal
/// `title:` or `label:` argument or first argument of the Edit-menu helper.
/// The brand label `'Hermes'` (the app menu and the Window menu's main-window
/// item) is the one literal that is the same in every language.
List<Hit> _menuLiteralLabels() {
  final handlerTitle = RegExp(r"""\btitle\s*:[^,()]*?['"]""");
  final entryLabel = RegExp(
    r"""\bMenuEntry\(\s*MacCommand\.\w+\s*,\s*(?:\(\w*\)\s*=>\s*)?['"]""",
  );
  final sectionLabel = RegExp(
    r"""\bMenuSection\(\s*['"]\w+['"]\s*,\s*(?:\(\w*\)\s*=>\s*)?['"](?!Hermes['"])""",
  );
  // Menu code builds its labels in helpers (`edit('Undo', ...)`,
  // `run(..., title: 'Pin')`, `PlatformMenu(label: 'Edit')`), so there every
  // `title:` and `label:` argument and the Edit helper's first argument count.
  final menuLabel = RegExp(
    r"""\b(?:title|label)\s*:[^,()]*?['"](?!Hermes['"])""",
  );
  final helperLabel = RegExp(
    r"""\b(?:edit|item)\(\s*(?:MacCommand\.\w+\s*,\s*)?['"](?!Hermes['"])""",
  );
  const menuFiles = {
    'lib/src/macos/mac_menu_bar.dart',
    'lib/src/macos/menu_layout.dart',
    'lib/src/macos/mac_commands.dart',
    'lib/src/macos/mac_sidebar.dart',
    'lib/src/windows/conversation_windows_menu.dart',
  };
  final hits = <Hit>[];
  for (final file in dartFiles('lib')) {
    final lines = <int>{};
    for (final (offset, args) in callArguments(
      file,
      RegExp(r'\bMacCommandHandler\('),
    )) {
      if (handlerTitle.hasMatch(args)) lines.add(file.lineOf(offset));
    }
    if (menuFiles.contains(file.path)) {
      for (final m in [
        ...menuLabel.allMatches(file.text),
        ...helperLabel.allMatches(file.text),
      ]) {
        lines.add(file.lineOf(m.start));
      }
    }
    for (final m in [
      ...entryLabel.allMatches(file.text),
      ...sectionLabel.allMatches(file.text),
    ]) {
      lines.add(file.lineOf(m.start));
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

  // docs/architecture/macos.md: the Mac Edit menu keeps Copy on for selected
  // text only where the selection area reports to it.
  _guard(
    name: 'raw-selection-area',
    message:
        'use MenuSelectionArea (lib/src/macos/menu_selection_area.dart) '
        'instead of SelectionArea, so the Mac Edit menu keeps Copy on for '
        'its selected text.',
    pattern: RegExp(r'\bSelectionArea\('),
    view: _code,
    allow: {'lib/src/macos/menu_selection_area.dart': 'the wrapper itself'},
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

  // docs/architecture/app-shell.md: the launch profile comes from
  // ProfileResolver; `active` of /api/profiles/active is the sticky CLI
  // default.
  _guard(
    name: 'sticky-active-profile',
    message:
        'ask the launch profile with repositories.profiles.resolver.load(), '
        'not loadActive() (the sticky active profile).',
    pattern: RegExp(r'\bloadActive\('),
    view: _code,
    exact: {
      'lib/src/profiles/hermes_profiles_repository.dart': ExactAllow(
        2,
        'defines loadActive and reads it in load() for the Profiles page',
      ),
    },
  ),

  // docs/architecture/app-shell.md: a missing profile is resolved, never
  // named by hand. Limit: it sees `<x>profile ?? 'default'` only, not a
  // ternary (`profile == null ? 'default' : ...`) or another variable name.
  _guard(
    name: 'default-profile-fallback',
    message:
        'resolve a missing profile with ProfileResolver.resolve; do not '
        'write `profile ?? kDefaultProfile` or `profile ?? \'default\'`.',
    pattern: RegExp(
      r"""[pP]rofile\w*\s*\?\?\s*(?:kDefaultProfile|['"]default['"])""",
    ),
    exact: {
      'lib/src/chat/chat_controller.dart': ExactAllow(
        1,
        'compares with a stored pending request; requests nothing',
      ),
      'lib/src/chat/chat_controller_voice.dart': ExactAllow(
        1,
        'key of the stop hand-backs',
      ),
      'lib/src/chat/chat_screen_navigation.dart': ExactAllow(
        1,
        'label of the connect card; requests nothing',
      ),
      'lib/src/providers/providers_screen.dart': ExactAllow(
        1,
        'label for a server without profiles',
      ),
      'lib/src/surfaces/surface_snapshot_builder.dart': ExactAllow(
        2,
        'open profile of a snapshot; stores none, no request carries it',
      ),
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

  // docs/architecture/macos.md "macOS menu bar": menu labels and the titles
  // screens give a command are localized.
  _custom(
    name: 'menu-literal-label',
    message:
        'menu labels are localized: add an ARB key under @@x-area-macos in '
        'app_en.arb and app_de.arb and read it, as (l10n) => l10n.macosMenuX '
        'in menuLayout or context.l10n.macosMenuX in a MacCommandHandler '
        'title, not a string literal.',
    hits: _menuLiteralLabels,
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

  // docs/architecture/settings-screens.md, "Keyboard focus ring": a button
  // style's own shape replaces the theme's and takes the ring with it.
  _custom(
    name: 'button-shape-without-focus-ring',
    message:
        'a button style that sets its own shape drops the keyboard focus '
        'ring: write .copyWith(shape: focusRingShapeOf(context, shape)) '
        '(lib/src/theme/focus_ring.dart) instead of shape: in styleFrom, '
        'ButtonStyle or a copyWith with a WidgetStateProperty.',
    hits: _buttonShapeHits,
  ),

  // docs/architecture/settings-screens.md, "Keyboard focus ring": a Material
  // tile keeps only its own focus fill unless it sits in a FocusRing.
  _guard(
    name: 'list-tile-without-focus-ring',
    message:
        'wrap a ListTile, CheckboxListTile, SwitchListTile or RadioListTile in '
        'FocusRing(child: ...) so the keyboard focus ring shows inside the row '
        '(lib/src/theme/focus_ring.dart).',
    pattern: _bareListTile,
    view: _code,
  ),

  // docs/architecture/settings-screens.md, "Keyboard focus ring": chips take
  // the ring from the theme's shape.
  _custom(
    name: 'chip-shape-without-focus-ring',
    message:
        'a chip that sets its own shape: drops the keyboard focus ring the '
        'theme gives it (ChipThemeData.shape, FocusRingStateBorder in '
        'lib/src/theme/focus_ring.dart): leave the shape to the theme.',
    hits: _chipShapeHits,
  ),

  // docs/architecture/settings-screens.md, "Keyboard focus ring": a menu is
  // built by AdaptivePopupMenuButton, which puts the ring on its items.
  _guard(
    name: 'popup-menu-without-focus-ring',
    message:
        'use AdaptivePopupMenuButton (or NamedPopupMenuButton): it gives each '
        'menu item the keyboard focus ring; a raw PopupMenuButton or showMenu '
        'does not.',
    pattern: _rawPopupMenu,
    view: _code,
    allow: {
      'lib/src/widgets/adaptive_popup_menu_button.dart': 'the implementation',
    },
  ),

  // docs/architecture/settings-screens.md, "Keyboard focus ring": controls
  // that draw their own focus state take the ring from one building block.
  _guard(
    name: 'sliding-control-without-focus-ring',
    message:
        'wrap a CupertinoSlidingSegmentedControl in FocusRing.outside('
        'radius: 9, child: ...) (lib/src/theme/focus_ring.dart): the track '
        'clips its segments, so the keyboard focus ring goes round the control.',
    pattern: _rawSlidingControl,
    view: _code,
  ),
  _guard(
    name: 'segmented-button-without-focus-ring',
    message:
        'use AdaptiveSegmentedControl (lib/src/widgets/adaptive_segmented_'
        'control.dart): its Material segments carry the keyboard focus ring.',
    pattern: _rawSegmentedButton,
    view: _code,
    allow: {
      'lib/src/widgets/adaptive_segmented_control.dart': 'the implementation',
    },
  ),
  _guard(
    name: 'expansion-tile-without-focus-ring',
    message:
        'use DisclosureTile (lib/src/widgets/disclosure_tile.dart): its header '
        'carries the keyboard focus ring and the disclosure semantics.',
    pattern: _rawExpansionTile,
    view: _code,
    allow: {'lib/src/widgets/disclosure_tile.dart': 'the implementation'},
  ),
  _guard(
    name: 'floating-button-without-focus-ring',
    message:
        'wrap a FloatingActionButton in FocusRing.outside(radius: <its '
        'radius>, child: ...) (lib/src/theme/focus_ring.dart): its shape is '
        'not state-aware, so the keyboard focus ring is a wrapper.',
    pattern: _bareFloatingButton,
    view: _code,
  ),

  // docs/architecture/settings-screens.md, "Keyboard focus ring": the catalog
  // forces the keyboard state of its previews; app code never does, since the
  // ring would show after a pointer press in a release build.
  _guard(
    name: 'focus-ring-keyboard-override',
    message:
        'markFocusRingKeyboardInput is for the catalog (widgetbook/) and '
        'tests only: the ring follows real input (lib/src/theme/focus_ring.dart).',
    pattern: _keyboardOverride,
    view: _code,
    allow: {'lib/src/theme/focus_ring.dart': 'defines it'},
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

  test('the keyboard-override pattern catches a call and a tear-off', () {
    expect(_keyboardOverride.hasMatch('markFocusRingKeyboardInput();'), isTrue);
    expect(
      _keyboardOverride.hasMatch('run(markFocusRingKeyboardInput);'),
      isTrue,
    );
    expect(
      _keyboardOverride.hasMatch('markFocusRingKeyboardInputs();'),
      isFalse,
    );
  });

  group('segmented control, expansion tile and floating button guards', () {
    test(
      'a raw sliding control, segmented button or expansion tile is flagged',
      () {
        expect(
          _rawSlidingControl.hasMatch('CupertinoSlidingSegmentedControl<int>('),
          isTrue,
        );
        expect(
          _rawSlidingControl.hasMatch('RingedSlidingSegmentedControl<int>('),
          isFalse,
        );
        expect(_rawSegmentedButton.hasMatch('x = SegmentedButton<T>('), isTrue);
        expect(
          _rawSegmentedButton.hasMatch('SegmentedButton.styleFrom('),
          isTrue,
        );
        expect(
          _rawSegmentedButton.hasMatch('AdaptiveSegmentedButton('),
          isFalse,
        );
        expect(_rawSegmentedButton.hasMatch('ui.SegmentedButton('), isTrue);
        expect(_rawSegmentedButton.hasMatch('m.SegmentedButton<T>('), isTrue);
        expect(
          _rawSegmentedButton.hasMatch('x = SegmentedButton.new;'),
          isTrue,
        );
        expect(
          _rawSlidingControl.hasMatch(
            'c.CupertinoSlidingSegmentedControl<int>(',
          ),
          isTrue,
        );
        expect(
          _rawSlidingControl.hasMatch(
            'f(CupertinoSlidingSegmentedControl.new)',
          ),
          isTrue,
        );
        expect(
          _rawSlidingControl.hasMatch(
            'FocusRing.outside(radius: 9, child: c.CupertinoSlidingSegmentedControl<int>(',
          ),
          isFalse,
        );
        expect(_rawExpansionTile.hasMatch('m.ExpansionTile(title: a)'), isTrue);
        expect(_rawExpansionTile.hasMatch('ExpansionTile(title: a)'), isTrue);
        expect(_rawExpansionTile.hasMatch('ExpansionTile.new'), isTrue);
        expect(_rawExpansionTile.hasMatch('DisclosureTile(title: a)'), isFalse);
      },
    );

    test('a floating button outside FocusRing.outside is flagged', () {
      bool bare(String code) => _bareFloatingButton.hasMatch(code);
      expect(bare('child: FloatingActionButton(onPressed: f)'), isTrue);
      expect(bare('FloatingActionButton.extended(onPressed: f)'), isTrue);
      expect(bare('FloatingActionButton.small(onPressed: f)'), isTrue);
      expect(
        bare(
          'FocusRing.outside(radius: 28, child: FloatingActionButton.extended(a))',
        ),
        isFalse,
      );
      expect(
        bare(
          'FocusRing.outside(\n radius: kHermesRadius,\n child: FloatingActionButton(a))',
        ),
        isFalse,
      );
      expect(
        bare('FocusRing(radius: 8, child: FloatingActionButton(a))'),
        isTrue,
      );
      expect(bare('Tooltip(child: FloatingActionButton(a))'), isTrue);
      expect(bare('child: m.FloatingActionButton(onPressed: f)'), isTrue);
      expect(bare('child: m.FloatingActionButton.extended(a)'), isTrue);
      expect(bare('builder: FloatingActionButton.new'), isTrue);
      expect(bare('builder: FloatingActionButton.extended'), isTrue);
      expect(bare('f(FloatingActionButton.small)'), isTrue);
      expect(bare('f(m.FloatingActionButton.large)'), isTrue);
      expect(bare('class MyFloatingActionButton {}'), isFalse);
      expect(
        bare('FocusRing.outside(radius: 28, child: m.FloatingActionButton(a))'),
        isFalse,
      );
    });
  });

  group('list tile, chip and popup menu guards', () {
    bool tile(String code) => _bareListTile.hasMatch(code);

    test('a tile outside FocusRing is flagged, one inside is not', () {
      expect(tile('children: [ListTile(title: a)]'), isTrue);
      expect(tile('x = SwitchListTile.adaptive(value: v)'), isTrue);
      expect(tile('CheckboxListTile(value: v)'), isTrue);
      expect(tile('FocusRing(child: ListTile(title: a))'), isFalse);
      expect(
        tile('FocusRing(\n  child: CheckboxListTile.adaptive(\n'),
        isFalse,
      );
      expect(tile('MacSourceListTile(title: a)'), isFalse);
      expect(tile('RadioListTile<int>(value: 1)'), isTrue);
      expect(tile('RadioListTile<T>.adaptive(value: v)'), isTrue);
      expect(tile('x = RadioListTile<List<int>>(value: v)'), isTrue);
      expect(tile('FocusRing(child: RadioListTile<int>(value: 1))'), isFalse);
      expect(tile('FocusRing(radius: 4, child: ListTile(title: a))'), isTrue);
    });

    int chips(String source) =>
        chipShapeHitsIn(SourceFile('lib/x.dart', source)).length;

    test('a chip with its own shape is flagged', () {
      expect(chips('x = FilterChip(label: a, shape: s);'), 1);
      expect(chips('x = Chip(label: a, side: BorderSide(color: c));'), 0);
      expect(chips('x = ChoiceChip(label: Text(a), onSelected: f);'), 0);
      expect(chips('x = StatusChip(shape: s);'), 0);
      expect(chips('x = FilterChip.elevated(label: a, shape: s);'), 1);
      expect(chips('x = ChoiceChip.elevated(label: a, onSelected: f);'), 0);
    });

    test('a chip theme shape outside the app theme is flagged', () {
      int themed(String source, String path) =>
          chipShapeHitsIn(SourceFile(path, source)).length;
      const code = 'x = ChipThemeData(shape: s);';
      expect(themed(code, 'lib/src/x.dart'), 1);
      expect(
        themed('x = ChipThemeData.fromDefaults(shape: s);', 'lib/x.dart'),
        1,
      );
      expect(themed('x = ChipThemeData(side: s);', 'lib/src/x.dart'), 0);
      expect(themed(code, 'lib/src/theme/hermes_theme.dart'), 0);
    });

    test('a popup menu without its type argument is flagged', () {
      expect(_rawPopupMenu.hasMatch('PopupMenuButton<int>(a)'), isTrue);
      expect(_rawPopupMenu.hasMatch('PopupMenuButton(itemBuilder: b)'), isTrue);
      expect(_rawPopupMenu.hasMatch('showMenu<int>(context: c)'), isTrue);
      expect(_rawPopupMenu.hasMatch('AdaptivePopupMenuButton(a)'), isFalse);
      expect(_rawPopupMenu.hasMatch('NamedPopupMenuButton<int>(a)'), isFalse);
    });
  });

  group('button-shape scan', () {
    int hits(String source, {String path = 'lib/x.dart'}) =>
        buttonShapeHitsIn(SourceFile(path, source)).length;

    test('flags a state property, a variable and a buttonShape name', () {
      expect(
        hits('final a = s.copyWith(shape: WidgetStatePropertyAll(b));'),
        1,
      );
      expect(
        hits('final a = s.copyWith(shape: const WidgetStatePropertyAll(b));'),
        1,
        reason: 'a leading const does not hide it',
      );
      expect(hits('final a = s.copyWith(shape: myShape);'), 1);
      expect(hits('final a = TextButton.styleFrom(shape: buttonShapeX);'), 1);
      expect(
        hits('final a = ButtonStyle(shape: WidgetStatePropertyAll(b));'),
        1,
      );
    });

    test('rejects a name that only starts like a ring helper', () {
      expect(hits('final a = s.copyWith(shape: focusRingShapeOverride);'), 1);
      expect(
        hits('final a = s.copyWith(shape: focusRingShapeOfX(context, b));'),
        1,
      );
      expect(
        hits(
          'final a = s.copyWith(shape: buttonShapeOverride);',
          path: 'lib/src/theme/hermes_theme.dart',
        ),
        1,
      );
    });

    test('accepts the ring helpers and the theme\'s own buttonShape', () {
      expect(
        hits('final a = s.copyWith(shape: focusRingShapeOf(context, b));'),
        0,
      );
      expect(
        hits('final a = s.copyWith(shape: const focusRingShape(b, c));'),
        0,
      );
      expect(hits('final a = TextButton.styleFrom(minimumSize: z);'), 0);
      expect(hits('final a = s.copyWith(shape: buttonShape);'), 1);
      expect(
        hits(
          'final a = s.copyWith(shape: buttonShape);',
          path: 'lib/src/theme/hermes_theme.dart',
        ),
        0,
      );
    });
  });

  group('exact allowlists', () {
    test('a file below its allowance must shrink the allowlist', () {
      for (final entry in _exactChecks.entries) {
        expect(
          exactShortfalls(entry.key, entry.value.counts(), entry.value.allowed),
          isEmpty,
          reason: 'lower or remove the ExactAllow entry in this file',
        );
      }
    });

    test('exactShortfalls names a file that fell below or to zero', () {
      expect(exactShortfalls('arch.x', {'a.dart': 1}, {'a.dart': 2}), [
        'arch.x: a.dart has 1, its allowance is 2. Shrink the allowlist to 1.',
      ]);
      expect(exactShortfalls('arch.x', {}, {'a.dart': 1}), [
        'arch.x: a.dart has 0, its allowance is 1. Shrink the allowlist to 0 '
            '(remove the entry).',
      ]);
      expect(exactShortfalls('arch.x', {'a.dart': 2}, {'a.dart': 2}), isEmpty);
    });
  });

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
