import 'dart:io';

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
    // channels, so this reads the source: comments are stripped, then a file
    // may not build more apps than it mounts scopes.
    final apps = RegExp(
      r'\b(?:MaterialApp(?:\.router)?|CupertinoApp|WidgetsApp)\(',
    );
    final scopes = RegExp(r'\bAppThemeScopes\(');
    final comments = RegExp(r'//[^\n]*|/\*[\s\S]*?\*/');
    final short = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('generated')) continue;
      final code = f.readAsStringSync().replaceAll(comments, '');
      if (apps.allMatches(code).length > scopes.allMatches(code).length) {
        short.add(f.path);
      }
    }
    expect(short, isEmpty);
  });

  test('a hand-built test app that renders a theme-scope reader mounts '
      'AppThemeScopes', () {
    // `mui.Theme.of` does not throw without the scope, it falls back to the
    // light theme, so a dark test draws near-black headings and light code
    // blocks. Nothing fails at run time: this reads the sources.
    final readers = _readerClasses();
    expect(readers, isNotEmpty);
    expect(readers, containsAll(['BoundedMarkdown', 'HermesCodeBlock']));

    final helpers = _supportHelpers();
    final readerPattern = _wordsPattern(readers);
    final bad = <String>[];
    for (final f in _dartFiles('test')) {
      final path = f.path;
      if (!path.endsWith('_test.dart')) continue;
      final code = _stripComments(f.readAsStringSync());
      final mountsHelper = helpers.mounting.any(
        (h) => RegExp('\\b$h\\(').hasMatch(code),
      );
      final callsPlain = helpers.plain.any(
        (h) => RegExp('\\b$h\\(').hasMatch(code),
      );
      final buildsApp = _appConstructor.hasMatch(code) || callsPlain;
      if (!buildsApp) continue;
      if (_mountingIdentifier.hasMatch(code) || mountsHelper) continue;
      final used = readerPattern
          .allMatches(code)
          .map((m) => m.group(0)!)
          .toSet();
      if (used.isNotEmpty) {
        bad.add('$path: ${(used.toList()..sort()).join(', ')}');
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          'These tests build their own app and reference a widget that reads '
          "material_ui's theme, but never mount AppThemeScopes, so it draws "
          'with the light fallback in a dark test. Mount AppThemeScopes in '
          "the app's `builder:` (`builder: (_, child) => "
          'AppThemeScopes(child: child!)`):\n${bad.join('\n')}',
    );
  });
}

final _appConstructor = RegExp(
  r'\b(?:MaterialApp(?:\.router)?|CupertinoApp|WidgetsApp)\(',
);
final _mountingIdentifier = RegExp(
  r'\b(?:AppThemeScopes|MaterialUiThemeScope|FlyerMaterialScope|'
  r'buildMaterialUiTheme|pumpScreen|pumpWorkflowApp)\b|\bHermesApp\(',
);
final _comments = RegExp(r'//[^\n]*|/\*[\s\S]*?\*/');

String _stripComments(String code) => code.replaceAll(_comments, '');

List<File> _dartFiles(String dir) => [
  for (final f in Directory(dir).listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart') && !f.path.contains('generated'))
      f,
];

RegExp _wordsPattern(Iterable<String> words) =>
    RegExp('\\b(?:${words.join('|')})\\b');

/// Classes in `lib/` whose build reads `material_ui`'s theme or draws
/// `gpt_markdown`, and every class that mentions one of those, transitively.
/// Scope providers and app roots are not readers, and neither are the
/// navigation-only roots: they open a reader only after a tap, and a test that
/// pumps one of them to reach a route does not draw it.
Set<String> _readerClasses() {
  final decl = RegExp(
    r'^(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*'
    r'(?:class|mixin|enum)\s+(\w+)',
    multiLine: true,
  );
  final seed = RegExp(
    r'\bmui\.Theme\.of\b|\bGptMarkdown\(|\bGptMarkdownTheme\b|\bmui\.[A-Z]\w*\(',
  );
  final provider = RegExp(
    r'\bmui\.Theme\(|\bMaterialUiThemeScope\(|\bAppThemeScopes\(',
  );
  final bodies = <String, String>{};
  for (final f in _dartFiles('lib')) {
    final code = _stripComments(f.readAsStringSync());
    final starts = decl.allMatches(code).toList();
    for (var i = 0; i < starts.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1].start : code.length;
      bodies[starts[i].group(1)!] = code.substring(starts[i].start, end);
    }
  }
  const navigationOnly = {'AppShell', 'MacProfilesPage', 'HermesApp'};
  bool skipped(String name, String body) =>
      provider.hasMatch(body) ||
      _appConstructor.hasMatch(body) ||
      navigationOnly.any((n) => name == n || name == '_${n}State');
  final reached = <String>{
    for (final e in bodies.entries)
      if (!skipped(e.key, e.value) && seed.hasMatch(e.value)) e.key,
  };
  var grew = true;
  while (grew && reached.isNotEmpty) {
    grew = false;
    final pattern = _wordsPattern(reached);
    for (final e in bodies.entries) {
      if (reached.contains(e.key) || skipped(e.key, e.value)) continue;
      if (pattern.hasMatch(e.value)) {
        reached.add(e.key);
        grew = true;
      }
    }
  }
  return reached;
}

/// Top-level functions of the test helper files (`test/support` and the
/// harnesses beside a test directory, anything not named `*_test.dart`) that
/// build an app, split by whether
/// they mount the theme scopes (directly or through another helper).
({Set<String> mounting, Set<String> plain}) _supportHelpers() {
  final chunkStart = RegExp(r'^(?=[A-Za-z])', multiLine: true);
  final header = RegExp(
    r'^(?!class|import|export|part|typedef|const|final|abstract|mixin|enum|'
    r'extension)[\w<>?,. ]+?\s(\w+)\(',
  );
  final chunks = <String, String>{};
  for (final f in _dartFiles('test')) {
    if (f.path.endsWith('_test.dart')) continue;
    for (final c in _stripComments(f.readAsStringSync()).split(chunkStart)) {
      final m = header.firstMatch(c);
      if (m != null) chunks[m.group(1)!] = c;
    }
  }
  final mounting = <String>{};
  final plain = <String>{};
  for (var round = 0; round < 4; round++) {
    for (final e in chunks.entries) {
      bool calls(Set<String> names) =>
          names.any((n) => n != e.key && RegExp('\\b$n\\(').hasMatch(e.value));
      if (_mountingIdentifier.hasMatch(e.value) || calls(mounting)) {
        mounting.add(e.key);
        plain.remove(e.key);
      } else if (_appConstructor.hasMatch(e.value) || calls(plain)) {
        plain.add(e.key);
      }
    }
  }
  return (mounting: mounting, plain: plain);
}
