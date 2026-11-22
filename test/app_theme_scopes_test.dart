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
      containsAll([
        'BoundedMarkdown',
        'HermesCodeBlock',
        'buildChatBuilders',
        'ChatScreen',
        'ConversationWindowScreen',
        'BoundActivityPanel',
      ]),
    );
  });

  test('a hand-built test app that renders a theme-scope reader mounts '
      'AppThemeScopes', () {
    // `mui.Theme.of` does not throw without the scope, it falls back to the
    // light theme, so a dark test draws near-black headings and light code
    // blocks. Nothing fails at run time: this reads the sources.
    final readers = _readers();
    final helpers = _testHelpers(readers);
    final bad = <String>[];
    for (final f in dartFiles('test')) {
      if (!f.path.endsWith('_test.dart')) continue;
      final used = _unmountedReaderUses(
        readers,
        helpers,
        f,
        exemptions: _exemptions,
      );
      if (used.isNotEmpty) {
        bad.add('${f.path}: ${(used.toList()..sort()).join(', ')}');
      }
    }
    expect(bad, isEmpty, reason: _unmountedReason(bad));
  });

  test('every exemption is still an offender without it', () {
    final readers = _readers();
    final helpers = _testHelpers(readers);
    final stale = <String>[];
    for (final e in _exemptions) {
      final files = dartFiles('test').where((f) => f.path == e.path);
      final offends =
          files.isNotEmpty &&
          _apps(files.single.code)
              .any((a) => !a.mounted && a.args.contains(e.appContains)) &&
          _unmountedReaderUses(readers, helpers, files.single).isNotEmpty;
      if (!offends) stale.add('${e.path}: ${e.appContains}');
    }
    expect(
      stale,
      isEmpty,
      reason:
          'These exemptions no longer apply (the file, the app or the reader '
          'use is gone). Remove them from _exemptions:\n${stale.join('\n')}',
    );
  });

  group('the guard on fixtures', () {
    bool mounted(String app) => _apps(app).single.mounted;

    test('a scope in home: does not mount the app', () {
      expect(
        mounted(
          'MaterialApp(home: Scaffold(body: Column(children: ['
          'FlyerMaterialScope(child: SizedBox()), BoundedMarkdown("h")])))',
        ),
        isFalse,
      );
      expect(
        mounted('MaterialApp(home: AppThemeScopes(child: Chat()))'),
        isFalse,
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
          "import 'ext.dart';\n"
              'class UsesIt extends StatelessWidget {\n'
              '  Widget build(BuildContext context) => context.mdView;\n'
              '}\n',
        ),
        SourceFile(
          'lib/b/unrelated.dart',
          'class Unrelated extends StatelessWidget {\n'
              '  Widget build(BuildContext context) => x.mdView;\n'
              '}\n',
        ),
        SourceFile(
          'lib/b/package_user.dart',
          "import 'package:hermes_app/a/ext.dart';\n"
              'class ViaPackage {\n'
              '  Object build(BuildContext context) => context.mdView;\n'
              '}\n',
        ),
      ]);
      expect(readers.members, contains('mdView'));
      expect(readers.names, containsAll(['UsesIt', 'ViaPackage']));
      expect(readers.names, isNot(contains('Unrelated')));
    });

    test('a test sees an extension member only through an import', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/probe.dart',
          'extension ProbeTheme on BuildContext {\n'
              '  Color get surface => mui.Theme.of(this).surface;\n'
              '}\n',
        ),
      ]);
      final importing = SourceFile(
        'test/a_test.dart',
        "import 'package:hermes_app/a/probe.dart';\n",
      );
      final other = SourceFile('test/b_test.dart', '');
      expect(_memberUses(readers, importing, 'x.surface'), ['.surface']);
      expect(_memberUses(readers, other, 'x.surface'), isEmpty);
    });

    test('an extension does not make its receiver a reader', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/model.dart',
          'class Model {}\n'
              'extension ModelX on Model {\n'
              "  Widget get view => GptMarkdown('x');\n"
              '}\n'
              'class Holder {\n'
              '  Widget draw() => view;\n'
              '}\n'
              'extension HolderX on Holder {\n'
              "  Widget get view => GptMarkdown('y');\n"
              '}\n',
        ),
        SourceFile(
          'lib/a/plain_user.dart',
          "import 'model.dart';\n"
              'class PlainUser {\n'
              '  Object build() => Model();\n'
              '}\n',
        ),
        SourceFile(
          'lib/a/view_user.dart',
          "import 'model.dart';\n"
              'class ViewUser {\n'
              '  Object build(Model m) => m.view;\n'
              '}\n',
        ),
      ]);
      expect(readers.names, isNot(contains('Model')));
      expect(readers.names, isNot(contains('PlainUser')));
      expect(readers.names, contains('ViewUser'));
      // A bare use of the member inside the extended type's own body.
      expect(readers.names, contains('Holder'));
    });

    test('a finder-only mention is not a reader use', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/md.dart',
          'class BoundedMarkdown extends StatelessWidget {\n'
              "  Widget build(BuildContext context) => GptMarkdown('x');\n"
              '}\n',
        ),
      ]);
      Set<String> uses(String body) =>
          _readerUses(readers, SourceFile('test/a_test.dart', body));
      expect(
        uses('expect(find.byType(BoundedMarkdown), findsNothing);'),
        isEmpty,
      );
      expect(
        uses(
          'expect(find.byWidgetPredicate((w) => w is BoundedMarkdown), '
          'findsNothing);',
        ),
        isEmpty,
      );
      expect(
        uses(
          "pump(BoundedMarkdown('x'));\n"
          'expect(find.byType(BoundedMarkdown), findsOneWidget);',
        ),
        {'BoundedMarkdown'},
      );
    });

    test('the failure message names builder: alone', () {
      final reason = _unmountedReason(['test/a_test.dart: X']);
      expect(reason, contains('`builder:`'));
      expect(reason, isNot(contains('home:')));
      expect(reason, contains('test/a_test.dart: X'));
    });

    test('a helper that builds a scoped app and calls an unscoped one is plain', () {
      final helpers = _helpersOf([
        SourceFile(
          'test/support/h.dart',
          'Future<void> mixed(bool direct) async {\n'
              '  if (direct) {\n'
              '    MaterialApp(builder: (_, c) => AppThemeScopes(child: c!));\n'
              '  } else {\n'
              '    await unscoped();\n'
              '  }\n'
              '}\n'
              'Future<void> unscoped() async {\n'
              '  MaterialApp(home: Text("x"));\n'
              '}\n',
        ),
      ]);
      expect(
        helpers.plain.map((h) => h.name),
        containsAll(['mixed', 'unscoped']),
      );
      expect(helpers.mounting, isEmpty);
    });

    test('a long chain of helpers declared caller-first ends plain', () {
      final helpers = _helpersOf([
        SourceFile(
          'test/support/chain.dart',
          'void h1() => h2();\n'
              'void h2() => h3();\n'
              'void h3() => h4();\n'
              'void h4() => h5();\n'
              'void h5() => h6();\n'
              'void h6() => h7();\n'
              'void h7() => MaterialApp(home: Text("x"));\n',
        ),
      ]);
      expect(helpers.plain.map((h) => h.name).toSet(), {
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'h7',
      });
    });

    test('a chain of extensions on one type reaches the type', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/chain.dart',
          "part 'chain_a.dart';\n"
              "part 'chain_b.dart';\n"
              'class ProbeChain extends StatefulWidget {\n'
              '  State createState() => _ProbeChainState();\n'
              '}\n'
              'class _ProbeChainState {\n'
              '  Widget build(c) => _outer(c);\n'
              '}\n',
        ),
        SourceFile(
          'lib/a/chain_a.dart',
          "part of 'chain.dart';\n"
              'extension _A on _ProbeChainState {\n'
              '  Widget _outer(c) => _inner(c);\n'
              '}\n',
        ),
        SourceFile(
          'lib/a/chain_b.dart',
          "part of 'chain.dart';\n"
              'extension _B on _ProbeChainState {\n'
              '  Widget _inner(c) => Text("x", style: mui.Theme.of(c).text);\n'
              '}\n',
        ),
      ]);
      expect(readers.names, contains('ProbeChain'));
    });

    test('an exemption lets exactly its app through', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/md.dart',
          'class BoundedMarkdown extends StatelessWidget {\n'
              "  Widget build(BuildContext context) => GptMarkdown('x');\n"
              '}\n',
        ),
      ]);
      const toggled =
          'MaterialApp(builder: (_, c) => on ? AppThemeScopes(child: c!) : c!,'
          ' home: BoundedMarkdown("x"))';
      final file = SourceFile('test/e_test.dart', 'final a = $toggled;');
      const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
      const exempt = <_Exemption>[
        (
          path: 'test/e_test.dart',
          appContains: 'on ? AppThemeScopes',
          reason: 'r',
        ),
      ];
      expect(_unmountedReaderUses(readers, helpers, file), isNotEmpty);
      expect(
        _unmountedReaderUses(readers, helpers, file, exemptions: exempt),
        isEmpty,
      );
      expect(
        _unmountedReaderUses(
          readers,
          helpers,
          SourceFile('test/other_test.dart', 'final a = $toggled;'),
          exemptions: exempt,
        ),
        isNotEmpty,
      );
      final second = SourceFile(
        'test/e_test.dart',
        'final a = $toggled;\n'
            'final b = MaterialApp(home: BoundedMarkdown("y"));',
      );
      expect(
        _unmountedReaderUses(readers, helpers, second, exemptions: exempt),
        isNotEmpty,
      );
    });

    test('theme data in a test is not a direct seed', () {
      final readers = _readersOf([SourceFile('lib/a/x.dart', 'class X {}\n')]);
      const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
      Set<String> uses(String body) => _unmountedReaderUses(
        readers,
        helpers,
        SourceFile('test/t_test.dart', body),
      );
      expect(
        uses(
          'void main() {\n'
          '  testWidgets("a", (t) async {\n'
          '    await t.pumpWidget(MaterialApp(home: Text("x")));\n'
          '  });\n'
          '  test("b", () {\n'
          '    expect(mui.ThemeData().useMaterial3, isTrue);\n'
          '    final k = GptMarkdownTheme;\n'
          '  });\n'
          '}\n',
        ),
        isEmpty,
      );
      expect(
        uses('await t.pumpWidget(MaterialApp(home: GptMarkdown("x")));'),
        isNotEmpty,
      );
    });

    group('attribution to the callback', () {
      final readers = _readersOf([SourceFile('lib/a/x.dart', 'class X {}\n')]);
      const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
      Set<String> uses(String body) => _unmountedReaderUses(
        readers,
        helpers,
        SourceFile('test/t_test.dart', body),
      );
      const localization =
          '  testWidgets("loc", (t) async {\n'
          '    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {\n'
          '      inside = c;\n'
          '      return SizedBox();\n'
          '    })));\n'
          '  });\n';
      const theme =
          '  testWidgets("theme", (t) async {\n'
          '    expect(mui.Theme.of(x).colorScheme, y);\n'
          '  });\n';

      test('a localization-only app beside another test reading the theme', () {
        expect(uses('void main() {\n$localization$theme}\n'), isEmpty);
      });

      test('a new unscoped test that renders a reader in the same file', () {
        expect(
          uses(
            'void main() {\n$localization$theme'
            '  testWidgets("new", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: GptMarkdown("x")));\n'
            '  });\n'
            '}\n',
          ),
          isNotEmpty,
        );
      });

      test('an app in a helper inside a group counts the whole group', () {
        expect(
          uses(
            'void main() {\n'
            '  group("g", () {\n'
            '    Future<void> pump(t) =>\n'
            '        t.pumpWidget(MaterialApp(home: Text("x")));\n'
            '    testWidgets("a", (t) async {\n'
            '      await pump(t);\n'
            '      expect(mui.Theme.of(x), y);\n'
            '    });\n'
            '  });\n'
            '}\n',
          ),
          isNotEmpty,
        );
      });
    });

    test('a direct material_ui widget is a seed, data types are not', () {
      final readers = _readersOf([SourceFile('lib/a/x.dart', 'class X {}\n')]);
      const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
      Set<String> uses(String body) => _unmountedReaderUses(
        readers,
        helpers,
        SourceFile('test/t_test.dart', body),
      );
      expect(
        uses(
          'await t.pumpWidget(MaterialApp(home: '
          'mui.Slider(value: 0.5, onChanged: null)));',
        ),
        isNotEmpty,
      );
      expect(
        uses(
          'await t.pumpWidget(MaterialApp(home: Text("x")));\n'
          'final d = mui.ThemeData(colorScheme: mui.ColorScheme.light());\n'
          'final t2 = mui.TextTheme();',
        ),
        isEmpty,
      );
    });

    group('readers in test code', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/md.dart',
          'class BoundedMarkdown extends StatelessWidget {\n'
              "  Widget build(BuildContext context) => GptMarkdown('x');\n"
              '}\n',
        ),
      ]);
      final helpers = _helpersOf([
        SourceFile(
          'test/zz/md_harness.dart',
          'Future<void> pumpMarkdown(WidgetTester t, String s) =>\n'
              '    t.pumpWidget(MaterialApp(home: Scaffold(body: '
              'BoundedMarkdown(s))));\n'
              'Future<void> pumpPreview(WidgetTester t) =>\n'
              '    pumpMarkdown(t, "x");\n'
              'Future<void> pumpOuter(WidgetTester t) => pumpPreview(t);\n'
              'Future<void> pumpText(WidgetTester t) =>\n'
              '    t.pumpWidget(MaterialApp(home: Text("x")));\n'
              'Future<void> pumpScoped(WidgetTester t) => t.pumpWidget(\n'
              '    MaterialApp(\n'
              '      builder: (_, c) => AppThemeScopes(child: c!),\n'
              '      home: BoundedMarkdown("x"),\n'
              '    ),\n'
              '  );\n'
              'class MixedRig {\n'
              '  Future<void> scoped(WidgetTester t) => t.pumpWidget(\n'
              '    MaterialApp(\n'
              '      builder: (_, c) => AppThemeScopes(child: c!),\n'
              '      home: BoundedMarkdown("x"),\n'
              '    ),\n'
              '  );\n'
              '  Future<void> label(WidgetTester t) =>\n'
              '      t.pumpWidget(MaterialApp(home: Text("x")));\n'
              '}\n'
              'class ZzSplitRig {\n'
              '  Widget body(String t) => Scaffold(body: BoundedMarkdown(t));\n'
              '  Future<void> pump(String t) =>\n'
              '      tester.pumpWidget(MaterialApp(home: body(t)));\n'
              '}\n'
              'class LeakyRig {\n'
              '  Future<void> scoped(WidgetTester t) => t.pumpWidget(\n'
              '    MaterialApp(\n'
              '      builder: (_, c) => AppThemeScopes(child: c!),\n'
              '      home: Text("x"),\n'
              '    ),\n'
              '  );\n'
              '  Future<void> label(WidgetTester t) => t.pumpWidget(\n'
              '    MaterialApp(home: BoundedMarkdown("x")),\n'
              '  );\n'
              '}\n',
        ),
      ], readers: readers);
      Set<String> uses(String body) => _unmountedReaderUses(
        readers,
        helpers,
        SourceFile('test/zz/a_test.dart', body),
      );

      test('a finder is a use when a plain helper renders the reader', () {
        expect(
          uses(
            "await pumpMarkdown(tester, '# h');\n"
            'expect(find.byType(BoundedMarkdown), findsOneWidget);',
          ),
          isNotEmpty,
        );
      });

      test('a reader a plain helper renders is a use by every caller', () {
        expect(uses('await pumpPreview(tester);'), isNotEmpty);
        expect(uses('await pumpOuter(tester);'), isNotEmpty);
      });

      test('a rig counts members that its unscoped methods call', () {
        expect(uses('await ZzSplitRig(tester).pump("# h");'), isNotEmpty);
      });

      test('a rig only counts the readers its unscoped methods render', () {
        expect(uses('await MixedRig().label(tester);'), isEmpty);
        expect(uses('await LeakyRig().label(tester);'), isNotEmpty);
      });

      test('a text-only plain helper and a scoped helper are accepted', () {
        expect(uses('await pumpText(tester);'), isEmpty);
        expect(uses('await pumpScoped(tester);'), isEmpty);
        expect(
          uses(
            'await t.pumpWidget(MaterialApp(home: Text("x")));\n'
            'expect(find.byType(BoundedMarkdown), findsNothing);',
          ),
          isEmpty,
        );
      });

      test('a direct seed in an unscoped test app is a reader use', () {
        expect(
          uses("await t.pumpWidget(MaterialApp(home: GptMarkdown('x')));"),
          isNotEmpty,
        );
        expect(
          uses(
            'await t.pumpWidget(MaterialApp(home: Builder(builder: (c) =>\n'
            '    Text("x", style: mui.Theme.of(c).text))));',
          ),
          isNotEmpty,
        );
        expect(
          uses(
            'await t.pumpWidget(MaterialApp(\n'
            '    builder: (_, c) => AppThemeScopes(child: c!),\n'
            "    home: GptMarkdown('x')));",
          ),
          isEmpty,
        );
      });
    });

    test('a lib body that uses a prefixed reader is a reader', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/md.dart',
          'class Heading extends StatelessWidget {\n'
              "  Widget build(BuildContext context) => GptMarkdown('x');\n"
              '}\n',
        ),
        SourceFile(
          'lib/b/use.dart',
          "import 'package:hermes_app/a/md.dart' as md;\n"
              'class Page extends StatelessWidget {\n'
              '  Widget build(BuildContext context) => md.Heading();\n'
              '}\n',
        ),
        SourceFile(
          'lib/b/other.dart',
          'class Elsewhere {\n'
              '  Object build() => foo.Heading();\n'
              '}\n',
        ),
      ]);
      expect(readers.names, contains('Page'));
      expect(readers.names, isNot(contains('Elsewhere')));
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

