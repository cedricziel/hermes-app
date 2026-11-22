import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:hermes_app/src/app.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'architecture/source_scan.dart';
import 'support/fake_device_authenticator.dart';
import 'support/screenshot_recorder.dart';
import 'support/workflow_app.dart';

/// Inherited widgets the app's chrome adds that say nothing about how a child
/// draws: focus scopes, the ticker mode of a hidden route, the desktop
/// navigation history and the menu bar's registry.
const _notTheme = {
  '_FocusInheritedScope',
  '_EffectiveTickerMode',
  'DesktopNavigationHistoryScope',
  '_RegistryScope',
};

/// `HermesApp` and the workflow tests' `pumpScreen` must draw third-party
/// widgets with the same theme. `gpt_markdown` reads `material_ui`'s theme from
/// [AppThemeScopes]; without it a dark screenshot shows near-black headings
/// the app never draws.
void main() {
  Color headingColor(WidgetTester tester) {
    final span = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(GptMarkdown),
            matching: find.byType(RichText),
          ),
        )
        .map((r) => r.text)
        .first;
    Color? found;
    span.visitChildren((s) {
      if (s is TextSpan && s.style?.color != null) found ??= s.style!.color;
      return found == null;
    });
    return found ?? (span.style?.color ?? Colors.transparent);
  }

  /// What a widget below `home` inherits that could change how it draws:
  /// every [InheritedTheme] and every [InheritedWidget] that is not on the
  /// allowlist, from the app's `Navigator` (what the builder wraps; the routes differ)
  /// up to the root. Providers and [MediaQuery] are
  /// data an app or a test supplies by itself, so they are left out;
  /// everything else has to be the same in `HermesApp` and `pumpScreen`.
  List<String> inheritedAbove(WidgetTester tester, Finder home) {
    final types = <String>[];
    tester.element(home).visitAncestorElements((e) {
      final w = e.widget;
      final name = w.runtimeType.toString();
      final ignored =
          w is MediaQuery ||
          name.startsWith('_InheritedProviderScope') ||
          _notTheme.contains(name);
      if (!ignored && (w is InheritedTheme || w is InheritedWidget)) {
        types.add(name);
      }
      return true;
    });
    return types;
  }

  Future<void> pumpHermesApp(WidgetTester tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final appLock = AppLockController(authenticator: FakeDeviceAuthenticator());
    addTearDown(appLock.dispose);
    await tester.runAsync(appLock.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()..bootstrap()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider.value(value: appLock),
        ],
        child: const HermesApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('HermesApp mounts AppThemeScopes above its home', (tester) async {
    await pumpHermesApp(tester);

    expect(
      find.ancestor(
        of: find.text('Connect to Hermes'),
        matching: find.byType(AppThemeScopes),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pumpScreen mounts AppThemeScopes above its home', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      ScreenshotRecorder('theme-scopes'),
      const Scaffold(body: Text('home')),
    );

    expect(
      find.ancestor(
        of: find.text('home'),
        matching: find.byType(AppThemeScopes),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'a dark pumpScreen draws markdown headings readable on the surface',
    (tester) async {
      await pumpScreen(
        tester,
        ScreenshotRecorder('theme-scopes'),
        const Scaffold(body: GptMarkdown('# Heading')),
        brightness: Brightness.dark,
      );

      final surface = Theme.of(tester.element(find.byType(GptMarkdown)))
          .colorScheme
          .surface;
      final color = headingColor(tester);
      // The light fallback is near black; the app draws a light heading.
      expect(color.computeLuminance(), greaterThan(surface.computeLuminance()));
      expect(
        (color.computeLuminance() + 0.05) / (surface.computeLuminance() + 0.05),
        greaterThan(7),
      );
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'pumpScreen (${brightness.name}) inherits the same theme widgets as HermesApp',
      (tester) async {
        await pumpHermesApp(tester);
        final app = inheritedAbove(tester, find.byType(Navigator).first);

        await pumpScreen(
          tester,
          ScreenshotRecorder('theme-scopes'),
          const Scaffold(body: Text('home')),
          brightness: brightness,
        );
        final harness = inheritedAbove(tester, find.byType(Navigator).first);

        expect(app, isNotEmpty);
        expect(harness, app);
      },
    );
  }

  test('every source file that builds an app mounts AppThemeScopes', () {
    // The conversation window and the quick panel are engines of their own
    // that `runApp` a MaterialApp, which no test can start without native
    // channels, so this reads the source: a file may not build more apps than
    // it mounts scopes. `code` blanks comments and string contents.
    final scopes = RegExp(r'\bAppThemeScopes\(');
    final short = <String>[];
    for (final f in dartFiles('lib')) {
      if (_appConstructor.allMatches(f.code).length >
          scopes.allMatches(f.code).length) {
        short.add(f.path);
      }
    }
    expect(short, isEmpty);
  });

  test('the reader derivation still finds every seed', () {
    // A seed regex that loses an alternative would shrink the reader set and
    // let tests through without any other test noticing.
    for (final probe in [
      'mui.Theme.of(context)',
      'GptMarkdown(',
      'GptMarkdownTheme',
      'mui.Slider(',
    ]) {
      expect(_seed.hasMatch(probe), isTrue, reason: probe);
    }
    final r = _readers();
    expect(r.seedsWithoutBody, isEmpty);
    expect(r.names, isNotEmpty);
    expect(
      r.names,
      containsAll(['BoundedMarkdown', 'HermesCodeBlock', 'buildChatBuilders']),
    );
  });

  test('a hand-built test app that renders a theme-scope reader mounts '
      'AppThemeScopes', () {
    // `mui.Theme.of` does not throw without the scope, it falls back to the
    // light theme, so a dark test draws near-black headings and light code
    // blocks. Nothing fails at run time: this reads the sources.
    final readers = _readers();
    final memberPattern = readers.members.isEmpty
        ? null
        : RegExp('\\.\\s*(?:${readers.members.join('|')})\\b');
    final helpers = _testHelpers();
    final bad = <String>[];
    for (final f in dartFiles('test')) {
      if (!f.path.endsWith('_test.dart')) continue;
      final code = f.code;
      final unmounted = _apps(code).where((a) => !a.mounted).length;
      final usesPlain = helpers.plain.any((h) => h.calledIn(code));
      if (unmounted == 0 && !usesPlain) continue;
      final used = {
        for (final m in _wordsPattern(
          readers.names,
          prefixes: _importPrefixes(f),
        ).allMatches(code))
          m.group(0)!,
        if (memberPattern != null)
          for (final m in memberPattern.allMatches(code)) m.group(0)!,
      };
      if (used.isNotEmpty) {
        bad.add('${f.path}: ${(used.toList()..sort()).join(', ')}');
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          'These tests build an app (or call a helper that does) whose '
          "`builder:` or `home:` never mounts AppThemeScopes, and reference a "
          "widget that reads material_ui's theme, so it draws with the light "
          "fallback in a dark test. Mount AppThemeScopes in the app's "
          '`builder:` (`builder: (_, child) => AppThemeScopes(child: '
          'child!)`):\n${bad.join('\n')}',
    );
  });

  group('the guard on fixtures', () {
    bool mounted(String app) => _apps(app).single.mounted;

    test('a scope beside the reader in home: does not mount the app', () {
      expect(
        mounted(
          'MaterialApp(home: Scaffold(body: Column(children: ['
          'FlyerMaterialScope(child: SizedBox()), BoundedMarkdown("h")])))',
        ),
        isFalse,
      );
      expect(
        mounted('MaterialApp(home: AppThemeScopes(child: Chat()))'),
        isTrue,
      );
      expect(
        mounted(
          'MaterialApp(builder: (_, child) => AppThemeScopes(child: child!), '
          'home: Scaffold(body: BoundedMarkdown("h")))',
        ),
        isTrue,
      );
    });

    test('a mount inside a conditional does not count', () {
      expect(
        mounted(
          'MaterialApp(builder: (_, app) => '
          'true ? app! : AppThemeScopes(child: app!))',
        ),
        isFalse,
      );
      expect(
        mounted(
          'MaterialApp(builder: (_, app) => '
          'cond ? AppThemeScopes(child: app!) : app!)',
        ),
        isFalse,
      );
      expect(
        mounted(
          'MaterialApp(builder: (_, app) { final x = a ? b : c; '
          'return AppThemeScopes(child: app!); })',
        ),
        isTrue,
      );
      expect(
        mounted(
          'MaterialApp(builder: (_, app) => AppThemeScopes('
          'child: lock == null ? app! : AppLockGate(child: app!)))',
        ),
        isTrue,
      );
    });

    test('an extension on a type lib does not declare spreads its members', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/ext.dart',
          'extension MdX on BuildContext {\n'
              "  Widget get mdView => GptMarkdown('x');\n"
              '}\n',
        ),
        SourceFile(
          'lib/a/user.dart',
          'class UsesIt extends StatelessWidget {\n'
              '  Widget build(BuildContext context) => context.mdView;\n'
              '}\n',
        ),
      ]);
      expect(readers.members, contains('mdView'));
      expect(readers.names, contains('UsesIt'));
    });

    test('a private reader in a part file of another directory is found', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/app.dart',
          "part 'sub/app_part.dart';\n"
              'class Pub extends StatelessWidget {\n'
              '  Widget build(BuildContext context) => _Priv();\n'
              '}\n',
        ),
        SourceFile(
          'lib/a/sub/app_part.dart',
          "part of '../app.dart';\n"
              'class _Priv extends StatelessWidget {\n'
              "  Widget build(BuildContext context) => GptMarkdown('x');\n"
              '}\n',
        ),
        SourceFile(
          'lib/a/other.dart',
          'class _Priv {}\n'
              'class Bystander {\n'
              '  final p = _Priv();\n'
              '}\n',
        ),
      ]);
      expect(readers.names, contains('Pub'));
      expect(readers.names, isNot(contains('Bystander')));
    });

    test('an import prefix qualifies a reference, other access does not', () {
      final pattern = _wordsPattern(['BoundedMarkdown'], prefixes: {'md'});
      expect(pattern.hasMatch('md.BoundedMarkdown('), isTrue);
      expect(pattern.hasMatch('BoundedMarkdown('), isTrue);
      expect(pattern.hasMatch('x.BoundedMarkdown('), isFalse);
      final file = SourceFile(
        'test/x_test.dart',
        "import 'package:hermes_app/a.dart' as md;\n"
            "import 'package:hermes_app/b.dart' show B;\n",
      );
      expect(_importPrefixes(file), {'md'});
    });
  });
}

