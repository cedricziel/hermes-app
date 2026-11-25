import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/messaging_screen.dart';
import 'package:hermes_app/src/messaging/messaging_setup_screen.dart';
import 'package:hermes_app/src/messaging/whatsapp_pairing_screen.dart';
import 'package:hermes_app/src/messaging/widgets/messaging_platform_row.dart';
import 'package:hermes_app/src/messaging/widgets/whatsapp_saved_banner.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/named_icon_button.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../support/fake_hermes_server.dart';
import '../../support/recorded_events.dart';
import '../../support/test_localizations.dart';
import 'whatsapp_fixtures.dart';

const _platformsPath = '/api/messaging/platforms';

Map<String, Object?> _list({required bool enabled}) => platformListBody([
  platformRow(id: 'telegram', name: 'Telegram', enabled: true),
  platformRow(
    id: 'whatsapp',
    name: 'WhatsApp',
    enabled: enabled,
    envVars: [
      envVarRow(key: 'WHATSAPP_ALLOWED_USERS', prompt: 'Allowed users'),
    ],
  ),
]);

Map<String, Object?> _live(Map<String, Object?> recorded) => {
  ...recorded,
  'expires_at': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
};

/// The entry to the WhatsApp link: the button in the setup form and what the
/// Messaging list says afterwards. The server is a fake; nothing contacts
/// WhatsApp.
void main() {
  late FakeHermesServer server;
  late FutureOr<FakeResponse> Function(RequestOptions) platformsReply;

  int count(String method, String path) =>
      server.requestsTo(method, path).length;

  setUp(() {
    platformsReply = (_) => (status: 200, body: _list(enabled: false));
    server = FakeHermesServer()
      ..onRequest('GET', _platformsPath, (r) => platformsReply(r))
      ..on('POST', waStartPath, _live(waStartAlreadyLinked))
      ..on('GET', waStatusPath, _live(waStatusConnected))
      ..on('POST', waApplyPath, waApplyRestartStarted)
      ..on('DELETE', waStatusPath, waCancelOk);
  });

  HermesMessagingRepository repository({String? profile = 'atlas'}) =>
      HermesMessagingRepository(server.client().raw, profile: profile);

  Widget app(Widget home) => MaterialApp(
    theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  HermesMessagingPlatform platform(String id, {bool enabled = false}) =>
      HermesMessagingPlatform(
        id: id,
        name: id == 'whatsapp' ? 'WhatsApp' : 'Telegram',
        description: '',
        enabled: enabled,
        configured: false,
        envVars: const [
          HermesMessagingEnvVar(
            key: 'KEY',
            label: 'A key',
            description: '',
            help: '',
            required: false,
            isSet: false,
            isPassword: false,
            advanced: false,
          ),
        ],
      );

  group('whatsAppWasEnabled', () {
    test('reads the platform list of the profile', () async {
      platformsReply = (_) => (status: 200, body: _list(enabled: true));
      expect(await whatsAppWasEnabled(repository()), isTrue);
      expect(server.requestsTo('GET', _platformsPath).single.queryParameters, {
        'profile': 'atlas',
      });
      platformsReply = (_) => (status: 200, body: _list(enabled: false));
      expect(await whatsAppWasEnabled(repository()), isFalse);
    });

    test('a read that fails counts as already on', () async {
      platformsReply = (r) =>
          throw DioException.connectionError(requestOptions: r, reason: 'down');
      expect(await whatsAppWasEnabled(repository()), isTrue);
    });

    test('a read that gets no answer in 10 s counts as already on', () {
      // The conservative answer: Check cannot then report a save it cannot
      // prove, since it cannot tell this apply from an earlier setup.
      fakeAsync((async) {
        platformsReply = (_) => Completer<FakeResponse>().future;
        bool? result;
        unawaited(whatsAppWasEnabled(repository()).then((v) => result = v));
        async.elapse(const Duration(seconds: 9));
        expect(result, isNull);
        async.elapse(const Duration(seconds: 1, milliseconds: 1));
        async.flushMicrotasks();
        expect(result, isTrue);
      });
    });
  });

  group('the Link WhatsApp button', () {
    testWidgets('is in the WhatsApp form only, and sends nothing to open it', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          MessagingSetupScreen(
            platform: platform('whatsapp'),
            repository: repository(),
          ),
        ),
      );
      expect(find.text('Link WhatsApp'), findsOneWidget);
      expect(server.requests, isEmpty);

      await tester.pumpWidget(
        app(
          MessagingSetupScreen(
            platform: platform('telegram'),
            repository: repository(),
          ),
        ),
      );
      expect(find.text('Link WhatsApp'), findsNothing);
    });

    testWidgets('is not offered without a named profile', (tester) async {
      await tester.pumpWidget(
        app(
          MessagingSetupScreen(
            platform: platform('whatsapp'),
            repository: repository(profile: null),
          ),
        ),
      );
      expect(find.text('Link WhatsApp'), findsNothing);
    });

    testWidgets(
      'shows progress during the read of up to 10 s and takes no second tap',
      (tester) async {
        platformsReply = (_) => Completer<FakeResponse>().future;
        await tester.pumpWidget(
          app(
            MessagingSetupScreen(
              platform: platform('whatsapp'),
              repository: repository(),
            ),
          ),
        );
        final button = find.widgetWithText(OutlinedButton, 'Link WhatsApp');
        await tester.tap(button);
        await tester.pump(const Duration(milliseconds: 1));

        // The read is out: a spinner in the button, the button off.
        expect(
          find.descendant(
            of: button,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        await tester.tap(button, warnIfMissed: false);
        await tester.pump(const Duration(seconds: 5));
        expect(count('GET', _platformsPath), 1);
        expect(find.byType(MessagingSetupScreen), findsOneWidget);
        expect(find.text('Allowed phone numbers'), findsNothing);

        // 10 s without an answer: the screen opens, nothing was started.
        await tester.pump(const Duration(seconds: 5, milliseconds: 10));
        await tester.pumpAndSettle();
        expect(find.text('Allowed phone numbers'), findsOneWidget);
        expect(count('POST', waStartPath), 0);
      },
    );

    testWidgets('the old server takes the button away after the screen ends', (
      tester,
    ) async {
      server.on('POST', waStartPath, waRouteMissing, status: 404);
      await tester.pumpWidget(
        app(
          MessagingSetupScreen(
            platform: platform('whatsapp'),
            repository: repository(),
          ),
        ),
      );
      await tester.tap(find.text('Link WhatsApp'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(find.text('Link WhatsApp'), findsNothing);
    });
  });

  group('the old-server event', () {
    testWidgets('is logged once per connection, not once per visit', (
      tester,
    ) async {
      server.on('POST', waStartPath, waRouteMissing, status: 404);
      final events = RecordedEvents();
      HermesRepositories connect() => HermesRepositories(
        server.client(),
        telemetry: events.connection(const {}),
      );

      Future<void> visit(HermesRepositories connection) async {
        // A new list, not the one left open.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          Provider<HermesRepositories?>.value(
            value: connection,
            child: app(MessagingScreen(repository: repository())),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(MessagingPlatformRow, 'WhatsApp'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Link WhatsApp'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Start'));
        await tester.pumpAndSettle();
        expect(
          find.text('This server cannot link WhatsApp from the app'),
          findsOneWidget,
        );
      }

      final first = connect();
      await visit(first);
      expect(events.named('whatsapp.pair.unavailable'), hasLength(1));

      // The same connection, the list opened again: not logged again.
      await visit(first);
      expect(events.named('whatsapp.pair.unavailable'), hasLength(1));

      // Another connection (a new sign-in or server): logged once more.
      await visit(connect());
      expect(events.named('whatsapp.pair.unavailable'), hasLength(2));
    });
  });

  group('the saved banner', () {
    Future<void> openLinked(WidgetTester tester) async {
      server.on('GET', _platformsPath, _list(enabled: false));
      await tester.pumpWidget(app(MessagingScreen(repository: repository())));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MessagingPlatformRow, 'WhatsApp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link WhatsApp'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pumpAndSettle();
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and restart'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Finish closes both screens to a success banner that can be closed',
      (tester) async {
        await openLinked(tester);
        expect(find.byType(WhatsAppSavedBanner), findsNothing);
        await finish(tester);

        expect(find.byType(MessagingSetupScreen), findsNothing);
        expect(find.text('WhatsApp is set up.'), findsOneWidget);
        expect(
          find.text('A restart of the messaging gateway was requested.'),
          findsOneWidget,
        );
        // No Server screen here: no "Open Server".
        expect(find.text('Open Server'), findsNothing);
        // The list was read again.
        expect(count('GET', _platformsPath), greaterThan(2));

        await tester.tap(
          find.descendant(
            of: find.byType(WhatsAppSavedBanner),
            matching: find.byType(NamedIconButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(WhatsAppSavedBanner), findsNothing);
      },
    );

    testWidgets('a restart that was not requested is a warning with its text', (
      tester,
    ) async {
      server.on('POST', waApplyPath, waApplyRestartFailed);
      await openLinked(tester);
      await finish(tester);
      expect(find.text('WhatsApp is saved.'), findsOneWidget);
      expect(
        find.textContaining('could not run /usr/bin/hermes'),
        findsOneWidget,
      );
    });

    testWidgets('leaving without Finish leaves no banner', (tester) async {
      await openLinked(tester);
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(WhatsAppSavedBanner), findsNothing);
    });
  });
}