/// The failure message of the guard: only `builder:` mounts.
String _unmountedReason(List<String> bad) =>
    'These tests build an app (or call a helper that does) whose '
    '`builder:` never mounts AppThemeScopes, and reference a widget that '
    "reads material_ui's theme, so it draws with the light fallback in a "
    "dark test. Mount AppThemeScopes in the app's `builder:` "
    '(`builder: (_, child) => AppThemeScopes(child: child!)`):\n'
    '${bad.join('\n')}';

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

/// What in test code reads the theme itself: `GptMarkdown(`, `mui.Theme.of`
/// and a direct `mui.Widget(`. Value types (`mui.ThemeData(`, `ColorScheme`,
/// `TextTheme`, anything named `*Data`, `*Theme` or `*Scheme`) and the scope
/// `mui.Theme(` are data, not a draw, and `GptMarkdownTheme` alone is no use.
final _testSeed = RegExp(
  r'\bGptMarkdown\(|\bmui\.Theme\.of\b|'
  r'\bmui\.(?!\w*(?:Data|Theme|Scheme)\()[A-Z]\w*\(',
);
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

/// [code] without `find.byType(X)` and `find.byWidgetPredicate(...)`: a test
/// that only looks for a reader by type, often to assert there is none, does
/// not render it.
String _withoutFinders(String code) {
  final byType = RegExp(r'\bfind\.byType\(\s*[\w.<>?]+\s*\)');
  var out = code.replaceAll(byType, 'find.byType()');
  final predicate = RegExp(r'\bfind\.byWidgetPredicate\(');
  while (true) {
    final m = predicate.firstMatch(out);
    if (m == null) return out;
    out = out.substring(0, m.start) + out.substring(callEnd(out, m.end));
  }
}

