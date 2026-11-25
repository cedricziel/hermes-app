import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/messaging_screen.dart';
import 'package:hermes_app/src/messaging/widgets/messaging_platform_row.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../messaging/whatsapp/whatsapp_fixtures.dart';
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// Linking WhatsApp by QR code, from the Messaging list to the saved banner,
/// on a phone (iOS) and on a computer (macOS), light and dark. The server is a
/// fake: no pairing is real, and nothing reaches WhatsApp. The code is an
/// invented text.
void main() {
  late FakeHermesServer server;
  late Map<String, Object?> status;
  var platformsEnabled = false;

  /// A recorded answer with a deadline ten minutes from now.
  Map<String, Object?> live(Map<String, Object?> recorded) => {
    ...recorded,
    'expires_at': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 10))
        .toIso8601String(),
  };

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    platformsEnabled = false;
    status = live(waStatusInstalling);
    server = FakeHermesServer()
      ..onRequest(
        'GET',
        '/api/messaging/platforms',
        (_) => (
          status: 200,
          body: platformListBody([
            platformRow(
              id: 'telegram',
              name: 'Telegram',
              description: 'Chat with Hermes in Telegram.',
              enabled: true,
              configured: true,
              state: 'connected',
            ),
            platformRow(
              id: 'whatsapp',
              name: 'WhatsApp',
              description: 'Chat with Hermes in WhatsApp.',
              enabled: platformsEnabled,
              configured: platformsEnabled,
              state: platformsEnabled ? 'connected' : 'disabled',
              envVars: [
                envVarRow(
                  key: 'WHATSAPP_ALLOWED_USERS',
                  prompt: 'Allowed users',
                  help: 'Comma-separated phone numbers.',
                ),
              ],
            ),
          ]),
        ),
      )
      ..onRequest('POST', waStartPath, (_) => (status: 200, body: status))
      ..onRequest('GET', waStatusPath, (_) => (status: 200, body: status))
      ..onRequest('POST', waApplyPath, (_) {
        platformsEnabled = true;
        return (status: 200, body: waApplyRestartStarted);
      })
      ..on('DELETE', waStatusPath, waCancelOk);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// A moment of the flow: the clock moves and the answers come in. The
  /// working card's spinner never settles, so no `pumpAndSettle` here.
  Future<void> moment(
    WidgetTester tester, [
    Duration by = const Duration(milliseconds: 500),
  ]) async {
    await tester.pump(by);
    await settle(tester);
  }

  for (final (name, size, platform, brightness) in [
    ('phone', phoneSize, TargetPlatform.iOS, Brightness.light),
    ('desktop', desktopSize, TargetPlatform.macOS, Brightness.light),
    ('phone-dark', phoneSize, TargetPlatform.iOS, Brightness.dark),
    ('desktop-dark', desktopSize, TargetPlatform.macOS, Brightness.dark),
  ]) {
    final computer = platform == TargetPlatform.macOS;

    testWidgets('$name: link WhatsApp, finish and the saved banner', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('whatsapp-$name');
      final appLock = await newAppLock(tester);
      await pumpScreen(
        tester,
        shots,
        MessagingScreen(
          repository: HermesMessagingRepository(
            server.client().raw,
            profile: 'atlas',
          ),
        ),
        size: size,
        platform: platform,
        brightness: brightness,
        providers: workflowProviders(appLock),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'list');

      await tester.tap(find.widgetWithText(MessagingPlatformRow, 'WhatsApp'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'setup-with-link');

      await tester.tap(find.text('Link WhatsApp'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'form');

      // Numbers that are not numbers send nothing.
      await tester.enterText(find.byKey(const Key('whatsapp-numbers')), '*');
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'form-invalid-numbers');
      expect(server.requestsTo('POST', waStartPath), isEmpty);

      await tester.enterText(
        find.byKey(const Key('whatsapp-numbers')),
        '+15555550100, +15555550101',
      );
      await tester.tap(find.text('Start'));
      await moment(tester);
      await shots.capture(tester, 'installing');

      status = live(waStatusWaiting);
      await moment(tester, const Duration(seconds: 2));
      await shots.capture(tester, computer ? 'code' : 'handset-notice');

      if (!computer) {
        await tester.tap(find.text('Show QR code'));
        await tester.pump();
        await shots.capture(tester, 'code');
      }

      // The window loses focus, or the app leaves the front.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await shots.capture(tester, 'code-hidden');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await moment(tester);
      await shots.capture(
        tester,
        computer ? 'code-shown-again' : 'needs-the-tap-again',
      );

      status = live(waStatusConnectedAfterScan);
      await moment(tester, const Duration(seconds: 2));
      await shots.capture(tester, 'linked');

      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'finish-question');

      await tester.tap(find.text('Save and restart'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'saved-banner');
      expect(find.text('WhatsApp is set up.'), findsOneWidget);
      expect(server.requestsTo('POST', waApplyPath), hasLength(1));
      expect(server.requestsTo('DELETE', waStatusPath), isEmpty);
    });
  }

  testWidgets('phone: the setup ends without a link', (tester) async {
    final shots = ScreenshotRecorder('whatsapp-phone-ends');
    await pumpScreen(
      tester,
      shots,
      MessagingScreen(
        repository: HermesMessagingRepository(
          server.client().raw,
          profile: 'atlas',
        ),
      ),
      platform: TargetPlatform.iOS,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MessagingPlatformRow, 'WhatsApp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Link WhatsApp'));
    await tester.pumpAndSettle();

    status = live(waStatusErrorInstall);
    await tester.tap(find.text('Start'));
    await moment(tester);
    await shots.capture(tester, 'error');
    // The server's own text reached the screen, and no apply was sent.
    expect(find.textContaining('npm install'), findsWidgets);
    expect(server.requestsTo('POST', waApplyPath), isEmpty);

    await tester.tap(find.text('Start again'));
    await tester.pumpAndSettle();
    status = live(waStartAlreadyLinked);
    await tester.tap(find.text('Start'));
    await moment(tester);
    await shots.capture(tester, 'already-linked');

    // Closing the screen asks the server to drop the setup, once.
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(server.requestsTo('DELETE', waStatusPath), hasLength(1));
  });
}
