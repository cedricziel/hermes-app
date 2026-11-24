import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart' show CodeBlockStyle;
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';

import '../support/rebuild_probe.dart';

/// Every field of the style set, so that a variant of one field is visible.
const _baseStyle = CodeBlockStyle(
  backgroundColor: Color(0xFF101010),
  borderColor: Color(0xFF202020),
  borderWidth: 1,
  borderRadius: Radius.circular(12),
  padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
  headerPadding: EdgeInsets.fromLTRB(10, 8, 8, 2),
  fontFamily: 'Courier',
  fontSize: 13,
  textColor: Color(0xFFAAAAAA),
  showLanguageLabel: true,
  languageStyle: TextStyle(fontSize: 11, color: Color(0xFF303030)),
  showCopyButton: true,
  copyLabel: 'Copy code',
  copiedLabel: 'Copied!',
  highlightWhileStreaming: true,
);

class _Config {
  const _Config({
    this.name = 'python',
    this.codes = 'def f(x):\n    return x + 1\n',
    this.style = _baseStyle,
    this.highlight = true,
    this.scales = false,
  });
  final String name;
  final String codes;
  final CodeBlockStyle style;
  final bool highlight;
  final bool scales;

  HermesCodeBlock build() => HermesCodeBlock(
    name: name,
    codes: codes,
    style: style,
    highlightCode: highlight,
    scalesItsOwnText: scales,
  );
}

/// What a test changes between two pumps: the block's config and the ambient
/// inherited widgets around it.
class _Env {
  _Env({this.config = const _Config(), this.iconOpacity});
  _Config config;
  ThemeData? theme;
  double textScale = 1.0;
  TextDirection direction = TextDirection.ltr;
  double? iconOpacity;
  Locale locale = const Locale('en');
}

late StateSetter _setEnv;