/// An app the guard leaves alone on purpose: the test [path] builds an app
/// whose arguments contain [appContains] and does not mount the scopes, for
/// [reason]. Each entry has to stay an offender (see the test below), so it
/// is removed as soon as it no longer applies.
typedef _Exemption = ({String path, String appContains, String reason});

const List<_Exemption> _exemptions = [
  (
    path: 'test/github_release_store_test.dart',
    appContains: 'bridged ? MaterialUiThemeScope',
    reason: 'tests the unbridged fallback on purpose',
  ),
];

typedef _Helpers = ({List<_Helper> mounting, List<_Helper> plain});

/// The readers the test [file] refers to when it builds an unmounted app of
/// its own or calls a helper whose app is unmounted, else none. The readers a
/// plain helper renders count as uses of every caller.
Set<String> _unmountedReaderUses(
  _Readers readers,
  _Helpers helpers,
  SourceFile file, {
  List<_Exemption> exemptions = const [],
}) {
  final code = file.code;
  final unmounted = [
    for (final a in _apps(code))
      if (!a.mounted &&
          !exemptions.any(
            (e) => e.path == file.path && a.args.contains(e.appContains),
          ))
        a,
  ];
  final plainCalled = helpers.plain.where((h) => h.calledIn(code)).toList();
  if (unmounted.isEmpty && plainCalled.isEmpty) return const {};
  return {
    // A helper's app is drawn wherever it is called: the whole file counts.
    if (plainCalled.isNotEmpty) ..._readerUses(readers, file),
    // An app of the file's own draws only what its test or group builds.
    for (final a in unmounted)
      ..._readerUses(readers, file, within: _callbackAround(code, a.start)),
    for (final h in plainCalled)
      for (final use in h.uses) '$use (via ${h.name})',
  };
}