final _appConstructor = RegExp(
  r'(?<![\w.])(?:MaterialApp(?:\.router)?|CupertinoApp|WidgetsApp)\(',
);
final _mountCall = RegExp(
  r'\b(?:AppThemeScopes|MaterialUiThemeScope|FlyerMaterialScope)\(|'
  r'\bmui\.Theme\(',
);

/// The alternatives that make a `lib/` declaration a reader of `material_ui`'s
/// theme or of `gpt_markdown`.
const _seedAlternatives = [
  r'\bmui\.Theme\.of\b',
  r'\bGptMarkdown\(',
  r'\bGptMarkdownTheme\b',
  r'\bmui\.[A-Z]\w*\(',
];
final _seed = RegExp(_seedAlternatives.join('|'));
final _provider = RegExp(
  r'\bmui\.Theme\(|\bMaterialUiThemeScope\(|\bAppThemeScopes\(',
);

/// Roots that open a reader only after a tap: a test that pumps one of them to
/// reach a route does not draw the reader.
const _navigationOnly = {'AppShell', 'MacProfilesPage', 'HermesApp'};

/// [words] as references: bare, or qualified by one of the import
/// [prefixes] (`md.BoundedMarkdown`). Any other member access (`x.Foo`) is not
/// a reference.
RegExp _wordsPattern(
  Iterable<String> words, {
  Set<String> prefixes = const {},
}) {
  final qualifier = prefixes.isEmpty ? '' : '(?:(?:${prefixes.join('|')})\\.)?';
  return RegExp('(?<![\\w.\$])$qualifier(?:${words.join('|')})\\b');
}

