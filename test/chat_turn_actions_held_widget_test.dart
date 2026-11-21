import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';
import 'support/pump_chat.dart' show composerField, openThread;

/// What the person sees under a reply that ended on a lost connection while the
/// server may still run its turn: Retry and Edit dimmed with a line that says
/// why, a failure line that does not tell them to send it again, and the same
/// in German. Nothing is sent by tapping them.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    transport = FakeChatTransport();
    server
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Run failure')]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
          messageRow(id: 2, role: 'assistant', content: 'A connection reset.'),
        ]),
      );
  });

  Future<void> pumpScreen(WidgetTester tester, {Locale? locale}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox()),
          ),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(
            repository: HermesChatRepository(server.client().raw),
            transport: transport,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openThread(tester, 'Run failure');
  }

  /// The prompt is sent and the turn ends with [error].
  Future<void> failTurn(WidgetTester tester, Object error) async {
    await tester.enterText(composerField, 'And again');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    final send = transport.sends.single;
    send
      ..emit(const PromptAcknowledged(1))
      ..emit(const ReplyDelta('Reading the report. '));
    await tester.pump();
    send.fail(error);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Finder inTranscript(String text) => find.descendant(
    of: find.byType(Chat),
    matching: find.textContaining(text, findRichText: true),
  );

  IconButton buttonOf(String tooltip) => tester_.widget<IconButton>(
    find.descendant(
      of: find.byTooltip(tooltip),
      matching: find.byType(IconButton),
    ),
  );

  testWidgets('a held reply shows Retry and Edit dimmed, with the reason, and '
      'tapping them sends nothing', (tester) async {
    tester_ = tester;
    await pumpScreen(tester);
    transport.active['s1'] = 'working';
    await failTurn(tester, const GatewayTurnEnded());

    expect(find.byTooltip('Try again'), findsOneWidget);
    expect(find.byTooltip('Edit prompt'), findsOneWidget);
    expect(buttonOf('Try again').onPressed, isNull);
    expect(buttonOf('Edit prompt').onPressed, isNull);
    // The reason is a sentence, not only a dimmed glyph.
    expect(inTranscript('Hermes may still be working on this.'), findsWidgets);
    expect(
      inTranscript(
        'Something went wrong. Hermes may still be working on this.',
      ),
      findsOneWidget,
    );
    expect(inTranscript('Try sending it again'), findsNothing);
    // Branch is not offered while the turn may run.
    expect(find.byTooltip('Branch in new chat'), findsNothing);

    await tester.tap(find.byTooltip('Try again'), warnIfMissed: false);
    await tester.tap(find.byTooltip('Edit prompt'), warnIfMissed: false);
    await tester.pump();
    expect(transport.undos, isEmpty);
    expect(transport.sends, hasLength(1));
  });

  testWidgets('a reply the server answered keeps Retry and Edit on', (
    tester,
  ) async {
    tester_ = tester;
    await pumpScreen(tester);
    transport.active['s1'] = 'working';
    await failTurn(tester, const GatewayRpcException(5000, 'boom'));

    expect(buttonOf('Try again').onPressed, isNotNull);
    expect(buttonOf('Edit prompt').onPressed, isNotNull);
    expect(inTranscript('Hermes may still be working on this.'), findsNothing);
    expect(
      inTranscript('Something went wrong. Try sending it again.'),
      findsOneWidget,
    );
  });

  testWidgets('the notices are German in a German app', (tester) async {
    tester_ = tester;
    await pumpScreen(tester, locale: const Locale('de'));
    transport.active['s1'] = 'working';
    await failTurn(tester, const GatewayTurnEnded());

    expect(
      inTranscript(
        'Etwas ist schiefgegangen. Hermes arbeitet möglicherweise noch daran.',
      ),
      findsOneWidget,
    );
    expect(
      inTranscript('Hermes arbeitet möglicherweise noch daran.'),
      findsWidgets,
    );
    expect(inTranscript('Something went wrong'), findsNothing);
  });

  testWidgets('a failure the server did not explain is German too', (
    tester,
  ) async {
    tester_ = tester;
    await pumpScreen(tester, locale: const Locale('de'));
    await failTurn(tester, const ProfileUnavailableException());

    expect(
      inTranscript(
        'Dieses Profil ist nicht mehr verfügbar. Wähle ein anderes.',
      ),
      findsOneWidget,
    );
    expect(inTranscript('no longer available'), findsNothing);
  });
}

late WidgetTester tester_;
