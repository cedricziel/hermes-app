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

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gateway_request_timeout_scan.dart';
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

/// Every floating button in [code] that is not in the wrapper that gives it
/// the keyboard ring, as offsets: a mini button (`mini: true`,
/// `FloatingActionButton.small`) must be directly inside
/// `MiniFabFocusRing(child:`, any other button directly inside
/// `FocusRing.outside(radius: ..., child:`, and a tear-off is never wrapped.
/// The wrappers are matched at a word boundary, so `NotMiniFabFocusRing(`
/// counts for nothing.
final _floatingButton = RegExp(
  r'(?<![\w.])(?:\w+\.)*\bFloatingActionButton(?!\w)(?:\.(\w+)\b)?',
);
final _genericCall = RegExp(r'^<[^<>()]*(?:<[^<>()]*>[^<>()]*)*>\s*\(');
final _inMiniWrapper = RegExp(
  r'\bMiniFabFocusRing\(\s*child:\s*(?:const\s+)?$',
);
final _inOutsideWrapper = RegExp(
  r'\bFocusRing\.outside\(\s*radius:\s*[^,()]+,\s*child:\s*(?:const\s+)?$',
);

List<int> bareFloatingButtons(String code) {
  final bare = <int>[];
  for (final m in _floatingButton.allMatches(code)) {
    final after = code.substring(m.end).trimLeft();
    // A call, with or without type arguments, or a `.name` / `.new` tear-off
    // is a use; a type (`FloatingActionButton? b`, `w is FloatingActionButton`,
    // `List<FloatingActionButton>`) is not.
    final call = after.startsWith('(') || _genericCall.hasMatch(after);
    if (!call && m.group(1) == null) continue;
    // The button's own arguments only: what sits in a nested call, a closure
    // or a collection (`onPressed: () => configure(mini: true)`) is not its.
    final args = StringBuffer();
    if (call) {
      final open = code.indexOf('(', m.end);
      var depth = 0;
      for (var i = open; i < code.length; i++) {
        final c = code[i];
        final opens = c == '(' || c == '[' || c == '{';
        final closes = c == ')' || c == ']' || c == '}';
        if (closes) depth--;
        if (depth == 1 && !opens && !closes) args.write(c);
        if (opens) depth++;
        if (depth == 0) break;
      }
    }
    // `mini` as a named argument only: at the start of an argument, so
    // `heroTag: c ? mini : true` is not it.
    final value = RegExp(r'(?:^|,)\s*mini\s*:\s*([^,]*)')
        .firstMatch(args.toString())
        ?.group(1)
        ?.trim();
    // Only the literals `true` and `false` can be read: any other value (a
    // variable, `!false`) hides whether the button is mini, so it is flagged.
    if (value != null && value != 'true' && value != 'false') {
      bare.add(m.start);
      continue;
    }
    final mini = m.group(1) == 'small' || value == 'true';
    final before = code.substring(0, m.start);
    final ok =
        call && (mini ? _inMiniWrapper : _inOutsideWrapper).hasMatch(before);
    if (!ok) bare.add(m.start);
  }
  return bare;
}

List<Hit> _floatingButtonHits() => [
  for (final file in dartFiles('lib'))
    for (final at in bareFloatingButtons(file.code))
      Hit(file.path, file.lineOf(at), file.lineText(file.lineOf(at))),
];

/// A raw popup menu: `PopupMenuButton<T>(`, the inferred `PopupMenuButton(`,
/// or `showMenu`.
final _rawPopupMenu = RegExp(
  r'(?<![\w.])(?:PopupMenuButton\s*[<(]|showMenu\s*[<(])',
);

List<Hit> _chipShapeHits() => [
  for (final file in dartFiles('lib')) ...chipShapeHitsIn(file),
];

/// A Windows or Linux chord of a menu command (docs/design-briefs/
/// windows-linux-platform-fixes.md, "F1 command set") bound by a widget
/// instead of declared in `menu_layout.dart`: a `SingleActivator` on one of
/// those keys without a Cmd, or a `ctrlActivator` call.
final _chordActivator = RegExp(r'\b(?:SingleActivator|ctrlActivator)\(');
final _commandKey = RegExp(
  r'^\s*(?:LogicalKeyboardKey\.)?(?:f1|f5|f8|keyN|keyF|keyR|keyB|keyP|comma)\b',
);

/// Alt with Left, Right or Up is Back, Forward and Enclosing Folder.
final _altArrowKey = RegExp(
  r'^\s*(?:LogicalKeyboardKey\.)?arrow(?:Left|Right|Up)\b',
);

bool _isMenuChord(String args) =>
    !args.contains('meta:') &&
    (_commandKey.hasMatch(args) ||
        (_altArrowKey.hasMatch(args) && args.contains('alt: true')));

List<Hit> menuChordHitsIn(SourceFile file) => [
  for (final (at, args) in callArguments(file, _chordActivator))
    if (file.code.startsWith('ctrlActivator(', at) || _isMenuChord(args))
      Hit(file.path, file.lineOf(at), file.lineText(file.lineOf(at))),
];

List<Hit> _menuChordHits() => [
  for (final file in dartFiles('lib'))
    // The page keeps Alt+Up and Alt+Down for Android and iPad keyboards,
    // where no menu command owns them.
    if (file.path != 'lib/src/macos/menu_layout.dart' &&
        file.path != 'lib/src/chat/checkpoints/pages/file_change_page.dart')
      ...menuChordHitsIn(file),
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

/// `.copyWith(platform: …)`: a theme copied onto another platform keeps the
/// base theme's tap-target size, density and platform-specific component
/// themes.
final _copyWithOpen = RegExp(r'\.copyWith\(');

/// Files under `lib/`, `widgetbook/` and `test/` that may still copy a theme onto
/// another platform, each with its reason. Empty: every preview and test host
/// builds the theme for its platform.
const _themePlatformCopyAllow = <String, String>{};

final _platformArg = RegExp(r'platform\s*:');
final _argStart = RegExp(r'[(,]\s*$');

/// A `platform:` argument at the top level of a `.copyWith(` argument list in
/// [file]. One nested in an argument (`ListTileThemeData(platform: p)`) or a
/// ternary (`c ? platform : d`) is not a hit.
List<Hit> themePlatformCopyHitsIn(SourceFile file) {
  final code = file.code;
  final hits = <Hit>[];
  for (final m in _copyWithOpen.allMatches(code)) {
    var depth = 1;
    for (var i = m.end; i < code.length && depth > 0; i++) {
      final c = code[i];
      if ('([{'.contains(c)) {
        depth++;
      } else if (')]}'.contains(c)) {
        depth--;
      } else if (depth == 1 &&
          code.startsWith('platform', i) &&
          _platformArg.matchAsPrefix(code, i) != null &&
          _argStart.hasMatch(code.substring(m.end - 1, i))) {
        final line = file.lineOf(i);
        hits.add(Hit(file.path, line, file.lineText(line)));
      }
    }
  }
  return hits;
}

List<Hit> _themePlatformCopies() => [
  for (final root in const ['lib', 'widgetbook', 'test'])
    for (final file in dartFiles(root))
      if (!isAllowed(file.path, _themePlatformCopyAllow.keys))
        ...themePlatformCopyHitsIn(file),
];

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

/// The widgets that draw the keyboard focus ring for what is built in their
/// `child:` slot, and nothing else of theirs: [FocusRing] (and
/// `FocusRing.outside`), the grouped row's ink, and the mini floating button's
/// ring. A [GroupedRow] is not one: it rings its own ink, and an ink well in its
/// `trailing` or any other slot sits inside that one with no ring.
const _ringOwners = {'FocusRing', 'GroupedRowInk', 'MiniFabFocusRing'};

/// The classes whose `InkWell` or `InkResponse` takes its ring from somewhere
/// other than an enclosing ring widget, as `path#Class`, each with the reason.
/// Exact: an entry that no longer matches a call fails, so the list shrinks with
/// the code.
const _inkWellRingOwnedElsewhere = <String, String>{
  'lib/src/widgets/grouped_list.dart#GroupedRowInk':
      'the building block itself: it wraps the ink well it builds in a '
      'FocusRing in the same build (through a local, which the syntax tree '
      'does not follow), unless the row takes no focus or draws its own mark',
};

/// How a call reads in the parse tree (nothing is resolved): the type it names
/// and the named constructor, if any. `a.B(` is the constructor of `B` under
/// the import prefix `a` or the named constructor `B` of the type `a`, so a
/// call has up to two shapes.
List<({String type, String? named})> _inkCallShapes(AstNode node) {
  if (node is InstanceCreationExpression) {
    return [
      (
        type: node.constructorName.type.name.lexeme,
        named: node.constructorName.name?.name,
      ),
    ];
  }
  if (node is MethodInvocation && !node.isCascaded) {
    final target = node.target;
    final name = node.methodName.name;
    if (target == null) return [(type: name, named: null)];
    if (target is SimpleIdentifier) {
      return [(type: name, named: null), (type: target.name, named: name)];
    }
    if (target is PrefixedIdentifier) {
      return [(type: target.identifier.name, named: name)];
    }
  }
  return const [];
}

bool _isInkCall(AstNode node) => _inkCallShapes(node).any(
  (s) => s.named == null && (s.type == 'InkWell' || s.type == 'InkResponse'),
);

ArgumentList? _argumentsOf(AstNode node) => switch (node) {
  InstanceCreationExpression() => node.argumentList,
  MethodInvocation() => node.argumentList,
  _ => null,
};

/// The handlers that make an ink well take focus, as Flutter's
/// `_primaryButtonEnabled` and `_secondaryButtonEnabled` read them
/// (`onTapCancel` alone does not).
const _inkHandlers = {
  'onTap',
  'onDoubleTap',
  'onLongPress',
  'onLongPressUp',
  'onTapUp',
  'onTapDown',
  'onSecondaryTap',
  'onSecondaryTapUp',
  'onSecondaryTapDown',
};

/// Whether the ink well [node] has a handler that is not a literal null.
bool _hasTapHandler(AstNode node) {
  for (final a in _argumentsOf(node)?.arguments ?? const <Expression>[]) {
    if (a is NamedArgument &&
        _inkHandlers.contains(a.name.lexeme) &&
        a.argumentExpression is! NullLiteral) {
      return true;
    }
  }
  return false;
}

/// Whether [node] is built in the `child:` slot of a ring owner. The walk goes
/// up the tree and stops, with no ring, at the first enclosing ink well (that
/// one decides, an outer ring does not reach through it), at any function body
/// (a callback or a route builder such as `showDialog`'s runs elsewhere), and
/// at an owner reached through any slot but `child`.
bool _insideRingOwner(AstNode node) {
  String? slot;
  for (var p = node.parent; p != null; p = p.parent) {
    if (p is FunctionBody || p is Declaration) return false;
    if (_isInkCall(p)) return false;
    if (p is NamedArgument) slot = p.name.lexeme;
    for (final shape in _inkCallShapes(p)) {
      if (_ringOwners.contains(shape.type) && slot == 'child') return true;
    }
  }
  return false;
}

/// An `InkWell(` or `InkResponse(` with a tap handler that no enclosing ring
/// widget or button covers, and the `path#Class` it sits in (no class for a
/// top-level function).
typedef InkFinding = ({Hit hit, String owner});

/// The `InkWell(` and `InkResponse(` calls of [file] with a tap handler that no
/// enclosing ring widget or button covers. Read from the analyzer's unresolved
/// syntax tree, so what encloses a call is what the tree says, not how many
/// lines above a `FocusRing` happens to be.
List<InkFinding> inkWellFindingsIn(SourceFile file) {
  final unit = parseString(
    content: file.raw,
    path: file.path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final found = <AstNode>[];
  unit.accept(_InkCalls(found));
  return [
    for (final node in found)
      if (_hasTapHandler(node) && !_insideRingOwner(node))
        (
          hit: Hit(
            file.path,
            file.lineOf(node.offset),
            file.lineText(file.lineOf(node.offset)),
          ),
          owner:
              '${file.path}#'
              '${node.thisOrAncestorOfType<ClassDeclaration>()?.namePart.typeName.lexeme ?? ''}',
        ),
  ];
}

/// Every call of a tree, for the canary.
class _AllCalls extends RecursiveAstVisitor<void> {
  _AllCalls._(this.nodes);
  final List<AstNode> nodes;

  static List<AstNode> of(AstNode unit) {
    final all = <AstNode>[];
    unit.accept(_AllCalls._(all));
    return all;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    nodes.add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    nodes.add(node);
    super.visitInstanceCreationExpression(node);
  }
}

class _InkCalls extends RecursiveAstVisitor<void> {
  _InkCalls(this.found);
  final List<AstNode> found;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isInkCall(node)) found.add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_isInkCall(node)) found.add(node);
    super.visitInstanceCreationExpression(node);
  }
}

