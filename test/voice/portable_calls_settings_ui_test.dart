import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/settings/settings_dialog.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:hermes_app/src/voice/calls/portable_call_settings.dart';
import 'package:hermes_app/src/voice/portable_calls_dialog.dart';
import 'package:hermes_app/src/voice/widgets/portable_calls_section.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Widget _app(Widget home, {Locale? locale, double textScale = 1}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: home),
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the section', () {
    testWidgets('says what it is and that it is new, in English', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(PortableCallsSection(value: false, onChanged: (_) {})),
      );
      expect(find.text('Voice calls on this device (beta)'), findsOneWidget);
      expect(
        find.text(
          'New on this platform: calls stay off until you turn them on.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('and in German', (tester) async {
      await tester.pumpWidget(
        _app(
          PortableCallsSection(value: true, onChanged: (_) {}),
          locale: const Locale('de'),
        ),
      );
      expect(find.text('Sprachanrufe auf diesem Gerät (Beta)'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('reports the new value when tapped', (tester) async {
      final values = <bool>[];
      await tester.pumpWidget(
        _app(PortableCallsSection(value: false, onChanged: values.add)),
      );
      await tester.tap(find.byType(Switch));
      expect(values, [true]);
    });

    testWidgets('fits a narrow screen at twice the text size', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          PortableCallsSection(value: false, onChanged: (_) {}),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the dialog flips the device preference', (tester) async {
    final settings = PortableCallSettings();
    await tester.runAsync(settings.load);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showPortableCallsDialog(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Voice calls'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(settings.enabled, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  group('the settings dialog', () {
    Future<void> open(
      WidgetTester tester, {
      required TargetPlatform platform,
      required bool provided,
    }) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeController()),
            if (provided)
              ChangeNotifierProvider(create: (_) => PortableCallSettings()),
          ],
          child: _app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showSettingsDialog(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      debugDefaultTargetPlatformOverride = platform;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    }

    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      testWidgets('has a Voice calls row on $platform, off', (tester) async {
        await open(tester, platform: platform, provided: true);
        expect(
          find.byKey(const ValueKey('setting-voiceCalls')),
          findsOneWidget,
        );
        expect(find.text('Voice calls'), findsOneWidget);
        expect(find.text('Off'), findsWidgets);
      });
    }

    testWidgets('has none on iOS', (tester) async {
      await open(tester, platform: TargetPlatform.iOS, provided: true);
      expect(find.byKey(const ValueKey('setting-voiceCalls')), findsNothing);
    });

    testWidgets('has none where the app provides no switch', (tester) async {
      await open(tester, platform: TargetPlatform.macOS, provided: false);
      expect(find.byKey(const ValueKey('setting-voiceCalls')), findsNothing);
    });
  });
}