/// The `as` prefixes of the imports of [file].
Set<String> _importPrefixes(SourceFile file) => {
  for (final m in RegExp(
    r'''^import\s+['"][^'"]+['"][^;]*?\bas\s+(\w+)''',
    multiLine: true,
  ).allMatches(file.text))
    m.group(1)!,
};

/// The library [file] belongs to: its `part of` target, or itself.
String _libraryOf(SourceFile file) {
  final m = RegExp(
    r'''^part\s+of\s+['"]([^'"]+)['"]''',
    multiLine: true,
  ).firstMatch(file.text);
  if (m == null) return file.path;
  return Uri(path: file.path).resolve(m.group(1)!).path;
}

/// One top-level declaration of a source file.
class _Decl {
  _Decl(this.path, this.name, this.body, this.offset, {this.on});

  final String path;
  final String name;
  String body;
  final int offset;

  /// The type an extension extends.
  final String? on;

  /// The library the declaration belongs to, so a private name is shared with
  /// the `part` files of its library and with nothing else.
  late String library = path;
}

final _chunkStart = RegExp(r'^(?=[A-Za-z_])', multiLine: true);
final _skipLine = RegExp(r'^(?:import|export|part|library|typedef)\b');
final _typeDecl = RegExp(
  r'^(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
  r'(?:class|mixin|enum)\s+(\w+)|^extension\s+type\s+(?:const\s+)?(\w+)',
);
final _extDecl = RegExp(
  r'^extension\b(?:\s+(\w+))?(?:\s*<[^>]*>)?\s+on\s+(\w+)',
);