List<InkFinding>? _inkFindings;

List<InkFinding> _allInkFindings() => _inkFindings ??= [
  for (final file in dartFiles('lib')) ...inkWellFindingsIn(file),
];

List<Hit> _inkWellHits() => [
  for (final f in _allInkFindings())
    if (!_inkWellRingOwnedElsewhere.containsKey(f.owner)) f.hit,
];

/// The widget that gives what is built in its `child:` slot a tab stop and an
/// activate key: [FocusableTap] (lib/src/widgets/focusable_tap.dart). `Focus`
/// is not one (a tab stop with no Enter or Space, and `canRequestFocus: false`
/// takes none), and a bare `FocusableActionDetector` is not either (it needs
/// actions and `enabled`; `FocusableTap` is the one that carries them). A
/// `GestureDetector` inside its `child:`, or holding one in its own `child:`
/// chain, has a keyboard path.
const _focusableOwners = {'FocusableTap'};

/// The handlers that make a `GestureDetector` a tap target: a tap, a double
/// tap, a long press or a secondary (right-click) tap. A drag, scale, pan or
/// force-press handler is not one, and `onTapCancel` alone does nothing.
const _gestureHandlers = {
  'onTap',
  'onTapUp',
  'onTapDown',
  'onDoubleTap',
  'onLongPress',
  'onLongPressStart',
  'onLongPressUp',
  'onSecondaryTap',
  'onSecondaryTapUp',
  'onSecondaryTapDown',
};

/// The classes whose `GestureDetector` is not keyboard-reachable on its own, as
/// `path#Class`, each with its reason. Only two reasons are accepted: "over a
/// focusable control" (the detector adds a pointer-only extra path, such as a
/// long press or a double tap, over a control the keyboard already reaches with
/// the same action or an equivalent) and "beside a focusable control" (the same
/// action is reachable by a focusable control next to it). Exact: an entry that
/// no longer matches a call fails, so the list shrinks with the code.
///
/// Known gaps are not on this list but in `baseline/arch.yaml`, as the ratchet
/// keeps them honest: the hold-to-record send control (F.463: the keyboard
/// cannot start a recording), the thread row's long press and `TouchRowMenu`
/// (F.474: the thread actions have no keyboard path on iPhone and iPad, and
/// Enter opens the chat) and `RowActions` (a row's actions have no keyboard
/// path on iOS for the profile row's "Change default model", and a macOS
/// right-click has none of its own; a roadmap row, to be numbered).
const _gestureDetectorKeyboardElsewhere = <String, String>{
  'lib/src/bot_screen/widgets/bot_screen_card.dart#_Tappable': 'beside a focusable control: a click on the picture opens the viewer, which the focusable Enlarge button next to it opens for the keyboard',
  'lib/src/chat/checkpoints/widgets/checkpoint_row.dart#_CheckpointRowState': 'over a focusable control: a right-click opens the row menu, which the row\'s focusable trailing menu button opens for the keyboard, over a focusable GroupedRow',
  'lib/src/chat/widgets/attachment_views.dart#_AttachmentThumbnailState': 'over a focusable control: the thumbnail is built in a local that the syntax tree does not follow into the FocusableTap and FocusRing that wrap it; on a Mac the click only selects and Quick Look opens it with Space',
  'lib/src/files/widgets/file_previews.dart#_ImagePreviewState': 'over a focusable control: the double-tap zoom sits over the viewer, which ZoomKeyboardShortcuts zooms from the keyboard',
  'lib/src/macos/mac_sidebar.dart#MacSplitView': 'beside a focusable control: a click on the scrim closes the sidebar overlay, which the focusable sidebar toggle (and its chord) closes for the keyboard',
  'lib/src/macos/mac_source_list.dart#_MacSourceListTileState': 'over a focusable control: a right-click over the tile\'s focusable, ringed InkWell opens its menu; on a Mac the keyboard equivalent is the menu bar\'s Pin, Rename and Archive commands for the selected thread (the row\'s More and Archive buttons show only under the pointer and take no focus)',
  'lib/src/models/widgets/model_picker.dart#_EffortSegment': 'over a focusable control: the detector only extends the tap target of the focusable, ringed InkWell pill it wraps',
  'lib/src/server_care/widgets/usage_chart.dart#_UsageChartState': 'over a focusable control: a tap or hover on the plot selects a day, which the chart\'s own Focus selects with the arrow, Home and End keys',
  'lib/src/tools/widgets/tools_switch.dart#ToolsSwitch': 'beside a focusable control: the box around the switch is the touch target, and the focusable GroupedSwitch inside it toggles the same value from the keyboard',
  'lib/src/widgets/adaptive_popup_menu_button.dart#_AdaptivePopupMenuButtonState': 'over a focusable control: the trigger it wraps is built by _ringed, a FocusableTap in a FocusRing, which opens the same menu from the keyboard',
  'lib/src/widgets/adaptive_popup_menu_button.dart#_ContextMenuRowState': 'over a focusable control: a right-click over a row opens the menu of the row\'s focusable AdaptivePopupMenuButton',
  'lib/src/widgets/adaptive_segmented_control.dart#_ExtendedHitArea': 'over a focusable control: it only extends the tap area of the focusable segments inside it, whose own taps win',
  'lib/src/widgets/inspector_layout.dart#InspectorLayout': 'beside a focusable control: a click on the barrier closes the overlaid Activity inspector, which the focusable Activity toggle in the toolbar closes too, and Escape closes while focus is inside the overlay',
};

bool _isGestureCall(AstNode node) =>
    _inkCallShapes(node)
        .any((s) => s.named == null && s.type == 'GestureDetector');

bool _hasGestureHandler(AstNode node) {
  for (final a in _argumentsOf(node)?.arguments ?? const <Expression>[]) {
    if (a is NamedArgument &&
        _gestureHandlers.contains(a.name.lexeme) &&
        a.argumentExpression is! NullLiteral) {
      return true;
    }
  }
  return false;
}

/// Whether [node] is a focusable owner, or reaches one through `child:` slots
/// only (a `Padding`, a `Semantics`, a `DecoratedBox` between them).
bool _childChainHasOwner(AstNode node) {
  for (var n = node; ;) {
    Expression? child;
    for (final a in _argumentsOf(n)?.arguments ?? const <Expression>[]) {
      if (a is NamedArgument && a.name.lexeme == 'child') {
        child = a.argumentExpression;
      }
    }
    if (child == null) return false;
    if (_inkCallShapes(child).any((s) => _focusableOwners.contains(s.type))) {
      return true;
    }
    n = child;
  }
}

/// Whether [node] sits in the `child:` slot of a focusable owner, on the same
/// walk rules as [_insideRingOwner]: it stops at a function body, a declaration
/// and the first enclosing gesture detector.
bool _insideFocusableOwner(AstNode node) {
  String? slot;
  for (var p = node.parent; p != null; p = p.parent) {
    if (p is FunctionBody || p is Declaration) return false;
    if (_isGestureCall(p)) return false;
    if (p is NamedArgument) slot = p.name.lexeme;
    for (final shape in _inkCallShapes(p)) {
      if (_focusableOwners.contains(shape.type) && slot == 'child') return true;
    }
  }
  return false;
}

