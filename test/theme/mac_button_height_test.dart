import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/generated/app_localizations.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/tools/widgets/tools_target.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

typedef _Theme = ThemeData Function({TargetPlatform? platform});

final _buttons = <String, Widget Function()>{
  'FilledButton': () =>
      FilledButton(onPressed: () {}, child: const Text('Save')),
  'FilledButton.tonal': () =>
      FilledButton.tonal(onPressed: () {}, child: const Text('Save')),
  'OutlinedButton': () =>
      OutlinedButton(onPressed: () {}, child: const Text('Save')),
  'TextButton': () => TextButton(onPressed: () {}, child: const Text('Save')),
};

Future<Size> _sizeOf(
  WidgetTester tester,
  _Theme theme,
  TargetPlatform platform,
  Widget child, {
  Finder? finder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme(platform: platform),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  return tester.getSize(finder ?? find.byWidget(child));
}

void main() {
  final themes = <String, _Theme>{
    'light': buildHermesLightTheme,
    'dark': buildHermesDarkTheme,
  };

  for (final MapEntry(key: mode, value: theme) in themes.entries) {
    group('$mode theme', () {
      for (final MapEntry(key: name, value: build) in _buttons.entries) {
        testWidgets('$name is 28 pt tall on a Mac', (tester) async {
          final size = await _sizeOf(
            tester,
            theme,
            TargetPlatform.macOS,
            build(),
          );
          expect(size.height, 28);
          expect(size.width, greaterThanOrEqualTo(28));
        });
      }

      const others = {
        TargetPlatform.windows: 32.0,
        TargetPlatform.linux: 32.0,
        TargetPlatform.android: 48.0,
        TargetPlatform.iOS: 48.0,
      };
      for (final MapEntry(key: platform, value: height) in others.entries) {
        for (final MapEntry(key: name, value: build) in _buttons.entries) {
          testWidgets('$name stays $height tall on $platform', (tester) async {
            final size = await _sizeOf(tester, theme, platform, build());
            expect(size.height, height);
          });
        }
      }

      testWidgets('Mac IconButton stays 40 pt', (tester) async {
        final size = await _sizeOf(
          tester,
          theme,
          TargetPlatform.macOS,
          IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
        );
        expect(size.height, 40);
      });

      testWidgets('Mac SegmentedButton stays 32 pt', (tester) async {
        final size = await _sizeOf(
          tester,
          theme,
          TargetPlatform.macOS,
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('A')),
              ButtonSegment(value: 2, label: Text('B')),
            ],
            selected: const {1},
          ),
          finder: find.byType(SegmentedButton<int>),
        );
        expect(size.height, 32);
      });

      // The theme must reach 28 pt only through `minimumSize`: a button that
      // sets part of its own style, or a banner that merges the theme's
      // style, must see the same padding and density as before.
      group('buttons that style themselves', () {
        Future<void> pumpMac(WidgetTester tester, Widget child) =>
            tester.pumpWidget(
              MaterialApp(
                theme: theme(platform: TargetPlatform.macOS),
                locale: const Locale('de'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: Center(child: child)),
              ),
            );

        testWidgets('a stacked AppBanner action keeps its start edge', (
          tester,
        ) async {
          await pumpMac(
            tester,
            AppBanner(
              tone: AppBannerTone.neutral,
              title: 'Titel',
              action: TextButton(onPressed: () {}, child: const Text('Aktion')),
            ),
          );
          expect(
            AppBanner.stacksAction(tester.element(find.byType(AppBanner))),
            isTrue,
          );
          expect(
            tester.getTopLeft(find.text('Aktion')).dx,
            tester.getTopLeft(find.text('Titel')).dx,
          );
        });

        testWidgets('a minimumSize-only style keeps its height', (
          tester,
        ) async {
          final button = FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Go'),
          );
          await pumpMac(tester, button);
          expect(tester.getSize(find.byWidget(button)).height, 36);
        });

        testWidgets('toolsButtonStyle keeps its height', (tester) async {
          late TextButton button;
          await pumpMac(
            tester,
            Builder(
              builder: (context) => button = TextButton(
                onPressed: () {},
                style: toolsButtonStyle(context),
                child: const Text('Go'),
              ),
            ),
          );
          expect(tester.getSize(find.byWidget(button)).height, 36);
        });

        testWidgets('TextButton.icon keeps its width', (tester) async {
          final button = TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Go'),
          );
          await pumpMac(tester, button);
          expect(
            tester.getSize(find.byWidget(button)).width,
            closeTo(82.2, 0.1),
          );
        });
      });
    });
  }
}