/// Every top-level class, mixin, enum, extension, function, getter and
/// variable of [file], split where a line starts in column 0.
List<_Decl> _declarations(SourceFile file) {
  final out = <_Decl>[];
  var offset = 0;
  for (final chunk in file.code.split(_chunkStart)) {
    final at = offset;
    offset += chunk.length;
    if (chunk.isEmpty || _skipLine.hasMatch(chunk)) continue;
    final type = _typeDecl.firstMatch(chunk);
    if (type != null) {
      out.add(_Decl(file.path, type.group(1) ?? type.group(2)!, chunk, at));
      continue;
    }
    final ext = _extDecl.firstMatch(chunk);
    if (ext != null) {
      out.add(
        _Decl(
          file.path,
          ext.group(1) ?? 'extension_on_${ext.group(2)}',
          chunk,
          at,
          on: ext.group(2),
        ),
      );
      continue;
    }
    final stops = [
      for (final s in ['{', '=>', ';'])
        if (chunk.contains(s)) chunk.indexOf(s),
    ];
    final header = stops.isEmpty
        ? chunk
        : chunk.substring(0, stops.reduce((a, b) => a < b ? a : b));
    final name =
        RegExp(r'\bget\s+(\w+)').firstMatch(header)?.group(1) ??
        RegExp(r'(\w+)\s*(?:<[^>(]*>)?\s*\(').firstMatch(header)?.group(1) ??
        RegExp(r'(\w+)\s*(?:=|$)').firstMatch(header)?.group(1);
    if (name == null || name == 'Function' || name == 'main') continue;
    out.add(_Decl(file.path, name, chunk, at));
  }
  return out;
}