Future<void> _mount(WidgetTester tester, _Env env) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      builder: (_, child) => AppThemeScopes(child: child!),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            _setEnv = setState;
            Widget child = Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 400, child: env.config.build()),
            );
            if (env.iconOpacity != null) {
              child = IconTheme(
                data: IconThemeData(opacity: env.iconOpacity),
                child: child,
              );
            }
            return Localizations.override(
              context: context,
              locale: env.locale,
              child: Theme(
                data: env.theme ?? Theme.of(context),
                child: Directionality(
                  textDirection: env.direction,
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(env.textScale)),
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// Applies [change], pumps, and returns how many elements below the block
/// rebuilt.
Future<int> _change(WidgetTester tester, void Function() change) async {
  final counts = await countRebuildsBelow<HermesCodeBlock>(() async {
    _setEnv(change);
    await tester.pump();
  });
  return counts.inside;
}

/// The element tree of the block as text, without object hashes.
String _shown(WidgetTester tester) => tester
    .element(find.byType(HermesCodeBlock))
    .toStringDeep()
    .replaceAll(RegExp(r'#[0-9a-f]{5}'), '#');

/// The size of the code text itself (the block fills the height it is given).
Size _codeSize(WidgetTester tester) => tester.getSize(
  find.descendant(
    of: find.byType(HermesCodeBlock),
    matching: find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().startsWith('def f'),
    ),
  ),
);

/// The first frames after mounting rebuild the focus widgets of the copy
/// button once (focus scope and highlight mode settle); not what is measured.
Future<void> _settle(WidgetTester tester) async {
  _setEnv(() {});
  await tester.pump();
  await tester.pump();
}

Finder get _copy => find.bySemanticsLabel(RegExp('^(Copy code|Copied!)'));

void main() {
  testWidgets('an equal config does not rebuild the subtree', (tester) async {
    final env = _Env();
    await _mount(tester, env);
    await _settle(tester);
    final before = _shown(tester);
    final rebuilt = await _change(tester, () {
      env.config = const _Config(); // an equal config in a new widget
    });
    expect(rebuilt, 0);
    expect(_shown(tester), before);
  });

  testWidgets('an equal style held in a new object does not rebuild', (
    tester,
  ) async {
    final env = _Env();
    await _mount(tester, env);
    await _settle(tester);
    final rebuilt = await _change(tester, () {
      env.config = _Config(style: _baseStyle.copyWith(copyLabel: 'Copy code'));
    });
    expect(rebuilt, 0);
  });

  group('a changed widget field rebuilds and shows it', () {
    final variants = <String, _Config>{
      'name': const _Config(name: 'dart'),
      'codes': const _Config(codes: 'x = 1\n'),
      'highlightCode': const _Config(highlight: false),
      'scalesItsOwnText': const _Config(scales: true),
      'backgroundColor': _Config(
        style: _baseStyle.copyWith(backgroundColor: const Color(0xFF123456)),
      ),
      'borderColor': _Config(
        style: _baseStyle.copyWith(borderColor: const Color(0xFF654321)),
      ),
      'borderWidth': _Config(style: _baseStyle.copyWith(borderWidth: 3)),
      'borderRadius': _Config(
        style: _baseStyle.copyWith(borderRadius: const Radius.circular(4)),
      ),
      'padding': _Config(style: _baseStyle.copyWith(padding: EdgeInsets.zero)),
      'headerPadding': _Config(
        style: _baseStyle.copyWith(headerPadding: EdgeInsets.zero),
      ),
      'fontFamily': _Config(style: _baseStyle.copyWith(fontFamily: 'Menlo')),
      'fontFamilyPackage': _Config(
        style: _baseStyle.copyWith(fontFamilyPackage: 'some_package'),
      ),
      'fontSize': _Config(style: _baseStyle.copyWith(fontSize: 20)),
      'textColor': _Config(
        style: _baseStyle.copyWith(textColor: const Color(0xFFBB0000)),
      ),
      'showLanguageLabel': _Config(
        style: _baseStyle.copyWith(showLanguageLabel: false),
      ),
      'languageStyle': _Config(
        style: _baseStyle.copyWith(
          languageStyle: const TextStyle(
            fontSize: 15,
            color: Color(0xFF00AA00),
          ),
        ),
      ),
      'showCopyButton': _Config(
        style: _baseStyle.copyWith(showCopyButton: false),
      ),
      'copyLabel': _Config(style: _baseStyle.copyWith(copyLabel: 'Kopieren')),
      'copiedLabel': _Config(
        style: _baseStyle.copyWith(copiedLabel: 'Kopiert'),
      ),
      // Read by the caller (BoundedMarkdown), not drawn: the block rebuilds
      // anyway, since every field is compared.
      'highlightWhileStreaming': _Config(
        style: _baseStyle.copyWith(highlightWhileStreaming: false),
      ),
    };
    for (final e in variants.entries) {
      testWidgets(e.key, (tester) async {
        final env = _Env();
        await _mount(tester, env);
        final copiedLabel = e.key == 'copiedLabel';
        if (copiedLabel) {
          // The label shows only once the code was copied.
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async => null,
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          await tester.tap(_copy);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
        }
        await _settle(tester);
        final before = _shown(tester);
        final rebuilt = await _change(tester, () => env.config = e.value);
        expect(rebuilt, greaterThan(0), reason: 'subtree rebuilt');
        if (copiedLabel) {
          expect(find.bySemanticsLabel('Kopiert'), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
        } else if (e.key != 'highlightWhileStreaming') {
          expect(_shown(tester), isNot(before), reason: 'change is shown');
        }
      });
    }
  });

  testWidgets('a hot reload builds the block again', (tester) async {
    // Reassembling marks every descendant dirty on its own, so counting
    // rebuilds cannot tell whether the State dropped its cache; the widget it
    // returns can: the same instance would be a stale tree after a code change.
    final env = _Env();
    await _mount(tester, env);
    await _settle(tester);
    Widget builtBy(Element block) {
      late Widget child;
      block.visitChildren((c) => child = c.widget);
      return child;
    }

    final block = tester.element(find.byType(HermesCodeBlock));
    final before = builtBy(block);
    final done = tester.binding.reassembleApplication();
    await tester.pump();
    await done;
    expect(identical(builtBy(block), before), isFalse);
  });

  testWidgets('a theme change rebuilds and shows it', (tester) async {
    final env = _Env();
    await _mount(tester, env);
    final before = _shown(tester);
    final rebuilt = await _change(
      tester,
      () => env.theme = buildHermesDarkTheme(),
    );
    expect(rebuilt, greaterThan(0));
    expect(_shown(tester), isNot(before));
  });

  testWidgets('a text-scale change reaches a block that scales itself', (
    tester,
  ) async {
    final env = _Env(config: const _Config(scales: true));
    await _mount(tester, env);
    final before = _codeSize(tester);
    final rebuilt = await _change(tester, () => env.textScale = 2.0);
    expect(rebuilt, greaterThan(0));
    expect(_codeSize(tester).height, greaterThan(before.height));
  });

  testWidgets('a text-scale change does not reach a block inside a paragraph', (
    tester,
  ) async {
    final env = _Env();
    await _mount(tester, env);
    final before = _codeSize(tester);
    await _change(tester, () => env.textScale = 2.0);
    expect(_codeSize(tester), before);
  });

  testWidgets('a Directionality change moves the header and shows it', (
    tester,
  ) async {
    final env = _Env();
    await _mount(tester, env);
    final ltr = tester.getCenter(_copy).dx;
    final rebuilt = await _change(
      tester,
      () => env.direction = TextDirection.rtl,
    );
    expect(rebuilt, greaterThan(0));
    expect(tester.getCenter(_copy).dx, lessThan(ltr));
  });

  group('descendants keep their own dependencies', () {
    // The block's own context reads none of these, so its cached subtree is
    // reused; the descendants that read the inherited widget through their
    // own context must still update.
    testWidgets('an IconTheme change above the block reaches its icons', (
      tester,
    ) async {
      final env = _Env(iconOpacity: 1.0);
      await _mount(tester, env);
      double alpha() => tester
          .widget<RichText>(
            find
                .descendant(
                  of: find.byType(HermesCodeBlock),
                  matching: find.byWidgetPredicate(
                    (w) => w is RichText && w.text.toPlainText().length == 1,
                  ),
                )
                .last,
          )
          .text
          .style!
          .color!
          .a;
      final before = alpha();
      await _change(tester, () => env.iconOpacity = 0.4);
      expect(alpha(), lessThan(before));
    });

    testWidgets('a Locale change flips the header through MaterialApp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late StateSetter set;
      var locale = const Locale('en');
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return MaterialApp(
              locale: locale,
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: buildHermesLightTheme(),
              builder: (_, child) => AppThemeScopes(child: child!),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: 400, child: const _Config().build()),
                ),
              ),
            );
          },
        ),
      );
      final ltr = tester.getCenter(_copy).dx;
      final rebuilt = await countRebuildsBelow<HermesCodeBlock>(() async {
        set(() => locale = const Locale('ar'));
        await tester.pump();
      });
      expect(rebuilt.inside, greaterThan(0));
      expect(tester.getCenter(_copy).dx, lessThan(ltr));
    });
  });

  group('closures and state are never stale', () {
    final copied = <String>[];
    setUp(copied.clear);

    void mockClipboard(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('Copy copies the code of the latest widget', (tester) async {
      mockClipboard(tester);
      final env = _Env();
      await _mount(tester, env);
      await _change(tester, () => env.config = const _Config(codes: 'new\n'));
      await tester.tap(_copy);
      await tester.pump();
      expect(copied, ['new\n']);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('the copied state shows, survives an equal rebuild and ends', (
      tester,
    ) async {
      mockClipboard(tester);
      final env = _Env();
      await _mount(tester, env);
      expect(find.bySemanticsLabel('Copied!'), findsNothing);
      await tester.tap(_copy);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.bySemanticsLabel('Copied!'), findsOneWidget);
      await _settle(tester);
      final rebuilt = await _change(tester, () => env.config = const _Config());
      expect(rebuilt, 0);
      expect(find.bySemanticsLabel('Copied!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.bySemanticsLabel('Copied!'), findsNothing);
      expect(find.bySemanticsLabel('Copy code'), findsOneWidget);
    });

    testWidgets('the semantics label follows the label of the latest widget', (
      tester,
    ) async {
      final env = _Env();
      await _mount(tester, env);
      await _change(
        tester,
        () => env.config = _Config(
          style: _baseStyle.copyWith(copyLabel: 'Kopieren'),
        ),
      );
      expect(find.bySemanticsLabel('Kopieren'), findsOneWidget);
      expect(find.bySemanticsLabel('Copy code'), findsNothing);
    });
  });
}