/// The `GestureDetector(` calls of [file] with a tap-like handler that no
/// focusable owner covers, in the shape of [inkWellFindingsIn].
List<InkFinding> gestureDetectorFindingsIn(SourceFile file) {
  final unit = parseString(
    content: file.raw,
    path: file.path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  return [
    for (final node in _AllCalls.of(unit))
      if (_isGestureCall(node) &&
          _hasGestureHandler(node) &&
          !_childChainHasOwner(node) &&
          !_insideFocusableOwner(node))
        (
          hit: Hit(
            file.path,
            file.lineOf(node.offset),
            file.lineText(file.lineOf(node.offset)),
          ),
          owner:
              '${file.path}#'
              '${node.thisOrAncestorOfType<ClassDeclaration>()?.namePart.typeName.lexeme ?? ''}',
        ),
  ];
}

List<InkFinding>? _gestureFindings;

List<InkFinding> _allGestureFindings() => _gestureFindings ??= [
  for (final file in dartFiles('lib')) ...gestureDetectorFindingsIn(file),
];

List<Hit> _gestureDetectorHits() => [
  for (final f in _allGestureFindings())
    if (!_gestureDetectorKeyboardElsewhere.containsKey(f.owner)) f.hit,
];

/// A parameter default that is an English word or sentence, as the text of one
/// string literal: it starts with a capital letter, holds a space, or ends in
/// sentence punctuation. A lowercase id (`menu`, `png`, `/api/ws`) is none of
/// these.
bool looksLikeEnglishLabel(String value) {
  if (!RegExp(r'[A-Za-z]').hasMatch(value)) return false;
  return RegExp(r'^[A-Z]').hasMatch(value) ||
      value.contains(' ') ||
      RegExp(r'[.!?:\u2026]$').hasMatch(value);
}

/// Parameter defaults that read as English but are not visible UI text, as
/// `path#parameter`, each with the reason. Exact: an entry that no longer
/// matches fails, so the list shrinks with the code.
const _englishDefaultNotVisibleText = <String, String>{
  'lib/src/drag_out/sanitize_drag_file_name.dart#fallback':
      'a file name handed to another app when nothing is left of the dragged '
      'name, not a label drawn in the app; callers pass their own',
};

/// A `String` parameter default that is an English literal, and the
/// `path#parameter` it is on.
typedef EnglishDefault = ({Hit hit, String owner});

/// The parameters of [file] (named, optional positional, `this.x` and
/// `super.x`) whose default is a plain string literal that reads as English.
/// Read from the analyzer's unresolved syntax tree. A default that is a
/// constant, an interpolation or an empty string is not one.
List<EnglishDefault> englishDefaultsIn(SourceFile file) {
  final unit = parseString(
    content: file.raw,
    path: file.path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final found = <EnglishDefault>[];
  unit.accept(
    _DefaultClauses((clause) {
      final value = clause.value;
      final text = value is StringLiteral ? value.stringValue : null;
      if (text == null || !looksLikeEnglishLabel(text)) return;
      final parameter = clause.parent;
      if (parameter is! FormalParameter) return;
      final name = parameter.name;
      if (name == null) return;
      final line = file.lineOf(clause.offset);
      found.add((
        hit: Hit(file.path, line, file.lineText(line)),
        owner: '${file.path}#${name.lexeme}',
      ));
    }),
  );
  return found;
}

class _DefaultClauses extends RecursiveAstVisitor<void> {
  _DefaultClauses(this.onClause);
  final void Function(FormalParameterDefaultClause) onClause;

  @override
  void visitFormalParameterDefaultClause(FormalParameterDefaultClause node) {
    onClause(node);
    super.visitFormalParameterDefaultClause(node);
  }
}

List<EnglishDefault>? _englishDefaults;

List<EnglishDefault> _allEnglishDefaults() => _englishDefaults ??= [
  for (final file in dartFiles('lib'))
    if (!file.path.startsWith('lib/l10n/') &&
        !file.path.endsWith('.g.dart') &&
        !file.path.endsWith('.freezed.dart'))
      ...englishDefaultsIn(file),
];

/// `?? '...'` or `?? "..."` whose literal holds a letter: a null fallback that
/// can be visible English. `arch.english-default-label` reads parameter
/// defaults; this reads the expression form, which sits inside build methods.
final _englishNullFallback = RegExp(
  r"""\?\?\s*(?:'[^'\n]*[A-Za-z][^'\n]*'|"[^"\n]*[A-Za-z][^"\n]*")""",
);

/// The files `style.string` reads: those importing the widget layer.
final _widgetLayerImport = RegExp(
  r"""^import\s+['"]package:(?:flutter/(?:material|widgets|cupertino)|"""
  r"""material_ui/material_ui|cupertino_ui/cupertino_ui)\.dart['"]""",
  multiLine: true,
);

final _partOf = RegExp(
  r"""^part\s+of\s+['"]([^'"]+)['"]\s*;""",
  multiLine: true,
);

/// A `part of` file has no imports of its own: it belongs to the widget layer
/// when the library file it names imports it.
bool _importsWidgetLayer(SourceFile f) {
  if (!f.path.startsWith('lib/src/')) return false;
  if (_widgetLayerImport.hasMatch(f.raw)) return true;
  final parent = _partOf.firstMatch(f.raw)?.group(1);
  if (parent == null) return false;
  final file = File(Uri.file(f.path).resolve(parent).toFilePath());
  return file.existsSync() &&
      _widgetLayerImport.hasMatch(file.readAsStringSync());
}

/// Files whose `?? 'literal'` is not visible text, with how many such hits
/// each keeps and why (exact: the count shrinks with the code). Other hits of
/// the same file are real labels and stay in `baseline/arch.yaml`.
const _englishNullFallbackNotVisibleText = <String, ExactAllow>{
  'lib/src/tools/widgets/readiness_row.dart': ExactAllow(
    2,
    "the platform name 'macOS', a proper noun the same in every language",
  ),
  'lib/src/chat/widgets/chat_header.dart': ExactAllow(
    1,
    "the product name 'Hermes'",
  ),
  'lib/src/chat/chat_screen_layout.dart': ExactAllow(
    1,
    "the product name 'Hermes'",
  ),
  'lib/src/chat/chat_screen_navigation.dart': ExactAllow(
    1,
    "the profile id 'default', sent to the server, not shown",
  ),
  'lib/src/widgets/hermes_code_block.dart': ExactAllow(
    1,
    "the font family 'JetBrainsMono'",
  ),
  'lib/src/chat/widgets/tool_value_view.dart': ExactAllow(
    1,
    "a code language's name built from the fence's own tag, capitalised: a "
    'proper name, no English words',
  ),
  'lib/src/providers/providers_screen.dart': ExactAllow(
    1,
    "the profile id 'default', the name Hermes gives a server without "
    'profiles',
  ),
  'lib/src/voice/voice_call_screen.dart': ExactAllow(
    1,
    'part of the English setup prompt (setupPrompt) that is sent to the agent '
    'as a chat message: the prompt is English as a whole, not UI text',
  ),
};

List<Hit> _englishDefaultHits() => [
  for (final f in _allEnglishDefaults())
    if (!_englishDefaultNotVisibleText.containsKey(f.owner)) f.hit,
];

/// A function named `*Label`, `*Title` or `*Summary`, with the literal it
/// returns, and `path#name` as the owner (`path#Class.name` for a static
/// method).
typedef LabelHelper = ({Hit hit, String owner, String literal});

final _labelHelperName = RegExp(
  r'^(?:label|title|summary)$|(?:Label|Title|Summary)$',
);
const _labelReturnTypes = {
  'String',
  'String?',
  'Future<String>',
  'Future<String?>',
  'FutureOr<String>',
  'FutureOr<String?>',
  'Stream<String>',
  'Stream<String?>',
};
final _l10nParameterType = RegExp(r'\b(?:AppLocalizations|BuildContext)\b');

/// The top-level functions and static methods of [file] named `*Label`,
/// `*Title` or `*Summary` that return `String`, `String?`, `Future<String>`,
/// `Future<String?>`, `FutureOr<String>`, `FutureOr<String?>`,
/// `Stream<String>` or `Stream<String?>` (or declare no type), return or
/// yield at
/// least one string literal that holds a letter, and take neither an
/// `AppLocalizations` nor a `BuildContext`. Read from the analyzer's
/// unresolved syntax tree. A literal counts when it sits in a returned
/// expression outside call arguments, index expressions and function
/// literals, so `return table['key']` and `return s.replaceAll('a', 'b')`
/// are not hits; a returned variable or call is none either.
List<LabelHelper> labelHelpersIn(SourceFile file) {
  final unit = parseString(
    content: file.raw,
    path: file.path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;
  final found = <LabelHelper>[];
  void check(
    String? prefix,
    Token name,
    TypeAnnotation? returnType,
    FormalParameterList? parameters,
    FunctionBody body,
  ) {
    if (!_labelHelperName.hasMatch(name.lexeme)) return;
    final type = returnType?.toSource();
    if (type != null && !_labelReturnTypes.contains(type)) return;
    for (final p in parameters?.parameters ?? const <FormalParameter>[]) {
      if (_l10nParameterType.hasMatch(p.toSource())) return;
    }
    final finder = _ReturnedLiteral();
    body.accept(finder);
    final literal = finder.literal;
    if (literal == null) return;
    final line = file.lineOf(name.offset);
    found.add((
      hit: Hit(file.path, line, file.lineText(line)),
      owner: '${file.path}#${prefix == null ? '' : '$prefix.'}${name.lexeme}',
      literal: literal,
    ));
  }

  for (final member in unit.declarations) {
    if (member is FunctionDeclaration && !member.isGetter) {
      check(
        null,
        member.name,
        member.returnType,
        member.functionExpression.parameters,
        member.functionExpression.body,
      );
    }
  }
  unit.accept(
    _StaticMethods((owner, m) {
      if (m.isGetter || m.isSetter) return;
      check(owner, m.name, m.returnType, m.parameters, m.body);
    }),
  );
  return found;
}

/// The static methods of classes, enums, mixins, extensions and extension
/// types, with the name of the one that holds each.
class _StaticMethods extends RecursiveAstVisitor<void> {
  _StaticMethods(this.onMethod);
  final void Function(String owner, MethodDeclaration) onMethod;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!node.isStatic) return;
    final holder = node.parent?.parent;
    final name = switch (holder) {
      ClassDeclaration() => holder.namePart.typeName.lexeme,
      EnumDeclaration() => holder.namePart.typeName.lexeme,
      MixinDeclaration() => holder.name.lexeme,
      ExtensionDeclaration() => holder.name?.lexeme ?? 'extension',
      ExtensionTypeDeclaration() => holder.namePart.typeName.lexeme,
      _ => null,
    };
    if (name != null) onMethod(name, node);
  }
}

/// The first string literal with a letter in an expression a body returns.
class _ReturnedLiteral extends RecursiveAstVisitor<void> {
  String? literal;

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    _scan(node.expression);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    final e = node.expression;
    if (e != null) _scan(e);
  }

  // A `Stream<String>` helper yields its text.
  @override
  void visitYieldStatement(YieldStatement node) => _scan(node.expression);

  // A nested function's returns are not this function's.
  @override
  void visitFunctionExpression(FunctionExpression node) {}

  void _scan(Expression e) {
    if (literal != null) return;
    final finder = _LiteralFinder();
    e.accept(finder);
    literal = finder.literal;
  }
}