/// The narrowest `test`, `testWidgets` or `group` callback of [code] that
/// holds [offset], or all of [code] when the offset is in none of them (a
/// top-level helper or `main` itself).
String _callbackAround(String code, int offset) {
  var start = 0;
  var end = code.length;
  for (final m in RegExp(
    r'(?<![\w.])(?:testWidgets|test|group)\(',
  ).allMatches(code)) {
    if (m.start > offset) break;
    final close = callEnd(code, m.end);
    if (close > offset && close - m.start < end - start) {
      start = m.start;
      end = close;
    }
  }
  return code.substring(start, end);
}

/// The readers [file] (a test or a helper file) refers to in [within] (its
/// whole code by default), finders aside: names and prefixed names, the seeds
/// themselves (`GptMarkdown(`, `mui.Theme.of`) and the extension members it
/// can see.
Set<String> _readerUses(_Readers readers, SourceFile file, {String? within}) {
  final code = _withoutFinders(within ?? file.code);
  return {
    if (readers.names.isNotEmpty)
      for (final m in _wordsPattern(
        readers.names,
        prefixes: _importPrefixes(file),
      ).allMatches(code))
        m.group(0)!,
    for (final m in _testSeed.allMatches(code)) m.group(0)!,
    ..._memberUses(readers, file, code),
  };
}

