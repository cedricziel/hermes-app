import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/server_care/hermes_update_run.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/update_banner.dart';
import 'package:hermes_app/src/server_care/widgets/server_restart_banner.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

/// The banner paints through the window's top inset and keeps its content
/// below it, once.
void main() {
  late FakeHermesServer server;
  late HermesUpdateRun run;

  setUp(() {
    server = FakeHermesServer()
      ..on('POST', '/api/hermes/update', updateStarted())
      ..onRequest('GET', '/api/health', (o) {
        throw DioException.connectionError(requestOptions: o, reason: 'down');
      })
      ..onRequest('GET', '/api/actions/hermes-update/status', (o) {
        throw DioException.connectionError(requestOptions: o, reason: 'down');
      });
  });

  Future<void> pump(WidgetTester tester, TargetPlatform platform) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    run = HermesUpdateRun(repository: ServerCareRepository(server.client()));
    addTearDown(run.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHermesLightTheme(platform: platform),
        builder: (context, child) => MediaQuery(
          // A notch or the Mac title bar: what the window reports.
          data: MediaQuery.of(context)
              .copyWith(padding: const EdgeInsets.only(top: 47)),
          child: child!,
        ),
        home: ChangeNotifierProvider<HermesUpdateRun>.value(
          value: run,
          child: UpdateBannerLayer(
            onOpen: () {},
            child: Builder(
              builder: (context) => Text(
                'top ${MediaQuery.paddingOf(context).top}',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      ),
    );
    run.start().ignore();
    await tester.pump(const Duration(seconds: 3));
    expect(run.phase, UpdatePhase.restarting);
  }

  const text =
      "Hermes is restarting after the update. Chats continue when it's back.";

  for (final (name, platform) in [
    ('phone', TargetPlatform.android),
    ('Mac', TargetPlatform.macOS),
  ]) {
    testWidgets('$name: the background covers the inset and the text sits '
        'below it', (tester) async {
      await pump(tester, platform);
      final banner = find.byType(ServerRestartBanner);
      final rect = tester.getRect(banner);
      expect(rect.top, 0);
      expect(rect.height, greaterThanOrEqualTo(47 + 44));
      expect(tester.getTopLeft(find.text(text)).dy, greaterThanOrEqualTo(47));
      // The page below no longer adds the inset itself.
      expect(find.text('top 0.0'), findsOneWidget);
      expect(
        find.descendant(of: banner, matching: find.byType(MacWindowDragArea)),
        platform == TargetPlatform.macOS ? findsOneWidget : findsNothing,
      );
      await run.reset();
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('top 47.0'), findsOneWidget);
    });
  }
}