class _LiteralFinder extends RecursiveAstVisitor<void> {
  String? literal;
  // Latin letters; the multiplication and division signs (U+00D7, U+00F7)
  // sit inside the accented range and are not letters.
  static final _letter = RegExp(
    r'[A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u024F]',
  );

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (literal == null && _letter.hasMatch(node.value)) literal = node.value;
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    for (final part in node.elements) {
      if (part is InterpolationString && _letter.hasMatch(part.value)) {
        literal ??= part.value;
      } else if (part is InterpolationExpression) {
        part.expression.accept(this);
      }
    }
  }

  @override
  void visitArgumentList(ArgumentList node) {}

  // `s == 'done' ? a : b` tests a value; the literal is never shown.
  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.type;
    if (op == TokenType.EQ_EQ || op == TokenType.BANG_EQ) return;
    super.visitBinaryExpression(node);
  }

  // `'a' => ...` is a pattern that matches; only the arm's value is shown.
  @override
  void visitSwitchExpressionCase(SwitchExpressionCase node) {
    node.expression.accept(this);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {}

  @override
  void visitIndexExpression(IndexExpression node) {
    node.target?.accept(this);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {}
}

/// Label helpers that return text nobody reads, as `path#name` with the
/// reason. Exact: an entry that no longer matches fails.
const _labelHelperNotVisibleText = <String, String>{};

List<LabelHelper>? _labelHelpers;

List<LabelHelper> _allLabelHelpers() => _labelHelpers ??= [
  for (final file in dartFiles('lib'))
    if (_importsWidgetLayer(file)) ...labelHelpersIn(file),
];

List<Hit> _labelHelperHits() => [
  for (final f in _allLabelHelpers())
    if (!_labelHelperNotVisibleText.containsKey(f.owner)) f.hit,
];

/// An `import` or `export` of a Flutter barrel, or of a file under
/// `package:flutter/src/material` or `src/cupertino`, that starts a line. The
/// URI may be a raw string (`r'...'`).
final _flutterBarrelImport = RegExp(
  r'''^[ \t]*(import|export)\s+r?['"]package:flutter/'''
  r'''(?:(?:material|cupertino)\.dart|src/(?:material|cupertino)/[^'"\n]*)['"]''',
  multiLine: true,
);

/// Imports and exports of the Flutter Material or Cupertino libraries in
/// [file]. The pattern runs on the text view, so a line inside a multi-line
/// string that merely looks like a directive is dropped: its keyword is blank
/// in the code view.
List<Hit> flutterBarrelImportHitsIn(SourceFile file) {
  final code = file.code;
  return [
    for (final m in _flutterBarrelImport.allMatches(file.text))
      if (code.startsWith(
        m.group(1)!,
        m.start + m.group(0)!.indexOf(m.group(1)!),
      ))
        Hit(
          file.path,
          file.lineOf(m.start),
          file.lineText(file.lineOf(m.start)),
        ),
  ];
}

/// Dart roots the barrel guard reads; `packages/hermes_api` is generated.
const _barrelRoots = [
  'lib',
  'test',
  'widgetbook',
  'integration_test',
  'test_driver',
  'packages',
  'benchmark',
  'tool',
  'scripts',
];

List<Hit> _flutterBarrelImports() => [
  for (final root in _barrelRoots)
    for (final file in dartFiles(root))
      if (!file.path.startsWith('packages/hermes_api/'))
        ...flutterBarrelImportHitsIn(file),
];

/// Every guard of this file.
final guardRules = <Rule>[
  // docs/architecture/gateway.md, "Request deadlines": a deadline belongs to
  // the request, not to the caller waiting for it.
  _custom(
    name: 'gateway-request-timeout',
    message:
        '.timeout(...) on a gateway RPC future abandons the caller and leaves '
        'the request, its pending entry and its span open until the socket '
        'ends: pass the deadline to the request instead, '
        'GatewayRpcClient.requestWithin(method, params, timeout: d) (or '
        'requestGuarded, the timeout: of requestKeepingConnection, or the '
        'third argument of BackgroundContext.request), which '
        'settles the request and ends its span '
        '(lib/src/chat/gateway/gateway_rpc_client.dart).',
    hits: gatewayRequestTimeoutHits,
  ),

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

  // Flutter 3.50 deprecates the two barrels (#1232).
  _custom(
    name: 'material-ui-imports',
    message:
        'import package:material_ui/material_ui.dart and '
        'package:cupertino_ui/cupertino_ui.dart, not package:flutter/material.dart '
        'or package:flutter/cupertino.dart (deprecated since Flutter 3.50), and '
        'not a deep package:flutter/src/material or src/cupertino file. '
        'Rewrite the barrel imports with: dart run '
        'tool/migrate_material_ui_imports.dart <file ...>; a deep import needs '
        'the matching public library of those packages by hand.',
    hits: _flutterBarrelImports,
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

  // docs/architecture/settings-screens.md, "Keyboard focus ring": a tappable
  // row or card takes its ring from FocusRing, not from Material's own tint.
  _custom(
    name: 'inkwell-without-focus-ring',
    message:
        'an InkWell or InkResponse with an onTap takes keyboard focus and shows '
        'no ring of its own: put it inside FocusRing(radius: <the row\'s '
        'radius minus 2>, child: ...) for a row or card a container clips, '
        'FocusRing.outside(radius: ...) for a tap target nothing clips '
        '(lib/src/theme/focus_ring.dart), or GroupedRowInk / GroupedRow in a '
        'grouped section; a class (path#Class) whose ring another widget owns goes on '
        '_inkWellRingOwnedElsewhere with its reason.',
    hits: _inkWellHits,
  ),

  // docs/architecture/settings-screens.md, "Keyboard focus ring": a tap box a
  // GestureDetector builds is a keyboard control only through FocusableTap.
  _custom(
    name: 'gesture-detector-without-focus',
    message:
        'a GestureDetector with a tap, double tap or long press handler has no '
        'tab stop and no Enter or Space: build the control with FocusableTap('
        'onActivate: ..., child: ...) (lib/src/widgets/focusable_tap.dart) '
        'inside a FocusRing (lib/src/theme/focus_ring.dart), or an InkWell. A '
        'class (path#Class) whose detector is a pointer-only extra path '
        '"over a focusable control", or whose action a focusable control '
        '"beside" it reaches, goes on _gestureDetectorKeyboardElsewhere with '
        'that reason.',
    hits: _gestureDetectorHits,
  ),

  // CLAUDE.md "Architecture" > Localization; docs/architecture/localization.md.
  _custom(
    name: 'english-default-label',
    message:
        'a String parameter whose default is an English literal shows English '
        'in a German UI and the style score cannot see it: take the label as '
        'a required parameter, or nullable with no default, and resolve the '
        'fallback with context.l10n.<key> at the widget layer (a key in '
        'lib/l10n/arb/app_en.arb and app_de.arb). A default that is not '
        'visible text goes on _englishDefaultNotVisibleText (path#parameter) '
        'with its reason.',
    hits: _englishDefaultHits,
  ),
  _guard(
    name: 'english-null-fallback',
    message:
        'a `?? \'English text\'` in a widget file shows English in a German UI '
        'when the value is null and the style score cannot see it: resolve '
        'the fallback with context.l10n.<key> (a key in '
        'lib/l10n/arb/app_en.arb and app_de.arb). A fallback that is not '
        'visible text (an id, a header, a file name) goes on '
        '_englishNullFallbackNotVisibleText (path, exact count) with its reason, or is '
        'written as a named constant.',
    pattern: _englishNullFallback,
    where: _importsWidgetLayer,
    exact: _englishNullFallbackNotVisibleText,
  ),
  _custom(
    name: 'label-helper-takes-l10n',
    message:
        'a top-level function or static method named *Label, *Title or '
        '*Summary that returns an English literal shows English in a German '
        'UI: pass AppLocalizations and return l10n.<key>, like '
        'kanbanStatusLabel(l10n, status) and effortLabel(l10n, effort) (keys '
        'in lib/l10n/arb/app_en.arb and app_de.arb). A helper whose text is '
        'not visible (an id, a semantic identifier, a debug label, a server '
        'value passed through) goes on _labelHelperNotVisibleText '
        '(path#name) with its reason.',
    hits: _labelHelperHits,
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

  // docs/architecture/macos.md, "Keyboard shortcuts on Windows and Linux": the
  // chords of the menu commands are declared once, in menu_layout.dart.
  _custom(
    name: 'menu-chord-outside-menu-layout',
    message:
        'a menu command\'s chord is declared once, next to the Mac\'s, in '
        'lib/src/macos/menu_layout.dart (desktopShortcuts), and the screen '
        'offers the command with a MacCommandScope; DesktopCommandShortcuts '
        '(lib/src/navigation/) binds it. A second handler for the same key '
        'fires twice or fights the first.',
    hits: _menuChordHits,
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
  _custom(
    name: 'floating-button-without-focus-ring',
    message:
        'wrap a FloatingActionButton in FocusRing.outside(radius: <its '
        'radius>, child: ...) or a mini one (mini: true or .small) in '
        'MiniFabFocusRing(child: ...) (lib/src/theme/focus_ring.dart): its '
        'shape is not state-aware, so the keyboard focus ring is a wrapper. '
        'mini: must be the literal true or false: write a literal mini: true '
        'button inside MiniFabFocusRing, or a regular button inside '
        'FocusRing.outside.',
    hits: _floatingButtonHits,
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

  // docs/architecture/settings-screens.md, "Dialogs and sheets": a dialog that
  // binds Esc itself must keep it after a click took focus out of its field;
  // test/widgets/dialog_esc_guard_test.dart walks the dialogs that do.
  _guard(
    name: 'dismiss-intent-binding',
    message:
        'a dialog that needs its own Esc wraps its content in '
        'DismissOnEscape (lib/src/widgets/route_dismissal.dart), which keeps '
        'a FocusScope below the binding; add the dialog to '
        'test/widgets/dialog_esc_guard_test.dart.',
    pattern: RegExp(r'\bDismissIntent\b'),
    view: _code,
    allow: {
      'lib/src/widgets/route_dismissal.dart': 'DismissOnEscape, the block',
      'lib/src/widgets/grouped_dialog.dart':
          'Done-only GroupedDialogs have no text field, and a click does not '
          'move focus off the autofocused wrapper; tested: dialog_esc_guard_'
          'test.dart "appearance on iOS: a click on the title, then Esc"',
      'lib/src/widgets/anchored_popover.dart':
          'its barrier is dismissible, so the route\'s own Esc closes it when '
          'a click moves focus to the route scope; tested: anchored_popover_'
          'test.dart "Escape closes a popover after a mouse click inside it"',
      'lib/src/chat/subagents/bound_agent_detail.dart':
          'a FocusScope (parentScope traversal) sits below its Actions; '
          'tested: bound_activity_panel_agents_test.dart "Escape after a mouse '
          'click inside the detail" and "Tab from the note field"',
      'lib/src/bot_screen/viewer/bot_screen_viewer.dart':
          'no text field, so a click does not move focus out of its Focus; '
          'tested: bot_screen_viewer_chat_screen_test.dart "Escape still '
          'closes the overlay after a mouse click on its edge"',
    },
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
  _custom(
    name: 'theme-platform-copy',
    message:
        'build the theme for the platform instead of copying one onto it: '
        'buildHermesLightTheme(platform: p) / buildHermesDarkTheme(platform: '
        'p), or platformTheme(context, p) in widgetbook/. '
        '`.copyWith(platform: …)` keeps the base theme\'s materialTapTargetSize, '
        'visualDensity and platform-specific component themes, so a Mac case '
        'under flutter test gets phone sizing.',
    hits: _themePlatformCopies,
  ),
];

void main() {
  ratchetTests(guardRules, namespace: 'arch');

  group('gateway request timeout scan', () {
    int hits(String source, {String path = 'lib/src/x.dart'}) =>
        gatewayRequestTimeoutHitsIn(SourceFile(path, source)).length;

    test('flags a timeout wrapped around a request call', () {
      expect(hits("f() => client.request('session.resume', p).timeout(t);"), 1);
      expect(hits('f() async => await t.request(method, p).timeout(d);'), 1);
      expect(
        hits(
          "f() => (c.requestWithin('a.b', p, timeout: d)).timeout(t, onTimeout: g);",
        ),
        1,
      );
      expect(hits('f() => t.requestKeepingConnection(m, p).timeout(d);'), 1);
      expect(
        hits("f() => c.request('x.y', {}).then((r) => r).timeout(t);"),
        1,
        reason: 'a chain after the call',
      );
    });

    test('flags a variable that holds a request, in the same member', () {
      expect(
        hits(
          'f() async {\n'
          "  final pending = client.request('session.resume', p);\n"
          '  return await pending.timeout(t);\n'
          '}',
        ),
        1,
      );
    });

    test('flags the transport helpers only inside the gateway directory', () {
      const source = 'f() => _call(client, m, p).timeout(t);';
      expect(hits(source, path: 'lib/src/chat/gateway/x.dart'), 1);
      expect(hits(source), 0);
    });

    test('leaves other futures and other request APIs alone', () {
      for (final fine in [
        'f() => connect().timeout(t);',
        'f() => pending.timeout(t);',
        'f() => permission.request().timeout(t);',
        'f() => queue.request(open).timeout(t);',
        "f() => dio.request('/x').timeout(t);",
        "f() => client.request('session.resume', p);",
        'f() async {\n  final x = other();\n  return x.timeout(t);\n}',
        "// client.request('a.b', p).timeout(t)\nf() => 1;",
        "f() => 'client.request(a.b).timeout(t)';",
      ]) {
        expect(hits(fine), 0, reason: fine);
      }
    });

    test('a same-named local of another block is not followed', () {
      expect(
        hits(
          'f() async {\n'
          "  { final pending = client.request('session.resume', {}); "
          'await pending; }\n'
          '  { final pending = other(); await pending.timeout(t); }\n'
          '}',
        ),
        0,
      );
      expect(
        hits(
          'f() async {\n'
          '  { final pending = other(); await pending; }\n'
          "  { final pending = client.request('session.resume', {}); "
          'await pending.timeout(t); }\n'
          '}',
        ),
        1,
      );
    });

    test('a local shadowed in a closed inner block is not the one used '
        'after it', () {
      expect(
        hits(
          'f() async {\n'
          '  final pending = other();\n'
          "  { final pending = client.request('session.resume', {}); "
          'await pending; }\n'
          '  await pending.timeout(t);\n'
          '}',
        ),
        0,
      );
    });

    test('a variable of another member is not followed', () {
      expect(
        hits(
          "g() { final pending = client.request('a.b', p); }\n"
          'f() => pending.timeout(t);',
        ),
        0,
      );
    });
  });

  group('theme-platform-copy scan', () {
    int hits(String source) =>
        themePlatformCopyHitsIn(SourceFile('test/x.dart', source)).length;

    test('catches a platform argument at any position and nesting before', () {
      for (final bad in [
        'Theme.of(context).copyWith(platform: platform)',
        'base.copyWith(\n  platform: TargetPlatform.macOS,\n)',
        'buildHermesLightTheme().copyWith(platform: p)',
        'base.copyWith(visualDensity: d, platform: p)',
        'base.copyWith(\n  appBarTheme: AppBarTheme(leadingWidth: 4),\n  platform: p,\n)',
        'base.copyWith(appBarTheme: AppBarTheme(titleTextStyle: '
            'TextStyle(fontSize: 12)), platform: p)',
        'b.copyWith(\n  textTheme: b.textTheme.apply(bodyColor: '
            'Color(Colors.red.toARGB32())),\n  platform: p,\n)',
      ]) {
        expect(hits(bad), 1, reason: bad);
      }
    });

    test('ignores nested platform arguments, ternaries and other calls', () {
      for (final fine in [
        'buildHermesLightTheme(platform: p)',
        'Theme.of(context).copyWith(visualDensity: d)',
        'theme.copyWith(appBarTheme: a, platform2: p)',
        'MediaQuery.of(context).copyWith(size: s)',
        'base.copyWith(tile: ListTileThemeData(platform: p))',
        'base.copyWith(visualDensity: c ? platform : d)',
        'x.copyWith(a: f(g(platform: p)))',
      ]) {
        expect(hits(fine), 0, reason: fine);
      }
    });

    test('ignores comments and strings', () {
      final f = SourceFile(
        'test/x.dart',
        "// base.copyWith(platform: p)\nfinal s = 'a.copyWith(platform: p)';\n"
            'final t = base.copyWith(platform: p);\n',
      );
      final found = themePlatformCopyHitsIn(f);
      expect(found, hasLength(1));
      expect(found.single.line, 3);
    });
  });

  group('material-ui-imports scan', () {
    int hits(String source) =>
        flutterBarrelImportHitsIn(SourceFile('test/x.dart', source)).length;

    test('catches the barrels, deep imports and raw-string URIs', () {
      for (final bad in [
        "import 'package:flutter/material.dart';",
        'export "package:flutter/cupertino.dart" show CupertinoIcons;',
        "import 'package:flutter/src/material/app_bar.dart';",
        "import 'package:flutter/src/cupertino/colors.dart' as c;",
        "import r'package:flutter/material.dart';",
        'import r"package:flutter/src/material/scaffold.dart";',
        "  import 'package:flutter/material.dart';",
      ]) {
        expect(hits(bad), 1, reason: bad);
      }
    });

    test('ignores other flutter libraries, comments and lookalikes', () {
      for (final fine in [
        "import 'package:flutter/widgets.dart';",
        "import 'package:flutter/src/widgets/framework.dart';",
        "import 'package:flutter/src/materialish/x.dart';",
        "import 'package:material_ui/material_ui.dart';",
        "// import 'package:flutter/material.dart';",
        "final s = \"import 'package:flutter/material.dart';\";",
      ]) {
        expect(hits(fine), 0, reason: fine);
      }
    });

    test(
      'a directive-looking line in a multi-line string is not an import',
      () {
        const inString =
            "const src = '''\n"
            "import 'package:flutter/material.dart';\n"
            "export 'package:flutter/src/cupertino/x.dart';\n"
            "''';\n"
            "const raw = r'''\n"
            "import r'package:flutter/material.dart';\n"
            "''';\n";
        expect(hits(inString), 0);
        final real = SourceFile(
          'test/x.dart',
          "$inString\nimport 'package:flutter/material.dart';\n",
        );
        expect(flutterBarrelImportHitsIn(real).single.line, 9);
      },
    );
  });

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

    test('a floating button outside its wrapper is flagged', () {
      bool bare(String code) => bareFloatingButtons(code).isNotEmpty;
      const outside = 'FocusRing.outside(radius: 28, child: ';
      expect(bare('child: FloatingActionButton(onPressed: f)'), isTrue);
      expect(bare('FloatingActionButton.extended(onPressed: f)'), isTrue);
      expect(bare('Tooltip(child: FloatingActionButton(a))'), isTrue);
      expect(
        bare('FocusRing(radius: 8, child: FloatingActionButton(a))'),
        isTrue,
      );
      expect(bare('${outside}FloatingActionButton.extended(a))'), isFalse);
      expect(bare('${outside}m.FloatingActionButton(a))'), isFalse);
      expect(
        bare(
          'FocusRing.outside(\n radius: kHermesRadius,\n child: FloatingActionButton(a))',
        ),
        isFalse,
      );
      // A bare inset-0 ring fits one platform only.
      expect(
        bare('FocusRing(radius: 24, inset: 0, child: FloatingActionButton(a))'),
        isTrue,
      );
      // Tear-offs are never wrapped.
      expect(bare('builder: FloatingActionButton.new'), isTrue);
      expect(bare('builder: FloatingActionButton.extended'), isTrue);
      expect(bare('f(m.FloatingActionButton.large)'), isTrue);
      expect(bare('f(FloatingActionButton.small)'), isTrue);
      expect(bare('class MyFloatingActionButton {}'), isFalse);
    });

    test('theme, location and animator names are not floating buttons', () {
      bool bare(String code) => bareFloatingButtons(code).isNotEmpty;
      expect(bare('FloatingActionButtonThemeData(shape: s)'), isFalse);
      expect(
        bare('floatingActionButtonTheme: FloatingActionButtonThemeData()'),
        isFalse,
      );
      expect(
        bare(
          'floatingActionButtonLocation: FloatingActionButtonLocation.endFloat',
        ),
        isFalse,
      );
      expect(bare('f(FloatingActionButtonAnimator.scaling)'), isFalse);
      expect(bare('m.FloatingActionButtonLocation.centerDocked'), isFalse);
      // The constructor and its tear-offs still count.
      expect(bare('FloatingActionButton(onPressed: f)'), isTrue);
      expect(bare('FloatingActionButton.extended(onPressed: f)'), isTrue);
      expect(bare('f(FloatingActionButton.new)'), isTrue);
    });

    test('a ternary or a const does not change what the scan reads', () {
      bool bare(String code) => bareFloatingButtons(code).isNotEmpty;
      expect(
        bare(
          'MiniFabFocusRing(child: FloatingActionButton(heroTag: c ? mini : true, mini: compact))',
        ),
        isTrue,
      );
      expect(
        bare(
          'FocusRing.outside(radius: 28, child: FloatingActionButton(heroTag: c ? mini : other))',
        ),
        isFalse,
      );
      expect(
        bare(
          'FocusRing.outside(radius: 28, child: const FloatingActionButton(onPressed: f))',
        ),
        isFalse,
      );
      expect(
        bare(
          'MiniFabFocusRing(child: const FloatingActionButton(mini: true, onPressed: f))',
        ),
        isFalse,
      );
      expect(
        bare(
          'MiniFabFocusRing(\n child: const m.FloatingActionButton.small(a))',
        ),
        isFalse,
      );
      expect(
        bare('Padding(child: const FloatingActionButton(onPressed: f))'),
        isTrue,
      );
    });

    test('type positions are not uses of the button', () {
      bool bare(String code) => bareFloatingButtons(code).isNotEmpty;
      expect(bare('FloatingActionButton? b;'), isFalse);
      expect(bare('if (w is FloatingActionButton) {}'), isFalse);
      expect(bare('final List<FloatingActionButton> xs = [];'), isFalse);
      expect(bare('final m.FloatingActionButton b = f();'), isFalse);
      expect(bare('Foo<FloatingActionButton>(a)'), isFalse);
      // Calls (also with type arguments) and tear-offs still are.
      expect(bare('FloatingActionButton(onPressed: f)'), isTrue);
      expect(bare('FloatingActionButton<int>(onPressed: f)'), isTrue);
      expect(bare('f(FloatingActionButton.new)'), isTrue);
      expect(bare('f(FloatingActionButton.small)'), isTrue);
      expect(bare('x = FloatingActionButton.extended(a)'), isTrue);
    });

    test('mini must be a literal, and nested mini is not the button\'s', () {
      bool bare(String code) => bareFloatingButtons(code).isNotEmpty;
      const mini = 'MiniFabFocusRing(child: ';
      const outside = 'FocusRing.outside(radius: 28, child: ';
      // Only the literals true and false can be read.
      expect(
        bare('${mini}FloatingActionButton(mini: compact, onPressed: f))'),
        isTrue,
      );
      expect(
        bare('${outside}FloatingActionButton(mini: compact, onPressed: f))'),
        isTrue,
      );
      expect(
        bare('${mini}FloatingActionButton(mini: !false, onPressed: f))'),
        isTrue,
      );
      expect(
        bare('${outside}FloatingActionButton(mini: false, onPressed: f))'),
        isFalse,
      );
      expect(bare('${mini}FloatingActionButton(mini: true))'), isFalse);
      // A nested Foo(mini: true) is not the button's: the regular button
      // inside MiniFabFocusRing is flagged.
      expect(
        bare('${mini}FloatingActionButton(child: Foo(mini: true)))'),
        isTrue,
      );
      expect(
        bare('${outside}FloatingActionButton(child: Foo(mini: true)))'),
        isFalse,
      );
      expect(bare('FloatingActionButtonThemeData(mini: compact)'), isFalse);
    });

    test('mini is read from the button\'s own arguments only', () {
      bool bare(String code) => bareFloatingButtons(code).isNotEmpty;
      const mini = 'MiniFabFocusRing(child: ';
      expect(
        bare('${mini}FloatingActionButton(mini: true, onPressed: f))'),
        isFalse,
      );
      expect(
        bare(
          '${mini}FloatingActionButton(onPressed: f, child: Icon(a), mini: true))',
        ),
        isFalse,
      );
      // `mini: true` in a nested call is not the button's.
      expect(
        bare(
          '${mini}FloatingActionButton(onPressed: () => configure(mini: true)))',
        ),
        isTrue,
      );
      expect(
        bare(
          'FocusRing.outside(radius: 28, child: FloatingActionButton(onPressed: () => configure(mini: true)))',
        ),
        isFalse,
        reason: 'not mini, so FocusRing.outside is right',
      );
      expect(
        bare(
          'FocusRing.outside(radius: 20, child: FloatingActionButton(mini: true, onPressed: () => f(mini: false)))',
        ),
        isTrue,
      );
    });

    test('a mini button belongs in MiniFabFocusRing, not FocusRing.outside', () {
      bool bare(String code) => bareFloatingButtons(code).isNotEmpty;
      const mini = 'MiniFabFocusRing(child: ';
      expect(
        bare('${mini}FloatingActionButton(mini: true, onPressed: f))'),
        isFalse,
      );
      expect(
        bare(
          '${mini}m.FloatingActionButton(\n  heroTag: null,\n  mini: true,\n))',
        ),
        isFalse,
      );
      expect(bare('${mini}FloatingActionButton.small(onPressed: f))'), isFalse);
      // The Android defect: the 20 px outside ring on a mini button.
      expect(
        bare(
          'FocusRing.outside(radius: 20, child: FloatingActionButton(mini: true))',
        ),
        isTrue,
      );
      expect(
        bare(
          'FocusRing.outside(radius: 20, child: FloatingActionButton.small(a))',
        ),
        isTrue,
      );
      // The mini wrapper on a button that is not mini.
      expect(bare('${mini}FloatingActionButton(onPressed: f))'), isTrue);
      expect(bare('${mini}FloatingActionButton.extended(a))'), isTrue);
      expect(bare('${mini}FloatingActionButton(mini: false, a))'), isTrue);
      // A wrapper that only ends in the name does not count.
      expect(
        bare('NotMiniFabFocusRing(child: FloatingActionButton(mini: true))'),
        isTrue,
      );
      expect(
        bare('MyFocusRing.outside(radius: 20, child: FloatingActionButton(a))'),
        isTrue,
      );
    });
  });

  group('inkwell guard', () {
    int hits(String source) =>
        inkWellFindingsIn(SourceFile('lib/x.dart', source)).length;

    test('a tappable ink well outside a ring is flagged', () {
      expect(hits('f() => InkWell(onTap: g, child: a);'), 1);
      expect(hits('f() => InkResponse(onTap: g, child: a);'), 1);
      expect(hits('f() => const InkWell(onTap: g, child: a);'), 1);
      expect(hits('f() => new InkWell(onTap: g, child: a);'), 1);
      expect(hits('f() => m.InkWell(onTap: g, child: a);'), 1);
      expect(hits('f() => Material(child: InkWell(onTap: g, child: a));'), 1);
      expect(
        hits(
          'f() => Column(children: [InkWell(onTap: g, child: a), '
          'InkWell(onTap: h, child: b)]);',
        ),
        2,
      );
    });

    test('the ring must enclose the call, not sit near it', () {
      // A ring above, below or beside, however close, rings nothing.
      expect(
        hits(
          'f() => Column(children: [FocusRing(child: a), '
          'InkWell(onTap: g, child: b)]);',
        ),
        1,
      );
      expect(
        hits(
          'f() { final r = FocusRing(radius: 4, child: a);\n'
          'return InkWell(onTap: g, child: r); }',
        ),
        1,
      );
      expect(hits('f() => InkWell(onTap: g, child: FocusRing(child: a));'), 1);
      // And it counts however far down the call is, and however many lines
      // the arguments take.
      expect(
        hits(
          'f() => FocusRing(\n${'  // pad\n' * 40}  child: Padding(\n'
          '    padding: p,\n    child: InkWell(\n${'      key: k,\n' * 30}'
          '      onTap: g,\n      child: a,\n    ),\n  ),\n);',
        ),
        0,
      );
    });

    test('a ring widget in its child slot encloses', () {
      for (final owner in [
        'FocusRing(radius: 4, child: ',
        'FocusRing.outside(radius: 8, child: ',
        'm.FocusRing(child: ',
        'GroupedRowInk(onTap: g, child: ',
        'MiniFabFocusRing(child: ',
        'FocusRing(radius: 4, child: Padding(child: ',
      ]) {
        expect(
          hits('f() => $owner InkWell(onTap: g, child: a));'),
          0,
          reason: owner,
        );
      }
      // An unrelated widget, or one that only ends alike, does not.
      expect(hits('f() => Padding(child: InkWell(onTap: g));'), 1);
      expect(hits('f() => NotARing(child: InkWell(onTap: g));'), 1);
      expect(hits('f() => FocusRingLike(child: InkWell(onTap: g));'), 1);
    });

    test('a nested ink well is decided by itself, not by an outer ring', () {
      expect(
        hits(
          'f() => FocusRing(ownFocus: true, child: '
          'InkWell(onTap: g, child: InkWell(onTap: g)));',
        ),
        1,
      );
    });

    test('a ring owner reached through another slot does not enclose', () {
      expect(hits('f() => FocusRing(radius: 4, other: InkWell(onTap: g));'), 1);
      expect(
        hits('f() => GroupedRow(title: t, trailing: InkWell(onTap: g));'),
        1,
      );
    });

    test('a button or a custom trigger is not a ring owner', () {
      expect(
        hits(
          'f() => AdaptivePopupMenuButton(items: i, '
          'child: InkWell(onTap: g));',
        ),
        1,
      );
      expect(
        hits('f() => TextButton(onPressed: g, child: InkWell(onTap: g));'),
        1,
      );
    });

    test('ownership does not cross a callback or a route builder', () {
      expect(
        hits(
          'f() => TextButton(onPressed: () => showDialog(builder: (_) => '
          'InkWell(onTap: g)));',
        ),
        1,
      );
      expect(
        hits(
          'f() => FocusRing(child: Builder(builder: (c) { '
          'return InkWell(onTap: g); }));',
        ),
        1,
      );
      expect(
        hits(
          'f() => FocusRing(child: Builder(builder: (c) => '
          'FocusRing(child: InkWell(onTap: g))));',
        ),
        0,
      );
    });

    test('every handler that makes an ink well focusable is read', () {
      for (final h in [
        'onTap',
        'onDoubleTap',
        'onLongPress',
        'onLongPressUp',
        'onTapUp',
        'onTapDown',
        'onSecondaryTap',
        'onSecondaryTapUp',
        'onSecondaryTapDown',
      ]) {
        expect(hits('f() => InkWell($h: g, child: a);'), 1, reason: h);
        expect(hits('f() => InkResponse($h: g, child: a);'), 1, reason: h);
        expect(hits('f() => InkWell($h: null, child: a);'), 0, reason: h);
        expect(
          hits('f() => FocusRing(child: InkWell($h: g, child: a));'),
          0,
          reason: h,
        );
      }
      // onTapCancel alone does not enable an ink well.
      expect(hits('f() => InkWell(onTapCancel: g, child: a);'), 0);
    });

    test('only a handler makes an ink well focusable here', () {
      expect(hits('f() => InkWell(child: a);'), 0);
      expect(hits('f() => InkWell(onTap: null, child: a);'), 0);
      expect(hits('f() => InkWell(onTap: cond ? g : null, child: a);'), 1);
      expect(hits('f() => InkWell(onTap: () {}, child: a);'), 1);
    });

    test('comments and strings are not code', () {
      expect(hits('// InkWell(onTap: g)\nf() => 1;'), 0);
      expect(hits("f() => 'InkWell(onTap: g, child: a)';"), 0);
      expect(hits('/* InkResponse(onTap: g) */ f() => 1;'), 0);
    });

    test('the finding names the line and the class it sits in', () {
      final found = inkWellFindingsIn(
        SourceFile(
          'lib/y.dart',
          'class A {\n  Widget w() => InkWell(\n    onTap: g,\n  );\n}\n'
              'Widget top() => InkWell(onTap: g);\n',
        ),
      );
      expect(found.map((f) => f.hit.line), [2, 6]);
      expect(found.map((f) => f.owner), ['lib/y.dart#A', 'lib/y.dart#']);
    });

    test('an allowlist entry still matches a call, so the list shrinks', () {
      final owners = {for (final f in _allInkFindings()) f.owner};
      for (final entry in _inkWellRingOwnedElsewhere.keys) {
        expect(
          owners,
          contains(entry),
          reason: '$entry no longer has an unringed ink well: remove it',
        );
      }
    });

    test('the analyzer API canary: the parser still produces what the scan '
        'reads', () {
      final unit = parseString(
        content:
            'f() { InkWell(onTap: g); const InkWell(onTap: g); '
            'm.InkResponse(onTap: null); FocusRing.outside(radius: 1, '
            'child: x); }',
        featureSet: FeatureSet.latestLanguageVersion(),
      ).unit;
      final calls = <AstNode>[];
      unit.accept(_InkCalls(calls));
      expect(calls, hasLength(3), reason: 'the ink calls it finds');
      expect(
        calls.where(_hasTapHandler),
        hasLength(2),
        reason: 'a NamedArgument onTap that is not a NullLiteral',
      );
      final outside = _AllCalls.of(
        unit,
      ).firstWhere((n) => _inkCallShapes(n).any((s) => s.named == 'outside'));
      expect(
        _inkCallShapes(outside).any((s) => s.type == 'FocusRing'),
        isTrue,
        reason: 'a named constructor reads as its type with a name',
      );
    });
  });

  group('gesture detector guard', () {
    int hits(String source) =>
        gestureDetectorFindingsIn(SourceFile('lib/x.dart', source)).length;

    test('a tappable detector with no focusable owner is flagged', () {
      expect(hits('f() => GestureDetector(onTap: g, child: a);'), 1);
      expect(hits('f() => const GestureDetector(onTap: g, child: a);'), 1);
      expect(hits('f() => new GestureDetector(onTap: g, child: a);'), 1);
      expect(hits('f() => m.GestureDetector(onTap: g, child: a);'), 1);
      expect(
        hits('f() => Padding(child: GestureDetector(onTap: g, child: a));'),
        1,
      );
      expect(
        hits(
          'f() => Column(children: [GestureDetector(onTap: g), '
          'GestureDetector(onLongPress: h)]);',
        ),
        2,
      );
    });

    test('every tap-like handler is read, a literal null is not', () {
      for (final h in [
        'onTap',
        'onTapUp',
        'onTapDown',
        'onDoubleTap',
        'onLongPress',
        'onLongPressStart',
        'onLongPressUp',
        'onSecondaryTap',
        'onSecondaryTapUp',
        'onSecondaryTapDown',
      ]) {
        expect(hits('f() => GestureDetector($h: g, child: a);'), 1, reason: h);
        expect(
          hits('f() => GestureDetector($h: null, child: a);'),
          0,
          reason: h,
        );
        expect(
          hits(
            'f() => FocusableTap(onActivate: g, child: GestureDetector($h: g));',
          ),
          0,
          reason: h,
        );
      }
      expect(hits('f() => GestureDetector(onTap: c ? g : null);'), 1);
    });

    test('drag, scale, pan and cancel handlers are not tap targets', () {
      for (final h in [
        'onPanStart',
        'onPanUpdate',
        'onHorizontalDragUpdate',
        'onVerticalDragEnd',
        'onScaleUpdate',
        'onTapCancel',
        'onDoubleTapDown',
        'onLongPressEnd',
        'onForcePressStart',
      ]) {
        expect(hits('f() => GestureDetector($h: g, child: a);'), 0, reason: h);
      }
      expect(hits('f() => GestureDetector(child: a);'), 0);
      // A drag beside a tap is still a tap target.
      expect(hits('f() => GestureDetector(onPanStart: g, onTap: h);'), 1);
    });

    test(
      'an owner in its child slot, or the detector\'s child chain, covers',
      () {
        for (final source in [
          'f() => FocusableTap(onActivate: g, child: @@);',
          'f() => m.FocusableTap(onActivate: g, child: @@);',
          'f() => FocusRing(child: FocusableTap(onActivate: g, child: @@));',
          'f() => Padding(child: FocusableTap(onActivate: g, child: Padding(child: @@)));',
        ]) {
          expect(
            hits(
              source.replaceFirst('@@', 'GestureDetector(onTap: g, child: a)'),
            ),
            0,
            reason: source,
          );
        }
        expect(
          hits(
            'f() => GestureDetector(onTap: g, child: Padding(child: '
            'FocusableTap(onActivate: g, child: a)));',
          ),
          0,
        );
        expect(
          hits(
            'f() => GestureDetector(onTap: g, child: '
            'FocusableTap(onActivate: g, child: a));',
          ),
          0,
        );
      },
    );

    test('an owner that only sits near, or ends alike, does not cover', () {
      expect(hits('f() => Padding(child: GestureDetector(onTap: g));'), 1);
      expect(
        hits(
          'f() => Column(children: [FocusableTap(child: a), '
          'GestureDetector(onTap: g)]);',
        ),
        1,
      );
      expect(hits('f() => FocusableTap(other: GestureDetector(onTap: g));'), 1);
      expect(hits('f() => NotFocus(child: GestureDetector(onTap: g));'), 1);
      // Focus is a tab stop with no Enter or Space, and a bare
      // FocusableActionDetector carries no actions: neither is an owner.
      expect(hits('f() => Focus(child: GestureDetector(onTap: g));'), 1);
      expect(
        hits(
          'f() => Focus(canRequestFocus: false, child: GestureDetector(onTap: g));',
        ),
        1,
      );
      expect(
        hits(
          'f() => FocusableActionDetector(child: GestureDetector(onTap: g));',
        ),
        1,
      );
      expect(
        hits(
          'f() => FocusableActionDetector(enabled: false, child: '
          'GestureDetector(onTap: g));',
        ),
        1,
      );
      expect(
        hits('f() => GestureDetector(onTap: g, child: Focus(child: a));'),
        1,
      );
      expect(
        hits('f() => GestureDetector(onTap: g, child: FocusableTapLike());'),
        1,
      );
      // An owner beside the detector's child, not in its child chain.
      expect(
        hits('f() => GestureDetector(onTap: g, child: a, other: Focus());'),
        1,
      );
      expect(
        hits('f() => FocusRing(child: GestureDetector(onTap: g, child: a));'),
        1,
      );
    });

    test('ownership does not cross a callback or a route builder', () {
      expect(
        hits(
          'f() => FocusableTap(onActivate: g, child: Builder(builder: (c) { '
          'return GestureDetector(onTap: g); }));',
        ),
        1,
      );
      expect(
        hits(
          'f() => FocusableTap(onActivate: g, child: Builder(builder: (c) => '
          'GestureDetector(onTap: g)));',
        ),
        1,
      );
      expect(
        hits(
          'f() => FocusableTap(onActivate: g, child: Builder(builder: (c) => '
          'FocusableTap(onActivate: g, child: GestureDetector(onTap: g))));',
        ),
        0,
      );
    });

    test('a nested detector is decided by itself, not by an outer owner', () {
      expect(
        hits(
          'f() => FocusableTap(onActivate: g, child: GestureDetector(onTap: g, '
          'child: Padding(child: GestureDetector(onTap: h))));',
        ),
        1,
      );
    });

    test('comments and strings are not code', () {
      expect(hits('// GestureDetector(onTap: g)\nf() => 1;'), 0);
      expect(hits("f() => 'GestureDetector(onTap: g)';"), 0);
    });

    test('the finding names the line and the class it sits in', () {
      final found = gestureDetectorFindingsIn(
        SourceFile(
          'lib/y.dart',
          'class A {\n  Widget w() => GestureDetector(\n    onTap: g,\n  );\n}\n'
              'Widget top() => GestureDetector(onTap: g);\n',
        ),
      );
      expect(found.map((f) => f.hit.line), [2, 6]);
      expect(found.map((f) => f.owner), ['lib/y.dart#A', 'lib/y.dart#']);
    });

    test('an allowlist entry still matches a call, so the list shrinks', () {
      final owners = {for (final f in _allGestureFindings()) f.owner};
      for (final entry in _gestureDetectorKeyboardElsewhere.keys) {
        expect(
          owners,
          contains(entry),
          reason: '$entry no longer has an unowned detector: remove it',
        );
      }
    });

    test('every allowlist reason names one of the two accepted kinds', () {
      for (final e in _gestureDetectorKeyboardElsewhere.entries) {
        expect(
          e.value.startsWith('over a focusable control: ') ||
              e.value.startsWith('beside a focusable control: '),
          isTrue,
          reason: '${e.key}: ${e.value}',
        );
      }
    });
  });

  group('label helper scan', () {
    List<String> owners(String source) => [
      for (final f in labelHelpersIn(SourceFile('lib/src/y.dart', source)))
        f.owner,
    ];

    test('a helper without AppLocalizations that returns a literal hits', () {
      expect(
        owners("String statusLabel(Status s) => s.isOk ? 'Done' : 'Open';"),
        ['lib/src/y.dart#statusLabel'],
      );
      expect(owners("String pageTitle() { return 'Settings'; }"), [
        'lib/src/y.dart#pageTitle',
      ]);
      expect(
        owners(
          "String runSummary(int n) => switch (n) { 0 => 'None', _ => '\$n runs' };",
        ),
        ['lib/src/y.dart#runSummary'],
      );
      expect(
        owners(
          "String effortLabel(E e) { switch (e) { case E.a: return 'Low'; "
          "case E.b: return 'High'; } }",
        ),
        ['lib/src/y.dart#effortLabel'],
      );
      expect(
        owners("class K { static String tagLabel(int x) => 'Tag \$x'; }"),
        ['lib/src/y.dart#K.tagLabel'],
      );
    });

    test('a literal inside an interpolated expression hits', () {
      expect(
        owners(
          "String statusLabel(bool done) => '\${done ? 'Done' : 'Open'}';",
        ),
        ['lib/src/y.dart#statusLabel'],
      );
      expect(
        owners(
          "String runSummary(int n) { return 'x\${n == 1 ? 'run' : 'runs'}'; }",
        ),
        ['lib/src/y.dart#runSummary'],
      );
      // The exclusions hold inside the braces too: an argument and a
      // compared value are not shown.
      expect(
        owners("String nameLabel(Item i) => '\${i.pick('Done')}';"),
        isEmpty,
      );
      expect(
        owners("String nameLabel(Item i) => '\${i.s == 'done' ? 1 : 2}';"),
        isEmpty,
      );
    });

    test('a helper that returns a Future of text hits', () {
      expect(
        owners("Future<String> pageTitle() async { return 'Settings'; }"),
        ['lib/src/y.dart#pageTitle'],
      );
      expect(owners("Future<String?> pageTitle() async => 'Settings';"), [
        'lib/src/y.dart#pageTitle',
      ]);
      expect(
        owners("Future<String> pageTitle(AppLocalizations l) async => 'a';"),
        isEmpty,
      );
      expect(
        owners("Future<int> pageTitle() async => 'Settings'.length;"),
        isEmpty,
      );
    });

    test('a helper that returns a FutureOr of text hits', () {
      expect(owners("FutureOr<String> pageTitle() => 'Settings';"), [
        'lib/src/y.dart#pageTitle',
      ]);
      expect(owners("FutureOr<String?> pageTitle() { return 'Settings'; }"), [
        'lib/src/y.dart#pageTitle',
      ]);
      expect(
        owners("FutureOr<String> pageTitle(AppLocalizations l) => 'a';"),
        isEmpty,
      );
      expect(
        owners("FutureOr<int> pageTitle() => 'Settings'.length;"),
        isEmpty,
      );
    });

    test('a helper that returns a Stream of text hits', () {
      expect(
        owners("Stream<String> pageTitle() async* { yield 'Settings'; }"),
        ['lib/src/y.dart#pageTitle'],
      );
      expect(
        owners("Stream<String?> pageTitle() async* { yield 'Settings'; }"),
        ['lib/src/y.dart#pageTitle'],
      );
      expect(
        owners(
          "Stream<String> pageTitle(BuildContext c) async* { yield 'a'; }",
        ),
        isEmpty,
      );
      expect(
        owners("Stream<int> pageTitle() async* { yield 'Settings'.length; }"),
        isEmpty,
      );
      expect(
        owners("Stream<String> pageTitle() async* { yield id; }"),
        isEmpty,
      );
    });

    test('a private helper is flagged too', () {
      expect(owners("String _modeLabel(M m) => 'Auto';"), [
        'lib/src/y.dart#_modeLabel',
      ]);
    });

    test('a helper that takes AppLocalizations or BuildContext is fine', () {
      expect(
        owners(
          "String kanbanStatusLabel(AppLocalizations l10n, S s) => 'Done';",
        ),
        isEmpty,
      );
      expect(
        owners("String effortLabel(AppLocalizations l10n, E e) => 'Low';"),
        isEmpty,
      );
      expect(
        owners("String pageTitle(BuildContext context) => 'Settings';"),
        isEmpty,
      );
      expect(
        owners(
          "String pageTitle(int n, {required AppLocalizations t}) => 'a';",
        ),
        isEmpty,
      );
    });

    test('returning only a variable, a call or a lookup is fine', () {
      expect(owners('String nameLabel(Item i) => i.name;'), isEmpty);
      expect(owners('String nameLabel(Item i) { return i.name; }'), isEmpty);
      expect(
        owners("String nameLabel(Item i) => names['a'] ?? i.id;"),
        isEmpty,
      );
      expect(
        owners("String nameLabel(Item i) => i.id.replaceAll('-', ' ');"),
        isEmpty,
      );
      expect(owners("String nameLabel(Item i) => '';"), isEmpty);
      expect(owners("String nameLabel(Item i) => '\${i.n}';"), isEmpty);
      expect(owners("String nameLabel(Item i) => '12:30';"), isEmpty);
    });

    test('an allowlist entry still matches a helper, so the list shrinks', () {
      final owners = {for (final f in _allLabelHelpers()) f.owner};
      for (final entry in _labelHelperNotVisibleText.keys) {
        expect(
          owners,
          contains(entry),
          reason: '$entry no longer is a label helper: remove it',
        );
      }
    });

    test('static methods of an enum, a mixin and an extension hit', () {
      expect(owners("enum E { a; static String modeLabel(E e) => 'Auto'; }"), [
        'lib/src/y.dart#E.modeLabel',
      ]);
      expect(owners("mixin M { static String pageTitle() => 'Home'; }"), [
        'lib/src/y.dart#M.pageTitle',
      ]);
      expect(
        owners("extension X on int { static String runSummary() => 'Runs'; }"),
        ['lib/src/y.dart#X.runSummary'],
      );
      expect(
        owners(
          "extension type T(int v) { static String tagLabel() => 'Tag'; }",
        ),
        ['lib/src/y.dart#T.tagLabel'],
      );
    });

    test('helpers named exactly label, title or summary hit', () {
      expect(owners("String label(S s) => 'Done';"), ['lib/src/y.dart#label']);
      expect(owners("String title() => 'Home';"), ['lib/src/y.dart#title']);
      expect(owners("class K { static String summary() => 'Runs'; }"), [
        'lib/src/y.dart#K.summary',
      ]);
    });

    test('a helper with no declared return type hits when it returns text', () {
      expect(owners("statusLabel(S s) => 'Done';"), [
        'lib/src/y.dart#statusLabel',
      ]);
      expect(owners("pageTitle() { return 'Home'; }"), [
        'lib/src/y.dart#pageTitle',
      ]);
      expect(owners('statusLabel(S s) => s.id;'), isEmpty);
    });

    test('a literal that is compared, matched or thrown is not shown text', () {
      expect(
        owners("String statusLabel(S s) => s.id == 'done' ? s.a : s.b;"),
        isEmpty,
      );
      expect(
        owners("String statusLabel(S s) => s.id != 'done' ? s.a : s.b;"),
        isEmpty,
      );
      expect(
        owners(
          "String statusLabel(S s) => switch (s.id) { 'a' => s.a, _ => s.b };",
        ),
        isEmpty,
      );
      expect(
        owners("String statusLabel(S s) => s.a ?? (throw StateError('no'));"),
        isEmpty,
      );
      // The value of an arm, a fallback and a ternary branch still count.
      expect(
        owners(
          "String statusLabel(S s) => switch (s.id) { 'a' => 'Done', _ => s.b };",
        ),
        ['lib/src/y.dart#statusLabel'],
      );
      expect(owners("String statusLabel(S s) => s.a ?? 'None';"), [
        'lib/src/y.dart#statusLabel',
      ]);
    });

    test('a multiplication or division sign is not a letter', () {
      expect(owners("String sizeLabel(S s) => '×';"), isEmpty);
      expect(owners("String sizeLabel(S s) => '÷ 2';"), isEmpty);
      expect(owners("String sizeLabel(S s) => '3 × 4';"), isEmpty);
      expect(owners("String sizeLabel(S s) => 'ä';"), [
        'lib/src/y.dart#sizeLabel',
      ]);
    });

    test('other names, return types, getters and instance methods pass', () {
      expect(owners("String statusName(S s) => 'Done';"), isEmpty);
      expect(owners("int countLabel(S s) => 3;"), isEmpty);
      expect(owners("String get pageTitle => 'Settings';"), isEmpty);
      expect(owners("class K { String tagLabel(int x) => 'Tag'; }"), isEmpty);
      expect(
        owners("String f(S s) { String inner() => 'Done'; return s.id; }"),
        isEmpty,
      );
      expect(
        owners(
          "String statusLabel(S s) { final f = () => 'Done'; return s.id; }",
        ),
        isEmpty,
      );
      expect(owners("// String statusLabel(S s) => 'Done';"), isEmpty);
    });
  });

  group('english default label scan', () {
    List<String> names(String source) => [
      for (final f in englishDefaultsIn(SourceFile('lib/y.dart', source)))
        f.owner,
    ];

    test(
      'a named parameter, an optional positional and a field formal hit',
      () {
        expect(names("void f({String cancel = 'Cancel'}) {}"), [
          'lib/y.dart#cancel',
        ]);
        expect(names("void f([String x = 'Ok']) {}"), ['lib/y.dart#x']);
        expect(
          names("class A { A({this.label = 'Install'}); final String label; }"),
          ['lib/y.dart#label'],
        );
        expect(names("class B extends A { B({super.hint = 'Search'}); }"), [
          'lib/y.dart#hint',
        ]);
        expect(names("void f({String? text = 'Someone took over.'}) {}"), [
          'lib/y.dart#text',
        ]);
        expect(names("void f({String t = 'Try again'}) {}"), ['lib/y.dart#t']);
      },
    );

    test('ids, an empty string, interpolation, constants and comments pass', () {
      expect(
        names(
          "void f({String a = 'menu', String b = 'png', String c = '/api/ws', "
          "String d = 'session-lock', String e = 'default', String g = '', "
          "String h = '\$x', String i = 'a-\$x', String j = kFoo, "
          "int k = 3, String? l}) {}",
        ),
        isEmpty,
      );
      expect(
        names("// void f({String a = 'Cancel'}) {}\nvoid g({String b}) {}"),
        isEmpty,
      );
      expect(
        names("final x = 'Cancel'; void f() { var y = 'Hello there'; }"),
        isEmpty,
      );
    });

    test('adjacent literals read as one; interpolated ones do not hit', () {
      expect(names("void f({String a = 'Someone else ' 'took control.'}) {}"), [
        'lib/y.dart#a',
      ]);
      expect(names("void f({String a = 'Someone ' '\$x'}) {}"), isEmpty);
    });

    test('the letter guard: no letter, no label', () {
      expect(looksLikeEnglishLabel(' \u00b7 '), isFalse);
      expect(looksLikeEnglishLabel('...'), isFalse);
    });

    test('the word heuristic', () {
      expect(looksLikeEnglishLabel('Cancel'), isTrue);
      expect(looksLikeEnglishLabel('try again'), isTrue);
      expect(looksLikeEnglishLabel('done.'), isTrue);
      expect(looksLikeEnglishLabel('menu'), isFalse);
      expect(looksLikeEnglishLabel('1234'), isFalse);
      expect(looksLikeEnglishLabel('A'), isTrue);
      expect(looksLikeEnglishLabel(''), isFalse);
    });

    test('an allowlist entry still matches a default, so the list shrinks', () {
      final owners = {for (final f in _allEnglishDefaults()) f.owner};
      for (final entry in _englishDefaultNotVisibleText.keys) {
        expect(
          owners,
          contains(entry),
          reason: '$entry no longer has an English default: remove it',
        );
      }
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

    test('a menu command chord outside menu_layout.dart is flagged', () {
      int chords(String source) =>
          menuChordHitsIn(SourceFile('lib/src/x.dart', source)).length;
      expect(
        chords('x = SingleActivator(LogicalKeyboardKey.keyN, control: true);'),
        1,
      );
      expect(chords('x = SingleActivator(LogicalKeyboardKey.f5);'), 1);
      expect(chords('x = ctrlActivator(LogicalKeyboardKey.keyB);'), 1);
      // A Mac chord, and keys no menu command uses, are not.
      expect(
        chords('x = SingleActivator(LogicalKeyboardKey.keyN, meta: true);'),
        0,
      );
      expect(chords('x = SingleActivator(LogicalKeyboardKey.escape);'), 0);
      // Alt with Left, Right or Up; a plain arrow, or Alt+Down, is not.
      for (final key in ['arrowLeft', 'arrowRight', 'arrowUp']) {
        expect(
          chords('x = SingleActivator(LogicalKeyboardKey.$key, alt: true);'),
          1,
          reason: key,
        );
        expect(chords('x = SingleActivator(LogicalKeyboardKey.$key);'), 0);
      }
      expect(
        chords('x = SingleActivator(LogicalKeyboardKey.arrowDown, alt: true);'),
        0,
      );
      expect(
        chords(
          'x = SingleActivator(LogicalKeyboardKey.arrowUp, alt: true, meta: true);',
        ),
        0,
      );
      expect(
        chords('x = SingleActivator(LogicalKeyboardKey.keyV, control: true);'),
        0,
      );
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