/// The readers helper [d] renders itself. A class counts only the members
/// that build an unmounted app, and the members those call by bare name (to a
/// fixpoint): a rig with a scoped method and an unscoped one that pumps text is
/// no reader use for a test that calls the second.
Set<String> _ownUses(_Readers readers, SourceFile file, _Decl d) {
  if (!_typeDecl.hasMatch(d.body)) {
    return _readerUses(readers, file, within: d.body);
  }
  final members = d.body.split(RegExp(r'(?=^  [^\s}])', multiLine: true));
  String? nameOf(String member) =>
      RegExp(r'\bget\s+(\w+)').firstMatch(member)?.group(1) ??
      RegExp(r'(\w+)\s*(?:<[^>(]*>)?\s*\(').firstMatch(member)?.group(1);
  final named = {
    for (final m in members)
      if (nameOf(m) != null) nameOf(m)!: m,
  };
  final counted = <String>{
    for (final m in members)
      if (_apps(m).any((a) => !a.mounted) && nameOf(m) != null) nameOf(m)!,
  };
  var grew = true;
  while (grew) {
    grew = false;
    for (final name in counted.toList()) {
      for (final e in named.entries) {
        if (!counted.contains(e.key) &&
            e.key != name &&
            RegExp('(?<![\\w.\$])${e.key}\\b').hasMatch(named[name]!)) {
          counted.add(e.key);
          grew = true;
        }
      }
    }
  }
  return {
    for (final name in counted)
      ..._readerUses(readers, file, within: named[name]!),
  };
}

