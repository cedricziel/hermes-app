import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/calls/active_call.dart';
import 'package:hermes_app/src/voice/hands_free_strip_layer.dart';
import 'package:provider/provider.dart';

import '../support/screenshot_recorder.dart';
import '../voice/calls/call_harness.dart';

/// The Hands-free strip in the app around a page and a pushed page, in every
/// state, on a phone and on a desktop window.
void main() {
  for (final desktop in [false, true]) {
    for (final dark in [false, true]) {
      final label =
          '${desktop ? 'desktop' : 'phone'}-${dark ? 'dark' : 'light'}';
      testWidgets('hands-free strip in the shell, $label', (tester) async {
        final shots = ScreenshotRecorder('hands-free-strip-$label');
        await shots.start(tester, desktop ? desktopSize : phoneSize);
        final platform = desktop ? TargetPlatform.macOS : TargetPlatform.iOS;
        final theme = withScreenshotFont(
          dark
              ? buildHermesDarkTheme(platform: platform)
              : buildHermesLightTheme(platform: platform),
        );
        final h = CallHarness();
        final registry = ActiveCallRegistry();
        addTearDown(() async {
          registry.dispose();
          await h.dispose();
        });
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: registry,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: navigator,
              theme: theme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) =>
                  shots.frame(HandsFreeStripLayer(child: child!)),
              home: Scaffold(
                appBar: AppBar(title: const Text('Quarterly report')),
                body: ListView(
                  children: [
                    for (var i = 0; i < 12; i++)
                      ListTile(title: Text('Message ${i + 1}')),
                  ],
                ),
              ),
            ),
          ),
        );
        await shots.capture(tester, 'no-call');
        await tester.runAsync(() async {
          await h.activate();
          registry.attach(h.call);
        });
        await tester.pump();
        await shots.capture(tester, 'open');
        await tester.runAsync(() => h.call.setMuted(true));
        await tester.pump();
        await shots.capture(tester, 'muted');
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Settings')),
              body: const Center(child: Text('A page above the shell')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await shots.capture(tester, 'over-a-pushed-page');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