/// Getters and methods an extension body declares, one indent in.
Set<String> _memberNames(String body) => {
  for (final m in RegExp(r'\bget\s+(\w+)').allMatches(body)) m.group(1)!,
  for (final m in RegExp(
    r'^  (?:static\s+)?[\w<>?,.\[\] ]*?\b(\w+)\s*(?:<[^>(]*>)?\(',
    multiLine: true,
  ).allMatches(body))
    m.group(1)!,
}..removeAll({'if', 'for', 'while', 'switch', 'return', 'operator'});

final _identifier = RegExp(r'(?<![\w.$])[A-Za-z_]\w*');

/// `lib/` declarations that read `material_ui`'s theme or draw
/// `gpt_markdown`, and every declaration that mentions one of them (a class,
/// function, getter or variable name), transitively. An extension is part of
/// the type it extends. Scope providers, app roots and the navigation-only
/// roots are not readers.
({Set<String> names, Set<String> members, List<String> seedsWithoutBody})
_readers() => _readersOf(dartFiles('lib'));

({Set<String> names, Set<String> members, List<String> seedsWithoutBody})
_readersOf(List<SourceFile> files) {
  final decls = <_Decl>[];
  for (final f in files) {
    final library = _libraryOf(f);
    for (final d in _declarations(f)) {
      d.library = library;
      decls.add(d);
    }
  }
  final all = <_Decl>[];
  for (final d in decls) {
    if (d.on != null) continue;
    all.add(d);
  }
  for (final d in decls) {
    final on = d.on;
    if (on == null) continue;
    final targets = all.where(
      (t) => t.name == on && (!on.startsWith('_') || t.library == d.library),
    );
    if (targets.isEmpty) {
      all.add(d);
    } else {
      for (final t in targets) {
        t.body += d.body;
      }
    }
  }

  bool skipped(_Decl d) =>
      _provider.hasMatch(d.body) ||
      _appConstructor.hasMatch(d.body) ||
      _navigationOnly.any((n) => d.name == n || d.name == '_${n}State');

  final mentions = <String, List<_Decl>>{};
  for (final d in all) {
    final names = _identifier.allMatches(d.body).map((m) => m.group(0)!);
    for (final m in names.toSet()) {
      (mentions[m] ??= []).add(d);
    }
  }
  final reached = <_Decl>{};
  final queue = <_Decl>[];
  void reach(_Decl d) {
    if (skipped(d) || !reached.add(d)) return;
    queue.add(d);
  }

  final seedsWithoutBody = [
    for (final alt in _seedAlternatives)
      if (!all.any((d) => !skipped(d) && RegExp(alt).hasMatch(d.body))) alt,
  ];
  for (final d in all) {
    if (_seed.hasMatch(d.body)) reach(d);
  }
  final members = <String>{};
  while (queue.isNotEmpty) {
    final d = queue.removeLast();
    for (final m in mentions[d.name] ?? const <_Decl>[]) {
      if (d.name.startsWith('_') && m.library != d.library) continue;
      reach(m);
    }
    if (d.on != null) {
      // An extension on a type `lib/` does not declare (`BuildContext`) is
      // reached through its members: `context.view`.
      for (final member in _memberNames(d.body)) {
        members.add(member);
        final use = RegExp('\\.\\s*$member\\b');
        for (final other in all) {
          if (other != d && use.hasMatch(other.body)) reach(other);
        }
      }
    }
  }
  return (
    members: members,
    names: {
      for (final d in reached)
        if (!d.name.startsWith('_') && !d.name.startsWith('extension_on_'))
          d.name,
    },
    seedsWithoutBody: seedsWithoutBody,
  );
}