/// The `.member` uses in [code] of extension members declared in a library
/// that [file] imports.
Iterable<String> _memberUses(_Readers readers, SourceFile file, String code) {
  final imported = _importsOf(file);
  final visible = [
    for (final e in readers.members.entries)
      if (e.value.any(imported.contains)) e.key,
  ];
  if (visible.isEmpty) return const [];
  return RegExp('\\.\\s*(?:${visible.join('|')})\\b')
      .allMatches(code)
      .map((m) => m.group(0)!);
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

  /// What the library imports (resolved repo paths) and the prefixes it
  /// imports under.
  Set<String> imports = const {};
  Set<String> prefixes = const {};
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
/// What [_readersOf] derives. [members] maps an extension member name to the
/// libraries that declare it: `.name` is a reader only in a file that is in
/// one of them or imports one.
typedef _Readers = ({
  Set<String> names,
  Map<String, Set<String>> members,
  List<String> seedsWithoutBody,
});

_Readers _readers() => _readersOf(dartFiles('lib'));

/// The repo paths [file] imports: `package:hermes_app/` and relative imports.
Set<String> _importsOf(SourceFile file) => {
  for (final m in RegExp(
    r'''^import\s+['"]([^'"]+)['"]''',
    multiLine: true,
  ).allMatches(file.text))
    if (m.group(1)!.startsWith('package:hermes_app/'))
      'lib/${m.group(1)!.substring('package:hermes_app/'.length)}'
    else if (!m.group(1)!.contains(':'))
      Uri(path: file.path).resolve(m.group(1)!).path,
};

_Readers _readersOf(List<SourceFile> files) {
  final decls = <_Decl>[];
  final imports = <String, Set<String>>{};
  final prefixes = <String, Set<String>>{};
  for (final f in files) {
    final library = _libraryOf(f);
    (imports[library] ??= {}).addAll(_importsOf(f));
    (prefixes[library] ??= {}).addAll(_importPrefixes(f));
    for (final d in _declarations(f)) {
      d.library = library;
      decls.add(d);
    }
  }
  for (final d in decls) {
    d.imports = imports[d.library]!;
    d.prefixes = prefixes[d.library]!;
  }
  final all = decls;

  bool skipped(_Decl d) =>
      _provider.hasMatch(d.body) ||
      _appConstructor.hasMatch(d.body) ||
      _navigationOnly.any(
        (n) =>
            d.name == n ||
            d.name == '_${n}State' ||
            d.on == n ||
            d.on == '_${n}State',
      );

  final mentions = <String, List<_Decl>>{};
  for (final d in all) {
    final names = {
      for (final m in _identifier.allMatches(d.body)) m.group(0)!,
      if (d.prefixes.isNotEmpty)
        for (final m in RegExp(
          '(?<![\\w.\$])(?:${d.prefixes.join('|')})\\.([A-Za-z_]\\w*)',
        ).allMatches(d.body))
          m.group(1)!,
    };
    for (final m in names) {
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
  final members = <String, Set<String>>{};
  while (queue.isNotEmpty) {
    final d = queue.removeLast();
    for (final m in mentions[d.name] ?? const <_Decl>[]) {
      if (d.name.startsWith('_') && m.library != d.library) continue;
      reach(m);
    }
    if (d.on != null) {
      // An extension is reached through its members, `context.view` from
      // anywhere that sees it, or a bare `view` in the body of the type it
      // extends. Its receiver is not a reader just for being extended.
      for (final member in _memberNames(d.body)) {
        (members[member] ??= {}).add(d.library);
        final use = RegExp('\\.\\s*$member\\b');
        final bare = RegExp('(?<![\\w.\$])$member\\b');
        for (final other in all) {
          final sees =
              other.library == d.library ||
              other.imports.contains(d.library) ||
              other.imports.contains(d.path);
          if (other == d || !sees) continue;
          // The extended type, or another extension on it, calls the member
          // bare; the chain `build` -> `_outer` -> `_inner` is followed to
          // its end because each reached declaration is queued in turn.
          if (use.hasMatch(other.body) ||
              ((other.name == d.on || other.on == d.on) &&
                  bare.hasMatch(other.body))) {
            reach(other);
          }
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
/// conditional. A scope in `home:` does not count: a route pushed from `home`
/// is built outside it.
bool _constructorMounts(String code, int open) {
  final args = code.substring(open, callEnd(code, open) - 1);
  final builder = _namedArgument(args, 'builder');
  if (builder != null) {
    for (final m in _mountCall.allMatches(builder)) {
      if (!_inConditional(builder, m.start)) return true;
    }
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
List<({int start, bool mounted, String args})> _apps(String code) => [
  for (final m in _appConstructor.allMatches(code))
    (
      start: m.start,
      mounted: _constructorMounts(code, m.end),
      args: code.substring(m.end, callEnd(code, m.end) - 1),
    ),
  for (final m in RegExp(r'(?<![\w.])HermesApp\(').allMatches(code))
    (start: m.start, mounted: true, args: ''),
];

class _Helper {
  _Helper(this.name, this.isType);

  final String name;
  final bool isType;

  /// The readers this helper renders itself, or through the plain helpers it
  /// calls.
  Set<String> uses = {};

  bool calledIn(String code) =>
      RegExp(isType ? '(?<![\\w.])$name\\b' : '(?<![\\w.])$name\\(')
          .hasMatch(code);
}

/// Functions and classes of the test helper files (anything under `test/` not
/// named `*_test.dart`: `test/support` and the harnesses beside a directory)
/// that build an app, split by whether every app they build mounts the scopes,
/// directly or through another helper.
_Helpers _testHelpers(_Readers readers) => _helpersOf([
  for (final f in dartFiles('test'))
    if (!f.path.endsWith('_test.dart')) f,
], readers: readers);

/// A helper is plain when any app it builds, or any helper it calls, is plain;
/// it mounts when it builds apps that all mount or calls only mounting
/// helpers. Iterates until nothing changes, so a long chain of callers ending
/// in a plain app is plain whatever the declaration order.
_Helpers _helpersOf(List<SourceFile> files, {_Readers? readers}) {
  final decls = [for (final f in files) ..._declarations(f)];
  final fileOf = {
    for (final f in files)
      for (final d in _declarations(f)) d.path: f,
  };
  final mounting = <String, _Helper>{};
  final plain = <String, _Helper>{};
  var changed = true;
  while (changed) {
    changed = false;
    for (final d in decls) {
      if (plain.containsKey(d.name)) continue;
      final helper = _Helper(d.name, _typeDecl.hasMatch(d.body));
      final apps = _apps(d.body);
      bool calls(Iterable<_Helper> hs) =>
          hs.any((h) => h.name != d.name && h.calledIn(d.body));
      if (apps.any((a) => !a.mounted) || calls(plain.values)) {
        plain[d.name] = helper;
        mounting.remove(d.name);
        changed = true;
      } else if (!mounting.containsKey(d.name) &&
          (apps.isNotEmpty || calls(mounting.values))) {
        mounting[d.name] = helper;
        changed = true;
      }
    }
  }
  if (readers != null) {
    final own = {
      for (final d in decls)
        if (plain.containsKey(d.name))
          d.name: _ownUses(readers, fileOf[d.path]!, d),
    };
    var grew = true;
    while (grew) {
      grew = false;
      for (final d in decls) {
        final h = plain[d.name];
        if (h == null) continue;
        final uses = {...own[d.name]!, ...h.uses};
        for (final other in plain.values) {
          if (other.name != d.name && other.calledIn(d.body)) {
            uses.addAll(other.uses);
          }
        }
        if (uses.length > h.uses.length) {
          h.uses = uses;
          grew = true;
        }
      }
    }
  }
  return (mounting: mounting.values.toList(), plain: plain.values.toList());
}
