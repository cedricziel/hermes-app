import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:material_ui/material_ui.dart';
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
    // it mounts scopes. Comments and strings are not code to the parser.
    expect(_syntaxErrors(dartFiles('lib')), isEmpty);
    final short = <String>[];
    for (final f in dartFiles('lib')) {
      if (!_appWord.hasMatch(f.raw)) continue;
      final p = _parse(f);
      if (p.apps.where((a) => !a.hermes).length > p.scopeCalls) {
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
    expect(_syntaxErrors(dartFiles('test')), isEmpty);
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

  test('the analyzer API canary: the parser still produces what the guard '
      'reads', () {
    // The guard reads the unresolved syntax tree of package:analyzer, and a
    // major version has renamed or reshaped nodes before (a named argument is
    // a `NamedArgument` now, not a `NamedExpression`). A node the parser stops
    // producing would not fail the guard, it would make it see nothing, so
    // this parses a snippet with every construct the guard relies on and
    // names the ones it no longer finds.
    final unit = parseString(
      content: r'''
import r'package:flutter/material.dart' as m;
class C extends StatelessWidget {
  Widget build(c) => m.MaterialApp(builder: _scoped, home: x);
}
mixin M {}
enum E { a }
enum E2 { a; void f() {} }
class Rig {
  Rig(this.v);
  Rig.named() : v = 0;
  final int v;
  static Widget stat(BuildContext c, Widget? child) => child!;
}
extension FactoryPreview on Widget Function() {
  Widget get preview => x;
}
Object tears() => MaterialApp(builder: Rig.stat, home: Rig().stat, key: (k));
extension type T(int v) {}
class A = Object with M;
final top = 1;
extension X on int {
  int get g => 1;
  void f() {}
}
Widget _scoped(BuildContext c, Widget? child) => AppThemeScopes(child: child!);
void main() {
  MaterialApp(builder: (_, child) { final w = child!; return w; });
  MaterialApp.router(routerConfig: r);
  const m.CupertinoApp();
  mui.Theme.of(c);
  <int>[1]..clear();
  find.byType(Foo);
  var a = x ? y : z;
  var b = switch (a) { 1 => y, _ => z };
  switch (a) { case 1: break; }
  if (a) {}
  var c = [if (a) b, for (final w in ws) w];
  for (final w in ws) {}
}
''',
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    ).unit;
    final nodes = <AstNode>[];
    unit.accept(_Collect(nodes));
    final parts = parseString(
      content: "part of r'../lib.dart';\n",
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    ).unit;

    T? first<T extends AstNode>(bool Function(T) where) =>
        nodes.whereType<T>().where(where).firstOrNull;
    final checks = <String, bool>{
      'ImportDirective with prefix and a raw-string uri': unit.directives
          .whereType<ImportDirective>()
          .any(
            (d) =>
                d.uri.stringValue == 'package:flutter/material.dart' &&
                d.prefix?.name == 'm',
          ),
      'PartOfDirective with uri': parts.directives
          .whereType<PartOfDirective>()
          .any((d) => d.uri?.stringValue == '../lib.dart'),
      'NamedArgument (name, argumentExpression, in ArgumentList.arguments)':
          first<NamedArgument>(
            (a) =>
                a.name.lexeme == 'builder' &&
                a.argumentExpression is SimpleIdentifier &&
                a.parent is ArgumentList,
          ) !=
          null,
      'MethodInvocation without a target (a bare call)':
          first<MethodInvocation>(
            (m) =>
                m.target == null &&
                m.methodName.name == 'MaterialApp' &&
                !m.isCascaded,
          ) !=
          null,
      'MethodInvocation under an import prefix (a SimpleIdentifier target)':
          first<MethodInvocation>(
            (m) =>
                m.target is SimpleIdentifier &&
                m.methodName.name == 'MaterialApp',
          ) !=
          null,
      'MethodInvocation on a prefixed name (a PrefixedIdentifier target)':
          first<MethodInvocation>(
            (m) => m.target is PrefixedIdentifier && m.methodName.name == 'of',
          ) !=
          null,
      'MethodInvocation of a cascade section (isCascaded)':
          first<MethodInvocation>(
            (m) => m.isCascaded && m.methodName.name == 'clear',
          ) !=
          null,
      'InstanceCreationExpression with an import prefix on its type':
          first<InstanceCreationExpression>(
            (c) =>
                c.constructorName.type.name.lexeme == 'CupertinoApp' &&
                c.constructorName.type.importPrefix?.name.lexeme == 'm',
          ) !=
          null,
      'FunctionExpression with parameters and a body':
          first<FunctionExpression>(
            (f) => f.parameters?.parameters.length == 2,
          ) !=
          null,
      'FormalParameter.isPositional and .name':
          first<FunctionExpression>(
            (f) =>
                f.parameters?.parameters.length == 2 &&
                f.parameters!.parameters.last.isPositional &&
                f.parameters?.parameters.last.name?.lexeme == 'child',
          ) !=
          null,
      'FunctionDeclaration (name, functionExpression)': unit.declarations
          .whereType<FunctionDeclaration>()
          .any(
            (f) =>
                f.name.lexeme == '_scoped' &&
                f.functionExpression.parameters != null,
          ),
      'ExtensionDeclaration (name, onClause, body.members)': unit.declarations
          .whereType<ExtensionDeclaration>()
          .any(
            (e) =>
                e.name?.lexeme == 'X' &&
                e.onClause?.extendedType is NamedType &&
                e.body.members.whereType<MethodDeclaration>().length == 2,
          ),
      'MethodDeclaration (name, isGetter)':
          first<MethodDeclaration>((m) => m.isGetter && m.name.lexeme == 'g') !=
          null,
      'ClassDeclaration (namePart.typeName)': unit.declarations
          .whereType<ClassDeclaration>()
          .any((c) => c.namePart.typeName.lexeme == 'C'),
      'MixinDeclaration (name)': unit.declarations
          .whereType<MixinDeclaration>()
          .any((m) => m.name.lexeme == 'M'),
      'EnumDeclaration (namePart.typeName)': unit.declarations
          .whereType<EnumDeclaration>()
          .any((e) => e.namePart.typeName.lexeme == 'E'),
      'ExtensionTypeDeclaration (namePart.typeName)': unit.declarations
          .whereType<ExtensionTypeDeclaration>()
          .any((e) => e.namePart.typeName.lexeme == 'T'),
      'ClassTypeAlias (name)': unit.declarations
          .whereType<ClassTypeAlias>()
          .any((c) => c.name.lexeme == 'A'),
      'TopLevelVariableDeclaration (variables)': unit.declarations
          .whereType<TopLevelVariableDeclaration>()
          .any((v) => v.variables.variables.first.name.lexeme == 'top'),
      'NamedArgument whose value is a PrefixedIdentifier (a static tear-off)':
          first<NamedArgument>(
            (a) =>
                a.name.lexeme == 'builder' &&
                a.argumentExpression is PrefixedIdentifier,
          ) !=
          null,
      'PropertyAccess (a tear-off of a call result)':
          first<PropertyAccess>((a) => a.propertyName.name == 'stat') != null,
      'ParenthesizedExpression':
          first<ParenthesizedExpression>(
            (e) => e.expression is SimpleIdentifier,
          ) !=
          null,
      'VariableDeclaration with a name and an initializer':
          first<VariableDeclaration>(
            (v) => v.name.lexeme == 'w' && v.initializer != null,
          ) !=
          null,
      'FieldDeclaration (fields.variables)':
          first<FieldDeclaration>(
            (f) => f.fields.variables.first.name.lexeme == 'v',
          ) !=
          null,
      'ConstructorDeclaration (name, typeName)':
          first<ConstructorDeclaration>(
            (c) => c.name?.lexeme == 'named' && c.typeName?.name == 'Rig',
          ) !=
          null,
      'EnumDeclaration with a BlockEnumBody and its members': unit.declarations
          .whereType<EnumDeclaration>()
          .any((e) {
            final body = e.body;
            return e.namePart.typeName.lexeme == 'E2' &&
                body is BlockEnumBody &&
                body.members.length == 1;
          }),
      'ExtensionDeclaration on a type that is not a NamedType': unit
          .declarations
          .whereType<ExtensionDeclaration>()
          .any(
            (e) =>
                e.name?.lexeme == 'FactoryPreview' &&
                e.onClause?.extendedType is! NamedType &&
                e.body.members.length == 1,
          ),
      'ConditionalExpression':
          first<ConditionalExpression>((_) => true) != null,
      'SwitchExpression': first<SwitchExpression>((_) => true) != null,
      'SwitchStatement': first<SwitchStatement>((_) => true) != null,
      'IfStatement': first<IfStatement>((_) => true) != null,
      'IfElement': first<IfElement>((_) => true) != null,
      'ForStatement': first<ForStatement>((_) => true) != null,
      'ForElement': first<ForElement>((_) => true) != null,
    };
    final missing = [
      for (final e in checks.entries)
        if (!e.value) e.key,
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'package:analyzer no longer produces what the theme-scope guard '
          '(test/app_theme_scopes_test.dart: _Parsed, _Index, _shapes, '
          '_findApps, _bodyMounts, _inConditional, _declarations) reads:\n'
          '${missing.join('\n')}\n'
          'Update the guard to the new syntax tree before trusting its '
          'results: it would otherwise see no apps and pass.',
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

    group('a builder tear-off', () {
      bool mounted(String source) => _apps(source).single.mounted;
      const app = 'Object app() => MaterialApp(builder: _scoped);\n';

      test('a function whose body wraps the child mounts the app', () {
        expect(
          mounted(
            '${app}Widget _scoped(BuildContext c, Widget? child) =>\n'
            '    AppThemeScopes(child: child!);\n',
          ),
          isTrue,
        );
        expect(
          mounted(
            '${app}Widget _scoped(BuildContext c, Widget? child) {\n'
            '  final x = 1;\n'
            '  return AppThemeScopes(child: child!);\n'
            '}\n',
          ),
          isTrue,
        );
      });

      test('a method of the same library mounts the app', () {
        final apps = _apps(
          'class Rig {\n'
          '  Widget scoped(BuildContext c, Widget? child) =>\n'
          '      MaterialUiThemeScope(child: child!);\n'
          '  Object app() => MaterialApp(builder: scoped);\n'
          '  static Widget stat(BuildContext c, Widget? child) =>\n'
          '      FlyerMaterialScope(child: child!);\n'
          '}\n'
          'Object other() => MaterialApp(builder: Rig.stat);\n',
        );
        expect(apps.map((a) => a.mounted), [true, true]);
      });

      test('a tear-off whose body does not mount is unmounted', () {
        expect(
          mounted(
            '${app}Widget _scoped(BuildContext c, Widget? child) => child!;\n',
          ),
          isFalse,
        );
        expect(
          mounted(
            '${app}Widget _scoped(BuildContext c, Widget? child) =>\n'
            '    Padding(padding: p, child: child!);\n',
          ),
          isFalse,
        );
      });

      test('a conditional tear-off is unmounted', () {
        expect(
          mounted(
            '${app}Widget _scoped(BuildContext c, Widget? child) =>\n'
            '    on ? AppThemeScopes(child: child!) : child!;\n',
          ),
          isFalse,
        );
      });

      test('a tear-off with no declaration in the file is unmounted', () {
        expect(mounted(app), isFalse);
        expect(
          mounted(
            '${app}Widget _scoped(BuildContext c, Widget? child) =>\n'
            '    AppThemeScopes(child: child!);\n'
            'class Other {\n'
            '  Widget _scoped(BuildContext c, Widget? child) => child!;\n'
            '}\n',
          ),
          isFalse,
          reason: 'one of two declarations of the name does not mount',
        );
      });

      test('a mounting tear-off keeps a reader out of the report', () {
        final readers = _readersOf([
          SourceFile(
            'lib/a/md.dart',
            'class BoundedMarkdown extends StatelessWidget {\n'
                "  Widget build(BuildContext context) => GptMarkdown('x');\n"
                '}\n',
          ),
        ]);
        const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
        String source(String scoped) =>
            'Widget _scoped(BuildContext c, Widget? child) => $scoped;\n'
            'Object app() => MaterialApp(\n'
            '  builder: _scoped,\n'
            '  home: BoundedMarkdown("x"),\n'
            ');\n';
        Set<String> uses(String scoped) => _unmountedReaderUses(
          readers,
          helpers,
          SourceFile('test/t_test.dart', source(scoped)),
        );
        expect(uses('AppThemeScopes(child: child!)'), isEmpty);
        expect(uses('child!'), isNotEmpty);
      });
    });

    group('a reader built around the test that draws it', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/md.dart',
          'class BoundedMarkdown extends StatelessWidget {\n'
              "  Widget build(BuildContext context) => GptMarkdown('x');\n"
              '}\n',
        ),
      ]);
      const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
      Set<String> uses(String body) => _unmountedReaderUses(
        readers,
        helpers,
        SourceFile('test/t_test.dart', body),
      );
      String suite(String around, {String hook = 'setUp'}) =>
          'void main() {\n'
          '  group("g", () {\n'
          '    late Widget w;\n'
          '    $hook(() {\n'
          '      w = BoundedMarkdown("x");\n'
          '    });\n'
          '$around'
          '  });\n'
          '}\n';
      const nested =
          '    group("nested", () {\n'
          '      testWidgets("t", (t) async {\n'
          '        await t.pumpWidget(MaterialApp(home: w));\n'
          '      });\n'
          '    });\n';

      test('a reader in setUp counts for the tests of its group', () {
        expect(
          uses(
            suite(
              '    testWidgets("t", (t) async {\n'
              '      await t.pumpWidget(MaterialApp(home: w));\n'
              '    });\n',
            ),
          ),
          {'BoundedMarkdown (reader built in setUp at line 5)'},
        );
      });

      test('a reader in setUp counts for the tests of a nested group', () {
        expect(uses(suite(nested)), {
          'BoundedMarkdown (reader built in setUp at line 5)',
        });
      });

      test('a reader in setUpAll is named setUpAll', () {
        expect(uses(suite(nested, hook: 'setUpAll')), {
          'BoundedMarkdown (reader built in setUpAll at line 5)',
        });
      });

      test('the setUp of a sibling group does not count', () {
        expect(
          uses(
            'void main() {\n'
            '  group("a", () {\n'
            '    setUp(() {\n'
            '      w = BoundedMarkdown("x");\n'
            '    });\n'
            '    testWidgets("t", (t) async {\n'
            '      expect(w, isNotNull);\n'
            '    });\n'
            '  });\n'
            '  group("b", () {\n'
            '    testWidgets("loc", (t) async {\n'
            '      await t.pumpWidget(MaterialApp(home: Text("x")));\n'
            '    });\n'
            '  });\n'
            '}\n',
          ),
          isEmpty,
        );
      });

      test('the setUp of a nested group does not count for its parent', () {
        expect(
          uses(
            'void main() {\n'
            '  group("outer", () {\n'
            '    testWidgets("t", (t) async {\n'
            '      await t.pumpWidget(MaterialApp(home: Text("x")));\n'
            '    });\n'
            '    group("inner", () {\n'
            '      setUp(() {\n'
            '        w = BoundedMarkdown("x");\n'
            '      });\n'
            '    });\n'
            '  });\n'
            '}\n',
          ),
          isEmpty,
        );
      });

      test('a local of a group counts for its tests', () {
        expect(
          uses(
            'void main() {\n'
            '  group("g", () {\n'
            '    final shown = BoundedMarkdown("x");\n'
            '    testWidgets("t", (t) async {\n'
            '      await t.pumpWidget(MaterialApp(home: shown));\n'
            '    });\n'
            '  });\n'
            '}\n',
          ),
          {'BoundedMarkdown (reader built in a group at line 3)'},
        );
      });

      test('a local closure of main counts for its tests', () {
        expect(
          uses(
            'void main() {\n'
            '  Widget make() => BoundedMarkdown("x");\n'
            '  testWidgets("t", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: make()));\n'
            '  });\n'
            '}\n',
          ),
          {'BoundedMarkdown (reader built in main at line 2)'},
        );
      });

      test('a top-level helper of the test file counts for its tests', () {
        expect(
          uses(
            'Widget _shown() => BoundedMarkdown("x");\n'
            'void main() {\n'
            '  testWidgets("t", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: _shown()));\n'
            '  });\n'
            '}\n',
          ),
          {'BoundedMarkdown (reader built in a top-level helper at line 1)'},
        );
      });

      test('a loop over widgets counts for the tests it makes', () {
        expect(
          uses(
            'void main() {\n'
            '  for (final w in [BoundedMarkdown("x")]) {\n'
            '    testWidgets("t", (t) async {\n'
            '      await t.pumpWidget(MaterialApp(home: w));\n'
            '    });\n'
            '  }\n'
            '}\n',
          ),
          {'BoundedMarkdown (reader built in a for loop at line 2)'},
        );
      });

      test('a sibling test that builds the reader still does not count', () {
        expect(
          uses(
            'void main() {\n'
            '  testWidgets("loc", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: Text("x")));\n'
            '  });\n'
            '  testWidgets("other", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: BoundedMarkdown("x")));\n'
            '    expect(mui.Theme.of(c), isNotNull);\n'
            '  });\n'
            '}\n',
          ),
          isNotEmpty,
          reason: 'the second test builds its own unmounted app',
        );
        expect(
          uses(
            'void main() {\n'
            '  testWidgets("loc", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: Text("x")));\n'
            '  });\n'
            '  testWidgets("other", (t) async {\n'
            '    expect(mui.Theme.of(c), isNotNull);\n'
            '  });\n'
            '}\n',
          ),
          isEmpty,
        );
      });
    });

    group('an extension member is one the declaration lists', () {
      // A line indented two spaces or more that reads `a.b(` was taken for a
      // member of the extension, so a `.clear()` in a test counted as a use
      // of the reader the extension holds.
      final readers = _readersOf([
        SourceFile(
          'lib/a/screen.dart',
          "part 'screen_part.dart';\n"
              'class Screen extends StatefulWidget {\n'
              '  State createState() => _ScreenState();\n'
              '}\n'
              'class _ScreenState extends State<Screen> {\n'
              '  Widget build(BuildContext context) => _body();\n'
              '}\n',
        ),
        SourceFile(
          'lib/a/screen_part.dart',
          "part of 'screen.dart';\n"
              'extension _ScreenParts on _ScreenState {\n'
              '  Widget _body() {\n'
              '    _items.clear();\n'
              "    return GptMarkdown('x');\n"
              '  }\n'
              '}\n',
        ),
      ]);

      test('a call in a member body is not a member', () {
        expect(readers.names, contains('Screen'));
        expect(readers.members.keys, contains('_body'));
        expect(readers.members.keys, isNot(contains('clear')));
        expect(readers.members.keys, isNot(contains('GptMarkdown')));
      });

      test('a cascade in a test beside a text-only app is no reader use', () {
        const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
        final file = SourceFile(
          'test/a_test.dart',
          "import 'package:hermes_app/a/screen.dart';\n"
              'void main() {\n'
              '  testWidgets("t", (t) async {\n'
              '    final list = <int>[1]..clear();\n'
              '    await t.pumpWidget(MaterialApp(home: Text("x")));\n'
              '  });\n'
              '}\n',
        );
        expect(_unmountedReaderUses(readers, helpers, file), isEmpty);
      });
    });

    group('a mount behind a conditional or beside the child', () {
      bool mounted(String builder) =>
          _apps('Object a() => MaterialApp(builder: $builder);').single.mounted;

      test('a switch expression does not mount', () {
        expect(
          mounted(
            '(_, c) => switch (mode) {'
            ' 1 => AppThemeScopes(child: c!), _ => c! }',
          ),
          isFalse,
        );
      });

      test('a switch statement does not mount', () {
        expect(
          mounted(
            '(_, c) { switch (mode) { case 1: '
            'return AppThemeScopes(child: c!); default: return c!; } }',
          ),
          isFalse,
        );
      });

      test('an if statement does not mount', () {
        expect(
          mounted(
            '(_, c) { if (on) { return AppThemeScopes(child: c!); } '
            'return c!; }',
          ),
          isFalse,
        );
      });

      test('a collection if does not mount', () {
        expect(
          mounted(
            '(_, c) => Column(children: '
            '[if (on) AppThemeScopes(child: c!) else c!])',
          ),
          isFalse,
        );
      });

      test('a conditional in a nested closure does not mount', () {
        expect(
          mounted(
            '(_, c) => Builder(builder: (_) => '
            'on ? AppThemeScopes(child: c!) : c!)',
          ),
          isFalse,
        );
      });

      test('a scope beside the child instead of around it does not mount', () {
        expect(
          mounted(
            '(_, c) => Stack(children: '
            '[AppThemeScopes(child: Overlay()), c!])',
          ),
          isFalse,
        );
        expect(mounted('(_, c) => AppThemeScopes(child: Home())'), isFalse);
      });

      test('a conditional below the scope, or after it, still mounts', () {
        expect(
          mounted(
            '(_, c) => AppThemeScopes(child: '
            'Column(children: [if (on) Banner(), c!]))',
          ),
          isTrue,
        );
        expect(
          mounted(
            '(_, c) { final s = AppThemeScopes(child: c!); '
            'return on ? s : Wrapper(child: s); }',
          ),
          isTrue,
        );
        expect(
          mounted(
            '(_, c) { if (on) { debug(); } '
            'return Stack(children: [AppThemeScopes(child: c!)]); }',
          ),
          isTrue,
        );
      });
    });

    test('an app under an import prefix is an app', () {
      const imports = "import 'package:flutter/material.dart' as m;\n";
      final apps = _apps(
        '${imports}void f() {\n'
        '  m.MaterialApp(home: Text("x"));\n'
        '  m.MaterialApp.router(routerConfig: r);\n'
        '  const m.CupertinoApp();\n'
        '  x.MaterialApp(home: Text("y"));\n'
        '  m.MaterialApp(builder: (_, c) => AppThemeScopes(child: c!));\n'
        '}\n',
      );
      expect(apps.map((a) => a.mounted), [false, false, false, true]);
      final readers = _readersOf([SourceFile('lib/a/x.dart', 'class X {}\n')]);
      const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
      expect(
        _unmountedReaderUses(
          readers,
          helpers,
          SourceFile(
            'test/t_test.dart',
            '${imports}void f() => m.MaterialApp(home: GptMarkdown("x"));\n',
          ),
        ),
        isNotEmpty,
      );
    });

    test('an import that is a raw string is read like any other', () {
      final file = SourceFile(
        'test/x_test.dart',
        "import r'package:hermes_app/a/probe.dart';\n"
            "import r'package:hermes_app/a.dart' as md;\n"
            "import r'package:hermes_app/b.dart' show B;\n",
      );
      expect(_importPrefixes(file), {'md'});
      final readers = _readersOf([
        SourceFile(
          'lib/a/probe.dart',
          'extension ProbeTheme on BuildContext {\n'
              '  Color get surface => mui.Theme.of(this).surface;\n'
              '}\n',
        ),
      ]);
      expect(_memberUses(readers, file, 'x.surface'), ['.surface']);
      final other = SourceFile('lib/b/user.dart', '');
      expect(_libraryOf(other), 'lib/b/user.dart');
      final part = SourceFile('lib/a/part.dart', "part of r'../a.dart';\n");
      expect(_libraryOf(part), 'lib/a.dart');
    });

    group('a reader nothing in the test refers to', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/md.dart',
          'class BoundedMarkdown extends StatelessWidget {\n'
              "  Widget build(BuildContext context) => GptMarkdown('x');\n"
              '}\n',
        ),
      ]);
      const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
      Set<String> uses(String body) => _unmountedReaderUses(
        readers,
        helpers,
        SourceFile('test/t_test.dart', body),
      );
      const textOnly =
          '  testWidgets("t", (t) async {\n'
          '    await t.pumpWidget(MaterialApp(home: Text("x")));\n'
          '  });\n';
      const mountedHost =
          'MaterialApp(builder: (_, child) => AppThemeScopes(child: child!), '
          'home: BoundedMarkdown("x"))';

      test('a mounted app built in a local helper of main is not blamed', () {
        expect(
          uses(
            'void main() {\n'
            '  Widget host() => $mountedHost;\n'
            '$textOnly'
            '}\n',
          ),
          isEmpty,
        );
      });

      test('a mounted app built in a top-level helper is not blamed', () {
        expect(
          uses(
            'Widget host() => $mountedHost;\n'
            'void main() {\n'
            '$textOnly'
            '}\n',
          ),
          isEmpty,
        );
      });

      test('a top-level class the test never mentions is not blamed', () {
        expect(
          uses(
            'class _Host {\n'
            '  Widget build() => BoundedMarkdown("x");\n'
            '}\n'
            'void main() {\n'
            '$textOnly'
            '}\n',
          ),
          isEmpty,
        );
      });

      test('a top-level value the test never mentions is not blamed', () {
        expect(
          uses(
            'final _cases = [BoundedMarkdown("x")];\n'
            'void main() {\n'
            '$textOnly'
            '}\n',
          ),
          isEmpty,
        );
      });

      test('a mounted app built in a setUp is not blamed', () {
        expect(
          uses(
            'void main() {\n'
            '  setUp(() {\n'
            '    app = $mountedHost;\n'
            '  });\n'
            '$textOnly'
            '}\n',
          ),
          isEmpty,
        );
      });

      test('one it reaches through another helper still counts', () {
        expect(
          uses(
            'Widget _a() => _b();\n'
            'Widget _b() => BoundedMarkdown("x");\n'
            'void main() {\n'
            '  testWidgets("t", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: _a()));\n'
            '  });\n'
            '}\n',
          ),
          {'BoundedMarkdown (reader built in a top-level helper at line 2)'},
        );
      });

      test('a loop over a named list the test reaches still counts', () {
        expect(
          uses(
            'final _cases = [BoundedMarkdown("x")];\n'
            'void main() {\n'
            '  for (final w in _cases) {\n'
            '    testWidgets("t", (t) async {\n'
            '      await t.pumpWidget(MaterialApp(home: w));\n'
            '    });\n'
            '  }\n'
            '}\n',
          ),
          isNotEmpty,
        );
      });
    });

    group('a scope that wraps an alias of the child', () {
      bool mounted(String builder) =>
          _apps('Object a() => MaterialApp(builder: $builder);').single.mounted;

      test('a widget built around the child and then scoped mounts', () {
        expect(
          mounted(
            '(_, child) { final w = MediaQuery(data: d, child: child!); '
            'return AppThemeScopes(child: w); }',
          ),
          isTrue,
        );
      });

      test('a plain local copy of the child mounts', () {
        expect(
          mounted(
            '(_, child) { final content = child!; '
            'return AppThemeScopes(child: content); }',
          ),
          isTrue,
        );
      });

      test('an alias of an alias mounts', () {
        expect(
          mounted(
            '(_, child) { final a = child!; final b = Pad(child: a); '
            'return AppThemeScopes(child: b); }',
          ),
          isTrue,
        );
      });

      test('a local that is not made of the child does not', () {
        expect(
          mounted(
            '(_, child) { final w = Other(); '
            'return AppThemeScopes(child: w); }',
          ),
          isFalse,
        );
      });
    });

    group('the child of the scope, and nothing else it takes', () {
      bool mounted(String builder) =>
          _apps('Object a() => MaterialApp(builder: $builder);').single.mounted;

      test('the child in a key does not mount', () {
        expect(
          mounted(
            '(_, c) => Stack(children: [AppThemeScopes('
            'key: ObjectKey(c), child: const SizedBox()), c!])',
          ),
          isFalse,
        );
      });

      test('the child as the child still mounts', () {
        expect(mounted('(_, c) => AppThemeScopes(child: c!)'), isTrue);
        expect(
          mounted('(_, c) => AppThemeScopes(key: ObjectKey(c), child: c!)'),
          isTrue,
        );
      });
    });

    group('a parse error', () {
      test('is reported for a file, and a fixture snippet is not one', () {
        final broken = SourceFile('lib/a/broken.dart', 'class {\n');
        expect(_syntaxErrors([broken]), isNotEmpty);
        expect(
          _syntaxErrors([broken]).first,
          startsWith('lib/a/broken.dart:1:'),
        );
        expect(
          _syntaxErrors([SourceFile('lib/a/ok.dart', 'class A {}\n')]),
          isEmpty,
        );
        final snippet = SourceFile(
          'test/t_test.dart',
          'await pump(MaterialApp(home: x));',
        );
        expect(_syntaxErrors([snippet]), isNotEmpty);
        expect(_apps(snippet.raw), hasLength(1));
      });
    });

    group('a finder that takes more than the type', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/md.dart',
          'class BoundedMarkdown extends StatelessWidget {\n'
              "  Widget build(BuildContext context) => GptMarkdown('x');\n"
              '}\n',
        ),
      ]);
      const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
      Set<String> uses(String body) => _unmountedReaderUses(
        readers,
        helpers,
        SourceFile('test/t_test.dart', body),
      );

      test('its type is not a use, with named arguments or without', () {
        expect(
          uses(
            'void f() {\n'
            '  MaterialApp(home: Text("x"));\n'
            '  expect(find.byType(BoundedMarkdown, skipOffstage: false),\n'
            '      findsNothing);\n'
            '  expect(find.byElementType(BoundedMarkdown), findsNothing);\n'
            '}\n',
          ),
          isEmpty,
        );
      });

      test('building the reader beside such a finder is a use', () {
        expect(
          uses(
            'void f() {\n'
            '  MaterialApp(home: BoundedMarkdown("x"));\n'
            '  expect(find.byType(BoundedMarkdown, skipOffstage: false),\n'
            '      findsOneWidget);\n'
            '}\n',
          ),
          {'BoundedMarkdown'},
        );
      });
    });

    test('an extension on a type with no name still holds its members', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/md.dart',
          'class BoundedMarkdown extends StatelessWidget {\n'
              "  Widget build(BuildContext context) => GptMarkdown('x');\n"
              '}\n',
        ),
        SourceFile(
          'lib/a/preview.dart',
          'extension FactoryPreview on Widget Function() {\n'
              "  Widget get preview => BoundedMarkdown('x');\n"
              '}\n'
              'class Plain {\n'
              '  Object build() => preview;\n'
              '}\n',
        ),
      ]);
      expect(readers.members.keys, contains('preview'));
      expect(readers.names, isNot(contains('Plain')));
      const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
      final file = SourceFile(
        'test/f_test.dart',
        "import 'package:hermes_app/a/preview.dart';\n"
            'Object f(Widget Function() factory) =>\n'
            '    MaterialApp(home: factory.preview);\n',
      );
      expect(_unmountedReaderUses(readers, helpers, file), {'.preview'});
    });

    group(
      'a reader built around the tests is reached by member and by word',
      () {
        final readers = _readersOf([
          SourceFile(
            'lib/a/md.dart',
            'class BoundedMarkdown extends StatelessWidget {\n'
                "  Widget build(BuildContext context) => GptMarkdown('x');\n"
                '}\n',
          ),
        ]);
        const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
        Set<String> uses(String body) => _unmountedReaderUses(
          readers,
          helpers,
          SourceFile('test/t_test.dart', body),
        );
        const pumpMd =
            'void main() {\n'
            '  testWidgets("t", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: t.md));\n'
            '  });\n'
            '}\n';

        test('a member of a named extension is reached by its member name', () {
          expect(
            uses(
              'extension _Md on WidgetTester {\n'
              '  Widget get md => BoundedMarkdown("x");\n'
              '}\n'
              '$pumpMd',
            ),
            isNotEmpty,
          );
        });

        test('a member of an unnamed extension is reached the same way', () {
          expect(
            uses(
              'extension on WidgetTester {\n'
              '  Widget get md => BoundedMarkdown("x");\n'
              '}\n'
              '$pumpMd',
            ),
            isNotEmpty,
          );
        });

        test(
          'a member another member of the type calls bare is reached too',
          () {
            expect(
              uses(
                'extension _Md on WidgetTester {\n'
                '  Widget get md => _inner;\n'
                '  Widget get _inner => BoundedMarkdown("x");\n'
                '}\n'
                '$pumpMd',
              ),
              isNotEmpty,
            );
          },
        );

        test('a member nothing refers to is not blamed', () {
          expect(
            uses(
              'extension _Md on WidgetTester {\n'
              '  Widget get other => BoundedMarkdown("x");\n'
              '}\n'
              'class _Host {\n'
              '  Widget get md => BoundedMarkdown("x");\n'
              '}\n'
              'void main() {\n'
              '  testWidgets("t", (t) async {\n'
              '    await t.pumpWidget(MaterialApp(home: Text("x")));\n'
              '  });\n'
              '}\n',
            ),
            isEmpty,
          );
        });

        test('a named argument label is not a reference', () {
          expect(
            uses(
              'Widget body() => BoundedMarkdown("x");\n'
              'void main() {\n'
              '  testWidgets("t", (t) async {\n'
              '    await t.pumpWidget(\n'
              '        MaterialApp(home: Scaffold(body: Text("x"))));\n'
              '  });\n'
              '}\n',
            ),
            isEmpty,
          );
        });

        test('a local inside a declaration is not a name of its own', () {
          expect(
            uses(
              'class _Host {\n'
              '  Widget build() {\n'
              '    final screen = BoundedMarkdown("x");\n'
              '    return screen;\n'
              '  }\n'
              '}\n'
              'void main() {\n'
              '  testWidgets("t", (t) async {\n'
              '    final screen = Text("x");\n'
              '    await t.pumpWidget(MaterialApp(home: screen));\n'
              '  });\n'
              '}\n',
            ),
            isEmpty,
          );
        });

        test('a type named in a constructor call is a reference', () {
          expect(
            uses(
              'class _Host extends StatelessWidget {\n'
              '  const _Host();\n'
              '  Widget build(BuildContext c) => BoundedMarkdown("x");\n'
              '}\n'
              'void main() {\n'
              '  testWidgets("t", (t) async {\n'
              '    await t.pumpWidget(MaterialApp(home: const _Host()));\n'
              '  });\n'
              '}\n',
            ),
            isNotEmpty,
          );
        });
      },
    );

    group('a scope around a local that is not the child on every path', () {
      bool mounted(String builder) =>
          _apps('Object a() => MaterialApp(builder: $builder);').single.mounted;

      test('a local reassigned under a condition does not mount', () {
        expect(
          mounted(
            '(_, child) { var w = child!; if (on) w = Other(); '
            'return AppThemeScopes(child: w); }',
          ),
          isFalse,
        );
      });

      test('a local whose value is a conditional does not mount', () {
        expect(
          mounted(
            '(_, child) { final w = on ? child! : Other(); '
            'return AppThemeScopes(child: w); }',
          ),
          isFalse,
        );
      });

      test('a local overwritten before the scope does not mount', () {
        expect(
          mounted(
            '(_, child) { var content = child!; '
            'content = const SizedBox(); '
            'return Stack(children: '
            '[AppThemeScopes(child: content), child!]); }',
          ),
          isFalse,
        );
      });

      test('an alias of such a local does not mount either', () {
        expect(
          mounted(
            '(_, child) { final w = on ? child! : Other(); '
            'final v = Pad(child: w); return AppThemeScopes(child: v); }',
          ),
          isFalse,
        );
      });

      test('a local that is only ever the child still mounts', () {
        expect(
          mounted(
            '(_, child) { final w = MediaQuery(data: d, child: child!); '
            'return AppThemeScopes(child: w); }',
          ),
          isTrue,
        );
      });
    });

    group('a member name that is also a common call', () {
      final readers = _readersOf([
        SourceFile(
          'lib/a/md.dart',
          'class BoundedMarkdown extends StatelessWidget {\n'
              "  Widget build(BuildContext context) => GptMarkdown('x');\n"
              '}\n',
        ),
      ]);
      const helpers = (mounting: <_Helper>[], plain: <_Helper>[]);
      Set<String> uses(String body) => _unmountedReaderUses(
        readers,
        helpers,
        SourceFile('test/t_test.dart', body),
      );
      String suite(String before, String inTest) =>
          '$before'
          'void main() {\n'
          '  testWidgets("t", (t) async {\n'
          '$inTest'
          '    await t.pumpWidget(MaterialApp(home: Text("x")));\n'
          '  });\n'
          '}\n';

      test('a text-only test that disposes is not blamed on a state class', () {
        expect(
          uses(
            suite(
              'class _HostState extends State<StatefulWidget> {\n'
                  '  Widget build(c) => BoundedMarkdown("x");\n'
                  '  void dispose() {}\n'
                  '}\n',
              '    addTearDown(c.dispose);\n',
            ),
          ),
          isEmpty,
        );
      });

      test('a text-only test that pumps is not blamed on a rig', () {
        expect(
          uses(
            suite(
              'class _Rig {\n'
                  '  Widget get screen => BoundedMarkdown("x");\n'
                  '  Future<void> pump(t) async {}\n'
                  '}\n',
              '    await t.pump();\n',
            ),
          ),
          isEmpty,
        );
      });

      test(
        'a bare call that shares an extension member name is not blamed',
        () {
          expect(
            uses(
              suite(
                'extension _Md on WidgetTester {\n'
                    '  Widget get md => BoundedMarkdown("x");\n'
                    '}\n',
                '    md();\n',
              ),
            ),
            isEmpty,
          );
        },
      );

      test('an instance held in a local of main still reaches its class', () {
        expect(
          uses(
            'class _Rig {\n'
            '  Widget get view => BoundedMarkdown("x");\n'
            '}\n'
            'void main() {\n'
            '  final rig = _Rig();\n'
            '  testWidgets("t", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: rig.view));\n'
            '  });\n'
            '}\n',
          ),
          isNotEmpty,
        );
      });

      test('an extension type member and an enum member reach their type', () {
        expect(
          uses(
            'extension type _Wrap(int v) {\n'
            '  Widget get shown => BoundedMarkdown("x");\n'
            '}\n'
            'void main() {\n'
            '  testWidgets("t", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: _Wrap(1).shown));\n'
            '  });\n'
            '}\n',
          ),
          isNotEmpty,
        );
        expect(
          uses(
            'enum _Case {\n'
            '  a;\n'
            '  Widget get shown => BoundedMarkdown("x");\n'
            '}\n'
            'void main() {\n'
            '  for (final c in _Case.values) {\n'
            '    testWidgets("t", (t) async {\n'
            '      await t.pumpWidget(MaterialApp(home: c.shown));\n'
            '    });\n'
            '  }\n'
            '}\n',
          ),
          isNotEmpty,
        );
      });

      test('a method call on an extension member reaches it', () {
        expect(
          uses(
            'extension _Md on WidgetTester {\n'
            '  Widget md() => BoundedMarkdown("x");\n'
            '}\n'
            'void main() {\n'
            '  testWidgets("t", (t) async {\n'
            '    await t.pumpWidget(MaterialApp(home: t.md()));\n'
            '  });\n'
            '}\n',
          ),
          isNotEmpty,
        );
      });
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

/// The app widgets the guard looks for, bare or under an import prefix
/// (`m.MaterialApp(`), with their `.router` constructor.
const _appNames = {'MaterialApp', 'CupertinoApp', 'WidgetsApp'};

/// Calls that mount a theme scope. `mui.Theme(` is the scope itself, not
/// `mui.Theme.of`.
const _mountNames = {
  'AppThemeScopes',
  'MaterialUiThemeScope',
  'FlyerMaterialScope',
};

/// A file with none of these words builds no app, so it is not parsed to look
/// for one.
final _appWord = RegExp(
  r'\b(?:MaterialApp|CupertinoApp|WidgetsApp|HermesApp)\b',
);

/// The calls that open a test, and the ones that set up a group.
const _testCallNames = {'test', 'testWidgets', 'group'};
const _setUpNames = {'setUp', 'setUpAll'};

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

// ---------------------------------------------------------------------------
// Syntax trees
// ---------------------------------------------------------------------------

/// A half-open range of offsets in a [_Parsed] source.
typedef _Span = ({int start, int end});

/// One reader found in a file: where, and what the source says there.
typedef _Hit = ({int offset, String text});

final _parsedFiles = Expando<_Parsed>('parsed');

/// The files the guard scans for real (`lib/` and `test/`), as opposed to the
/// fixtures' sources.
final _realFiles = <SourceFile>{...dartFiles('lib'), ...dartFiles('test')};

/// The syntax errors of every file in [files], as `path:line: message`.
List<String> _syntaxErrors(Iterable<SourceFile> files) => [
  for (final f in files) ..._parse(f).strictErrors,
];

/// [file] parsed once, without resolving anything.
_Parsed _parse(SourceFile file) => _parsedFiles[file] ??= _Parsed(file);

/// A source file as the analyzer's parser sees it. Nothing is resolved: the
/// guard sees names, not elements, which is why it works on the syntax tree
/// alone and needs no analysis context.
///
/// A fixture may be a bare statement list or an expression (`await pump();`,
/// `MaterialApp(...)`); such a snippet that does not parse as a unit is
/// wrapped in a function on its first line, so offsets and line numbers stay
/// those of the snippet.
class _Parsed {
  _Parsed._(this.view, this.unit, this.strictErrors);

  factory _Parsed(SourceFile file) {
    ParseStringResult parse(String content) => parseString(
      content: content,
      path: file.path,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    var result = parse(file.raw);
    var source = file.raw;
    final strictErrors = [
      for (final e in result.errors)
        '${file.path}:${result.lineInfo.getLocation(e.offset).lineNumber}: '
            '${e.message}',
    ];
    // Only a fixture may be a bare snippet: a real file that does not parse
    // is a finding, not something to wrap until it does.
    if (result.errors.isNotEmpty && !_realFiles.contains(file)) {
      const head = 'Future<void> __snippet() async { ';
      for (final tail in const ['\n}', ';\n}']) {
        final wrapped = parse('$head${file.raw}$tail');
        if (wrapped.errors.isEmpty) {
          result = wrapped;
          source = '$head${file.raw}$tail';
          break;
        }
      }
    }
    return _Parsed._(
      identical(source, file.raw) ? file : SourceFile(file.path, source),
      result.unit,
      strictErrors,
    );
  }

  /// The parsed text (the file, or the wrapped snippet) with its comment-free
  /// [SourceFile.code] view, which has the offsets of the tree.
  final SourceFile view;
  final CompilationUnit unit;

  /// What the parser reported for the text as it was given, `path:line:
  /// message`. Empty for every real file the guard reads.
  final List<String> strictErrors;

  String get code => view.code;

  late final _Index index = _Index.of(unit);

  /// The `as` prefixes this file's imports declare.
  late final Set<String> prefixes = {
    for (final d in unit.directives.whereType<ImportDirective>())
      if (d.prefix != null) d.prefix!.name,
  };

  /// `code` without the arguments of finders (`find.byType(X)`,
  /// `find.byWidgetPredicate(...)`): a test that only looks for a reader by
  /// type, often to assert there is none, does not render it.
  late final String masked = _mask();

  String _mask() {
    final cuts = <_Span>[];
    for (final call in index.calls) {
      final target = call.target;
      if (call.isCascaded || target is! SimpleIdentifier) continue;
      if (target.name != 'find') continue;
      switch (call.methodName.name) {
        case 'byWidgetPredicate':
          cuts.add((start: call.offset, end: call.end));
        case 'byType' || 'byElementType':
          final type = call.argumentList.arguments
              .where((a) => a is! NamedArgument)
              .firstOrNull;
          if (type is SimpleIdentifier ||
              type is PrefixedIdentifier ||
              type is PropertyAccess) {
            cuts.add((start: type!.offset, end: type.end));
          }
      }
    }
    if (cuts.isEmpty) return code;
    final out = StringBuffer();
    var at = 0;
    cuts.sort((a, b) => a.start.compareTo(b.start));
    for (final cut in cuts) {
      if (cut.start < at) continue;
      out.write(code.substring(at, cut.start));
      out.write(
        code.substring(cut.start, cut.end).replaceAll(RegExp(r'[^\n]'), ' '),
      );
      at = cut.end;
    }
    out.write(code.substring(at));
    return out.toString();
  }

  /// Every app built in the file, and whether it mounts the theme scopes.
  /// `HermesApp` is the real app and always does.
  late final List<_App> apps = _findApps(this);

  /// The `AppThemeScopes(` calls of the file.
  late final int scopeCalls = [
    for (final c in [...index.calls, ...index.creations])
      if (_shapes(c).any((s) => s.named == null && s.type == 'AppThemeScopes'))
        c,
  ].length;

  /// The `test`, `testWidgets` and `group` calls, and the `setUp` and
  /// `setUpAll` calls, of the file.
  late final List<MethodInvocation> testCalls = [
    for (final c in index.calls)
      if (_plainCall(c, _testCallNames)) c,
  ];
  late final List<MethodInvocation> setUpCalls = [
    for (final c in index.calls)
      if (_plainCall(c, _setUpNames)) c,
  ];

  /// The 1-based line of [offset].
  int lineOf(int offset) => view.lineOf(offset);
}

/// Whether [call] is a call of one of [names] with no target: `test(...)`.
bool _plainCall(MethodInvocation call, Set<String> names) =>
    call.target == null &&
    !call.isCascaded &&
    names.contains(call.methodName.name);

/// What the syntax tree of one file holds that the guard looks up: its calls
/// and constructions, the functions and methods it declares by name (what a
/// `builder: _scoped` tear-off points to) and its loops.
class _Index extends RecursiveAstVisitor<void> {
  _Index.of(CompilationUnit unit) {
    unit.accept(this);
  }

  final calls = <MethodInvocation>[];
  final creations = <InstanceCreationExpression>[];
  final functions =
      <String, List<({FormalParameterList? parameters, FunctionBody body})>>{};
  final loops = <AstNode>[];

  /// What a name can stand for: a function, a variable or a type declared in
  /// the file, with its range, the names it answers to and, for an extension,
  /// its members. A type is reached by its name alone; an extension has no
  /// name to use, so `t.md` reaches its getter `md` (see [accesses]). A reader
  /// built inside one is drawn only by what refers to one of those.
  final bindings = <({Set<String> names, Set<String> members, _Span span})>[];

  /// The member of every access: `md` in `x.md` or `t.md()`. Only an access
  /// reaches a member of an extension, never a bare call that shares its name
  /// (`pump()`, `dispose`).
  final accesses = <({String name, int offset})>[];

  /// Every name the file refers to, as the tree has it: an identifier or the
  /// name of a type. A label (`body:`) and a declared name are not references.
  final references = <({String name, int offset})>[];

  void _bind(
    Iterable<String> names,
    AstNode node, {
    Iterable<String> members = const [],
  }) => bindings.add((
    names: {...names},
    members: {...members},
    span: (start: node.offset, end: node.end),
  ));

  static Iterable<String> _memberNames(Iterable<ClassMember> members) => [
    for (final m in members)
      if (m is MethodDeclaration)
        m.name.lexeme
      else if (m is FieldDeclaration)
        for (final v in m.fields.variables) v.name.lexeme,
  ];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    references.add((name: node.name, offset: node.offset));
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    accesses.add((name: node.identifier.name, offset: node.identifier.offset));
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    accesses.add((
      name: node.propertyName.name,
      offset: node.propertyName.offset,
    ));
    super.visitPropertyAccess(node);
  }

  @override
  void visitNamedType(NamedType node) {
    references.add((name: node.name.lexeme, offset: node.offset));
    super.visitNamedType(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _bind([node.name.lexeme], node);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _bind([node.namePart.typeName.lexeme], node);
    super.visitClassDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _bind([node.name.lexeme], node);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _bind([node.namePart.typeName.lexeme], node);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    _bind([node.namePart.typeName.lexeme], node);
    super.visitExtensionTypeDeclaration(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    _bind(
      [if (node.name != null) node.name!.lexeme],
      node,
      members: _memberNames(node.body.members),
    );
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    calls.add(node);
    if (node.realTarget != null) {
      accesses.add((
        name: node.methodName.name,
        offset: node.methodName.offset,
      ));
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    creations.add(node);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.name.lexeme != 'main') _bind([node.name.lexeme], node);
    if (!node.isGetter && !node.isSetter) {
      final f = node.functionExpression;
      (functions[node.name.lexeme] ??= []).add((
        parameters: f.parameters,
        body: f.body,
      ));
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!node.isGetter && !node.isSetter && !node.isOperator) {
      (functions[node.name.lexeme] ??= []).add((
        parameters: node.parameters,
        body: node.body,
      ));
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    loops.add(node);
    super.visitForStatement(node);
  }

  @override
  void visitForElement(ForElement node) {
    loops.add(node);
    super.visitForElement(node);
  }
}

/// How a call reads, as the parser leaves it. Unresolved, `a.B(` is either the
/// constructor of `B` under the import prefix `a` or the named constructor
/// `B` of the type `a`, so a call has up to two shapes.
typedef _Shape = ({String? qualifier, String type, String? named});

List<_Shape> _shapes(AstNode node) {
  if (node is InstanceCreationExpression) {
    final type = node.constructorName.type;
    return [
      (
        qualifier: type.importPrefix?.name.lexeme,
        type: type.name.lexeme,
        named: node.constructorName.name?.name,
      ),
    ];
  }
  if (node is MethodInvocation && !node.isCascaded) {
    final target = node.target;
    final name = node.methodName.name;
    if (target == null) return [(qualifier: null, type: name, named: null)];
    if (target is SimpleIdentifier) {
      return [
        (qualifier: target.name, type: name, named: null),
        (qualifier: null, type: target.name, named: name),
      ];
    }
    if (target is PrefixedIdentifier) {
      return [
        (
          qualifier: target.prefix.name,
          type: target.identifier.name,
          named: name,
        ),
      ];
    }
  }
  return const [];
}

/// An app built in a source: where, whether its `builder:` mounts a scope,
/// the text of its arguments, and whether it is the real `HermesApp`.
typedef _App = ({
  int start,
  bool mounted,
  String args,
  int argsStart,
  int argsEnd,
  bool hermes,
});

/// Every app built in [code]; [code] may be a snippet.
List<_App> _apps(String code) => _parse(SourceFile('snippet.dart', code)).apps;

/// The apps of [p] that start in [span] (all of them by default).
List<_App> _appsIn(_Parsed p, [_Span? span]) => [
  for (final a in p.apps)
    if (span == null || (a.start >= span.start && a.start < span.end)) a,
];

List<_App> _findApps(_Parsed p) {
  final out = <_App>[];
  void look(AstNode node, ArgumentList args) {
    for (final s in _shapes(node)) {
      if (s.qualifier != null && !p.prefixes.contains(s.qualifier)) continue;
      final hermes = s.type == 'HermesApp' && s.named == null;
      final app =
          _appNames.contains(s.type) &&
          (s.named == null || s.named == 'router');
      if (!hermes && !app) continue;
      out.add((
        start: node.offset,
        mounted: hermes || _constructorMounts(p, args),
        args: hermes
            ? ''
            : p.code.substring(
                args.leftParenthesis.end,
                args.rightParenthesis.offset,
              ),
        argsStart: args.leftParenthesis.end,
        argsEnd: args.rightParenthesis.offset,
        hermes: hermes,
      ));
      return;
    }
  }

  for (final c in p.index.calls) {
    look(c, c.argumentList);
  }
  for (final c in p.index.creations) {
    look(c, c.argumentList);
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// Whether the app whose arguments are [args] mounts a scope in its
/// `builder:`. A scope in `home:` does not count: a route pushed from `home`
/// is built outside it.
bool _constructorMounts(_Parsed p, ArgumentList args) {
  for (final a in args.arguments) {
    if (a is NamedArgument && a.name.lexeme == 'builder') {
      return _builderMounts(p, a.argumentExpression);
    }
  }
  return false;
}

/// Whether the `builder:` value [e] wraps the app's child in a scope: a
/// function literal, or a tear-off of a function or method declared in the
/// same file (every declaration of that name has to).
bool _builderMounts(_Parsed p, Expression e) {
  var value = e;
  while (value is ParenthesizedExpression) {
    value = value.expression;
  }
  if (value is FunctionExpression) {
    return _bodyMounts(value.body, value.parameters);
  }
  final name = switch (value) {
    SimpleIdentifier() => value.name,
    PrefixedIdentifier() => value.identifier.name,
    PropertyAccess() => value.propertyName.name,
    _ => null,
  };
  final targets = name == null ? null : p.index.functions[name];
  return targets != null &&
      targets.isNotEmpty &&
      targets.every((t) => _bodyMounts(t.body, t.parameters));
}

/// Whether [body], the body of a builder with [parameters] (`context, child`),
/// has a scope call that wraps the child and does not sit in a conditional.
bool _bodyMounts(FunctionBody body, FormalParameterList? parameters) {
  final child = _childParameter(parameters);
  if (child == null) return false;
  final names = _aliases(body, child);
  final finder = _ScopeCalls();
  body.accept(finder);
  return finder.scopes.any(
    (scope) => !_inConditional(scope, body) && _wrapsChild(scope, names),
  );
}

/// Whether the `child:` of the scope call [scope], and nothing else it takes
/// (a `key:`, say), uses one of [names].
bool _wrapsChild(AstNode scope, Set<String> names) {
  final args = switch (scope) {
    MethodInvocation() => scope.argumentList,
    InstanceCreationExpression() => scope.argumentList,
    _ => null,
  };
  if (args == null) return false;
  for (final a in args.arguments) {
    if (a is NamedArgument && a.name.lexeme == 'child') {
      return names.any((n) => _mentions(a.argumentExpression, n));
    }
  }
  return false;
}

/// [child] and every local variable of [body] whose initializer uses a name
/// already in the set (`final content = child!;`), to a fixpoint.
Set<String> _aliases(FunctionBody body, String child) {
  final vars = _Variables();
  body.accept(vars);
  // A local that is assigned again, or whose value depends on a condition, is
  // not the child on every path.
  final eligible = [
    for (final v in vars.found)
      if (!vars.assigned.contains(v.name.lexeme) &&
          !_hasConditional(v.initializer!))
        v,
  ];
  final names = {child};
  var grew = true;
  while (grew) {
    grew = false;
    for (final v in eligible) {
      if (names.contains(v.name.lexeme)) continue;
      if (names.any((n) => _mentions(v.initializer!, n))) {
        names.add(v.name.lexeme);
        grew = true;
      }
    }
  }
  return names;
}

/// Whether a `?:`, a `switch` or a collection `if` is anywhere in [node].
bool _hasConditional(AstNode node) {
  final finder = _Conditionals();
  node.accept(finder);
  return finder.found;
}

class _Conditionals extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    found = true;
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    found = true;
  }

  @override
  void visitIfElement(IfElement node) {
    found = true;
  }
}

class _Variables extends RecursiveAstVisitor<void> {
  final found = <VariableDeclaration>[];

  /// The names assigned to after their declaration: `w = Other();`.
  final assigned = <String>{};

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final target = node.leftHandSide;
    if (target is SimpleIdentifier) assigned.add(target.name);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.initializer != null) found.add(node);
    super.visitVariableDeclaration(node);
  }
}

/// The name of the second positional parameter of a builder: the child.
String? _childParameter(FormalParameterList? parameters) {
  if (parameters == null) return null;
  final positional = [
    for (final p in parameters.parameters)
      if (p.isPositional) p,
  ];
  if (positional.length < 2) return null;
  final name = positional[1].name?.lexeme;
  return name == null || name == '_' ? null : name;
}

class _ScopeCalls extends RecursiveAstVisitor<void> {
  final scopes = <AstNode>[];

  void _check(AstNode node) {
    final scope = _shapes(node).any(
      (s) =>
          s.named == null &&
          (_mountNames.contains(s.type) ||
              (s.qualifier == 'mui' && s.type == 'Theme')),
    );
    if (scope) scopes.add(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _check(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(node);
    super.visitInstanceCreationExpression(node);
  }
}

/// Whether [node] uses the identifier [name] anywhere below it.
bool _mentions(AstNode node, String name) {
  final finder = _Mentions(name);
  node.accept(finder);
  return finder.found;
}

class _Mentions extends RecursiveAstVisitor<void> {
  _Mentions(this.name);
  final String name;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) found = true;
  }
}

/// Whether a conditional (`?:`, `switch`, `if`, collection `if`) sits between
/// [node] and [root]: a scope behind one does not mount on every path.
bool _inConditional(AstNode node, AstNode root) {
  for (var n = node.parent; n != null && n != root; n = n.parent) {
    if (n is ConditionalExpression ||
        n is SwitchExpression ||
        n is SwitchStatement ||
        n is IfElement ||
        n is IfStatement) {
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Which readers an app draws
// ---------------------------------------------------------------------------

/// The readers a test file refers to when it builds an unmounted app of its
/// own or calls a helper whose app is unmounted, else none. The readers a
/// plain helper renders count as uses of every caller.
Set<String> _unmountedReaderUses(
  _Readers readers,
  _Helpers helpers,
  SourceFile file, {
  List<_Exemption> exemptions = const [],
}) {
  final plainCalled = helpers.plain
      .where((h) => h.calledIn(file.code))
      .toList();
  if (plainCalled.isEmpty && !_appWord.hasMatch(file.raw)) return const {};
  final p = _parse(file);
  final unmounted = [
    for (final a in p.apps)
      if (!a.mounted &&
          !exemptions.any(
            (e) => e.path == file.path && a.args.contains(e.appContains),
          ))
        a,
  ];
  if (unmounted.isEmpty && plainCalled.isEmpty) return const {};
  return {
    // A helper's app is drawn wherever it is called: the whole file counts.
    if (plainCalled.isNotEmpty) ..._readerUses(readers, file),
    // An app of the file's own draws what its test builds, and what is built
    // around its tests: in the `setUp` of a group it is in, in a local of
    // `main` or a group, in a loop over widgets, in a top-level helper.
    for (final a in unmounted) ..._attributedUses(readers, file, a.start),
    for (final h in plainCalled)
      for (final use in h.uses) '$use (via ${h.name})',
  };
}

/// What an unmounted app at [offset] draws. The app is drawn by its test (the
/// narrowest `test`, `testWidgets` or `group` callback around it, or the whole
/// file when it is in none) and by everything built around the tests of the
/// groups it is in: `setUp`, `setUpAll`, locals, loops, and top-level helpers.
/// Sibling tests and groups are not part of that, so a test that only
/// localizes a text beside one that reads the theme stays clean. A reader
/// built around the tests is reported with where it is built.
Set<String> _attributedUses(_Readers readers, SourceFile file, int offset) {
  final p = _parse(file);
  final hits = _hitsOf(readers, file);
  final chain = [
    for (final c in p.testCalls)
      if (c.offset <= offset && offset < c.end) c,
  ]..sort((a, b) => (b.end - b.offset).compareTo(a.end - a.offset));
  if (chain.isEmpty) {
    return {for (final h in hits) h.text};
  }
  final own = (start: chain.last.offset, end: chain.last.end);
  final around = <({_Span span, String origin})>[
    for (final g in chain.take(chain.length - 1))
      for (final s in _ambient(p, (start: g.offset, end: g.end)))
        (span: s, origin: 'a group'),
    for (final d in p.unit.declarations)
      for (final s in _ambient(p, (start: d.offset, end: d.end)))
        (
          span: s,
          origin: d is FunctionDeclaration && d.name.lexeme == 'main'
              ? 'main'
              : 'a top-level helper',
        ),
  ];
  bool inAroundSpan(int offset) =>
      around.any((r) => offset >= r.span.start && offset < r.span.end);
  bool inAround(AstNode n) => inAroundSpan(n.offset);
  // What the test refers to by name: in its own callback, in the `setUp` and
  // `setUpAll` around it and in the loops that make it, and, to a fixpoint, in
  // whatever those refer to.
  final seeds = [
    own,
    for (final n in [...p.setUpCalls, ...p.index.loops].where(inAround))
      (start: n.offset, end: n.end),
  ];
  final referenced = <String>{for (final r in seeds) ..._names(p, r)};
  final accessed = <String>{for (final r in seeds) ..._accessed(p, r)};
  bool reaches(({Set<String> names, Set<String> members, _Span span}) b) =>
      b.names.any(referenced.contains) || b.members.any(accessed.contains);
  // Only a declaration around the tests is followed (a top-level one, or a
  // local of `main` or a group), and as a whole: what it holds is its own.
  final outer = [
    for (final b in p.index.bindings)
      if (_outermost(p, b.span) && inAroundSpan(b.span.start)) b,
  ];
  for (var grew = true; grew;) {
    grew = false;
    for (final b in outer) {
      if (reaches(b)) {
        for (final n in _names(p, b.span)) {
          grew |= referenced.add(n);
        }
        for (final n in _accessed(p, b.span)) {
          grew |= accessed.add(n);
        }
      }
    }
  }
  // A reader built around the tests counts when a `setUp`, `setUpAll` or loop
  // builds it, or when the declaration that builds it is referred to. One in
  // an app's own arguments belongs to that app, which is judged on its own.
  bool counts(_Hit h, String origin) {
    if (p.apps.any((a) => h.offset >= a.argsStart && h.offset < a.argsEnd)) {
      return false;
    }
    if (_builtIn(p, h.offset, origin) != origin) return true;
    // Judged by the outermost declaration that holds it: a local inside a
    // class or function is that declaration's, not a name of its own.
    final holders = [
      for (final b in p.index.bindings)
        if (h.offset >= b.span.start && h.offset < b.span.end) b,
    ]..sort((a, b) => a.span.start.compareTo(b.span.start));
    return holders.isEmpty || reaches(holders.first);
  }

  return {
    for (final h in hits)
      if (h.offset >= own.start && h.offset < own.end) h.text,
    for (final r in around)
      for (final h in hits)
        if (h.offset >= r.span.start &&
            h.offset < r.span.end &&
            counts(h, r.origin))
          '${h.text} (reader built in ${_builtIn(p, h.offset, r.origin)} '
              'at line ${p.lineOf(h.offset)})',
  };
}

/// The names [p] refers to in [span].
Set<String> _names(_Parsed p, _Span span) => {
  for (final r in p.index.references)
    if (r.offset >= span.start && r.offset < span.end) r.name,
};

/// The members [p] accesses in [span] (`md` in `t.md`).
Set<String> _accessed(_Parsed p, _Span span) => {
  for (final r in p.index.accesses)
    if (r.offset >= span.start && r.offset < span.end) r.name,
};

/// Whether no other declaration of [p] holds [span].
bool _outermost(_Parsed p, _Span span) => !p.index.bindings.any(
  (o) =>
      o.span.start <= span.start &&
      o.span.end >= span.end &&
      (o.span.start != span.start || o.span.end != span.end),
);

/// [span] without the `test`, `testWidgets` and `group` calls in it that no
/// other such call in it holds: what is built around the tests of a group.
List<_Span> _ambient(_Parsed p, _Span span) {
  final inside = [
    for (final c in p.testCalls)
      if (c.offset >= span.start &&
          c.end <= span.end &&
          !(c.offset == span.start && c.end == span.end))
        c,
  ]..sort((a, b) => a.offset.compareTo(b.offset));
  final out = <_Span>[];
  var at = span.start;
  for (final c in inside) {
    if (c.offset < at) continue;
    if (c.offset > at) out.add((start: at, end: c.offset));
    at = c.end;
  }
  if (at < span.end) out.add((start: at, end: span.end));
  return out;
}

/// What builds the reader at [offset]: the narrowest `setUp`, `setUpAll` or
/// loop around it, else [origin].
String _builtIn(_Parsed p, int offset, String origin) {
  String? best;
  var size = 1 << 62;
  void consider(AstNode n, String label) {
    if (n.offset <= offset && offset < n.end && n.end - n.offset < size) {
      best = label;
      size = n.end - n.offset;
    }
  }

  for (final c in p.setUpCalls) {
    consider(c, c.methodName.name);
  }
  for (final l in p.index.loops) {
    consider(l, 'a for loop');
  }
  return best ?? origin;
}

/// The readers [file] (a test or a helper file) refers to in [within] (all of
/// it by default), finders aside: names and prefixed names, the seeds
/// themselves (`GptMarkdown(`, `mui.Theme.of`) and the extension members it
/// can see.
Set<String> _readerUses(_Readers readers, SourceFile file, {_Span? within}) => {
  for (final h in _hitsOf(readers, file))
    if (within == null || (h.offset >= within.start && h.offset < within.end))
      h.text,
};

final _hitCache = Expando<(Object, List<_Hit>)>('hits');

/// Every reader reference in [file], by offset.
List<_Hit> _hitsOf(_Readers readers, SourceFile file) {
  final cached = _hitCache[file];
  if (cached != null && identical(cached.$1, readers.names)) return cached.$2;
  final text = _parse(file).masked;
  final hits = <_Hit>[
    if (readers.names.isNotEmpty)
      for (final m in _wordsPattern(
        readers.names,
        prefixes: _importPrefixes(file),
      ).allMatches(text))
        (offset: m.start, text: m.group(0)!),
    for (final m in _testSeed.allMatches(text))
      (offset: m.start, text: m.group(0)!),
    ..._memberHits(readers, file, text),
  ]..sort((a, b) => a.offset.compareTo(b.offset));
  _hitCache[file] = (readers.names, hits);
  return hits;
}

/// The readers helper [d] renders itself. A class counts only the members
/// that build an unmounted app, and the members those call by bare name (to a
/// fixpoint): a rig with a scoped method and an unscoped one that pumps text is
/// no reader use for a test that calls the second.
Set<String> _ownUses(_Readers readers, SourceFile file, _Decl d) {
  if (!d.isType) {
    return _readerUses(readers, file, within: (start: d.offset, end: d.end));
  }
  final p = _parse(file);
  final named = <String, ClassMember>{};
  for (final m in d.members) {
    final name = switch (m) {
      MethodDeclaration() => m.name.lexeme,
      FieldDeclaration() => m.fields.variables.first.name.lexeme,
      ConstructorDeclaration() => m.name?.lexeme ?? m.typeName?.name,
      _ => null,
    };
    if (name != null) named[name] = m;
  }
  String text(ClassMember m) => p.code.substring(m.offset, m.end);
  _Span span(ClassMember m) => (start: m.offset, end: m.end);
  final counted = <String>{
    for (final e in named.entries)
      if (_appsIn(p, span(e.value)).any((a) => !a.mounted)) e.key,
  };
  var grew = true;
  while (grew) {
    grew = false;
    for (final name in counted.toList()) {
      for (final e in named.entries) {
        if (!counted.contains(e.key) &&
            e.key != name &&
            RegExp('(?<![\\w.\$])${e.key}\\b').hasMatch(text(named[name]!))) {
          counted.add(e.key);
          grew = true;
        }
      }
    }
  }
  return {
    for (final name in counted)
      ..._readerUses(readers, file, within: span(named[name]!)),
  };
}

/// The `.member` uses in [code] of extension members declared in a library
/// that [file] imports.
Iterable<String> _memberUses(_Readers readers, SourceFile file, String code) =>
    _memberHits(readers, file, code).map((h) => h.text);

Iterable<_Hit> _memberHits(_Readers readers, SourceFile file, String code) {
  final imported = _importsOf(file);
  final visible = [
    for (final e in readers.members.entries)
      if (e.value.any(imported.contains)) e.key,
  ];
  if (visible.isEmpty) return const [];
  return RegExp('\\.\\s*(?:${visible.join('|')})\\b')
      .allMatches(code)
      .map((m) => (offset: m.start, text: m.group(0)!));
}

/// The `as` prefixes of the imports of [file].
Set<String> _importPrefixes(SourceFile file) => _parse(file).prefixes;

/// The library [file] belongs to: its `part of` target, or itself.
String _libraryOf(SourceFile file) {
  for (final d in _parse(file).unit.directives.whereType<PartOfDirective>()) {
    final uri = d.uri?.stringValue;
    if (uri != null) return Uri(path: file.path).resolve(uri).path;
  }
  return file.path;
}

/// The repo paths [file] imports: `package:hermes_app/` and relative imports.
/// The URI is read from the string literal, so a raw string works too.
Set<String> _importsOf(SourceFile file) => {
  for (final d in _parse(file).unit.directives.whereType<ImportDirective>())
    if (d.uri.stringValue case final uri?)
      if (uri.startsWith('package:hermes_app/'))
        'lib/${uri.substring('package:hermes_app/'.length)}'
      else if (!uri.contains(':'))
        Uri(path: file.path).resolve(uri).path,
};

/// One top-level declaration of a source file.
class _Decl {
  _Decl(this.file, this.node, this.name, {this.on});

  final SourceFile file;
  final CompilationUnitMember node;
  final String name;

  /// The type an extension extends.
  final String? on;

  String get path => file.path;
  int get offset => node.offset;
  int get end => node.end;

  /// The comment-free text of the declaration.
  late final String body = _parse(file).code.substring(offset, end);

  /// A class, mixin, enum or extension type: a declaration with members.
  bool get isExtension => node is ExtensionDeclaration;

  bool get isType =>
      node is ClassDeclaration ||
      node is ClassTypeAlias ||
      node is MixinDeclaration ||
      node is EnumDeclaration ||
      node is ExtensionTypeDeclaration;

  /// The members of a type or an extension, from the syntax tree.
  List<ClassMember> get members => switch (node) {
    ClassDeclaration(:final body) => body.members.toList(),
    MixinDeclaration(:final body) => body.members.toList(),
    ExtensionTypeDeclaration(:final body) => body.members.toList(),
    ExtensionDeclaration(:final body) => body.members.toList(),
    EnumDeclaration(:final body) =>
      body is BlockEnumBody ? body.members.toList() : const [],
    _ => const [],
  };

  /// The getters, setters and methods an extension declares.
  Set<String> get memberNames => {
    for (final m in members)
      if (m is MethodDeclaration && !m.isOperator) m.name.lexeme,
  };

  /// The library the declaration belongs to, so a private name is shared with
  /// the `part` files of its library and with nothing else.
  late String library = path;

  /// What the library imports (resolved repo paths) and the prefixes it
  /// imports under.
  Set<String> imports = const {};
  Set<String> prefixes = const {};
}

/// Every top-level class, mixin, enum, extension, function, getter and
/// variable of [file].
List<_Decl> _declarations(SourceFile file) {
  final out = <_Decl>[];
  for (final m in _parse(file).unit.declarations) {
    switch (m) {
      case ClassDeclaration():
        out.add(_Decl(file, m, m.namePart.typeName.lexeme));
      case EnumDeclaration():
        out.add(_Decl(file, m, m.namePart.typeName.lexeme));
      case ExtensionTypeDeclaration():
        out.add(_Decl(file, m, m.namePart.typeName.lexeme));
      case MixinDeclaration():
        out.add(_Decl(file, m, m.name.lexeme));
      case ClassTypeAlias():
        out.add(_Decl(file, m, m.name.lexeme));
      case ExtensionDeclaration():
        final extended = m.onClause?.extendedType;
        final on = extended is NamedType ? extended.name.lexeme : null;
        out.add(_Decl(file, m, m.name?.lexeme ?? 'extension_on_$on', on: on));
      case FunctionDeclaration():
        final name = m.name.lexeme;
        if (name != 'main') out.add(_Decl(file, m, name));
      case TopLevelVariableDeclaration():
        for (final v in m.variables.variables) {
          out.add(_Decl(file, m, v.name.lexeme));
        }
      default:
        break;
    }
  }
  return out;
}

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
      _appsIn(_parse(d.file), (
        start: d.offset,
        end: d.end,
      )).any((a) => !a.hermes) ||
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
    if (d.isExtension) {
      // An extension is reached through its members, `context.view` from
      // anywhere that sees it, or a bare `view` in the body of the type it
      // extends. Its receiver is not a reader just for being extended. Its
      // members count whatever it extends, a type with no name (`Widget
      // Function()`) included; only a named receiver is compared.
      for (final member in d.memberNames) {
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
              (d.on != null &&
                  (other.name == d.on || other.on == d.on) &&
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
  final mounting = <String, _Helper>{};
  final plain = <String, _Helper>{};
  var changed = true;
  while (changed) {
    changed = false;
    for (final d in decls) {
      if (plain.containsKey(d.name)) continue;
      final helper = _Helper(d.name, d.isType);
      final apps = _appsIn(_parse(d.file), (start: d.offset, end: d.end));
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
        if (plain.containsKey(d.name)) d.name: _ownUses(readers, d.file, d),
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

/// Collects every node of a tree, for the analyzer API canary.
class _Collect extends GeneralizingAstVisitor<void> {
  _Collect(this.nodes);
  final List<AstNode> nodes;

  @override
  void visitNode(AstNode node) {
    nodes.add(node);
    super.visitNode(node);
  }
}