/// Whether the app constructor whose `(` ends just before [open] mounts a
/// scope: a call in its `builder:` argument that is not inside a `?`/`:`
/// conditional, or a `home:` argument that is the scope call itself (a scope
/// somewhere in a `home:` subtree covers only that part of it).
bool _constructorMounts(String code, int open) {
  final args = code.substring(open, callEnd(code, open) - 1);
  final builder = _namedArgument(args, 'builder');
  if (builder != null) {
    for (final m in _mountCall.allMatches(builder)) {
      if (!_inConditional(builder, m.start)) return true;
    }
  }
  final home = _namedArgument(args, 'home')?.trim();
  if (home != null) {
    final m = RegExp('^(?:const\\s+)?(?:${_mountCall.pattern})')
        .firstMatch(home);
    if (m != null && callEnd(home, m.end) == home.length) return true;
  }
  return false;
}

/// Whether the offset [at] of [expr] sits in a `cond ? a : b` that started in
/// one of the brackets still open there, since the last `;` or `,`.
bool _inConditional(String expr, int at) {
  final seen = <bool>[false];
  for (var i = 0; i < at; i++) {
    final c = expr[i];
    if ('([{'.contains(c)) {
      seen.add(false);
    } else if (')]}'.contains(c)) {
      if (seen.length > 1) seen.removeLast();
    } else if (c == ';' || c == ',') {
      seen[seen.length - 1] = false;
    } else if (c == '?' &&
        i > 0 &&
        ' \n\t'.contains(expr[i - 1]) &&
        i + 1 < expr.length &&
        !'?.'.contains(expr[i + 1])) {
      seen[seen.length - 1] = true;
    }
  }
  return seen.any((b) => b);
}

String? _namedArgument(String args, String label) {
  var depth = 0;
  var start = -1;
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      depth--;
    } else if (depth == 0 &&
        start < 0 &&
        args.startsWith('$label:', i) &&
        (i == 0 || ' \n\t,'.contains(args[i - 1]))) {
      start = i + label.length + 1;
    } else if (depth == 0 && start >= 0 && c == ',') {
      return args.substring(start, i);
    }
  }
  return start < 0 ? null : args.substring(start);
}

/// Every app built in [code], and whether it mounts the theme scopes.
/// `HermesApp` is the real app and always does.
List<({int start, bool mounted})> _apps(String code) => [
  for (final m in _appConstructor.allMatches(code))
    (start: m.start, mounted: _constructorMounts(code, m.end)),
  for (final m in RegExp(r'(?<![\w.])HermesApp\(').allMatches(code))
    (start: m.start, mounted: true),
];

class _Helper {
  _Helper(this.name, this.isType);

  final String name;
  final bool isType;

  bool calledIn(String code) =>
      RegExp(isType ? '(?<![\\w.])$name\\b' : '(?<![\\w.])$name\\(')
          .hasMatch(code);
}

/// Functions and classes of the test helper files (anything under `test/` not
/// named `*_test.dart`: `test/support` and the harnesses beside a directory)
/// that build an app, split by whether every app they build mounts the scopes,
/// directly or through another helper.
({List<_Helper> mounting, List<_Helper> plain}) _testHelpers() {
  final decls = <_Decl>[];
  for (final f in dartFiles('test')) {
    if (!f.path.endsWith('_test.dart')) decls.addAll(_declarations(f));
  }
  final mounting = <String, _Helper>{};
  final plain = <String, _Helper>{};
  for (var round = 0; round < 4; round++) {
    for (final d in decls) {
      final helper = _Helper(d.name, _typeDecl.hasMatch(d.body));
      final apps = _apps(d.body);
      bool calls(Iterable<_Helper> hs) =>
          hs.any((h) => h.name != d.name && h.calledIn(d.body));
      if (apps.isNotEmpty) {
        if (apps.every((a) => a.mounted)) {
          mounting[d.name] = helper;
          plain.remove(d.name);
        } else {
          plain[d.name] = helper;
          mounting.remove(d.name);
        }
      } else if (calls(plain.values)) {
        plain[d.name] = helper;
      } else if (calls(mounting.values)) {
        mounting[d.name] = helper;
      }
    }
  }
  return (mounting: mounting.values.toList(), plain: plain.values.toList());
}
