import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_open_requests.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_share_inbox.dart';

/// Another destination can ask the chat to open a session, such as one run of
/// a scheduled task, including one the chat has not loaded.
void main() {
  late FakeHermesServer server;
  late ChatOpenRequests requests;
  late int shown;

  void seedProfile(String profile, List<Map<String, Object?>> sessions) =>
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody(sessions),
        query: {'profile': profile},
      );

  void seedMessages(String id, String profile, String text) => server.on(
    'GET',
    '/api/sessions/$id/messages',
    messageListBody(id, [messageRow(id: 1, role: 'assistant', content: text)]),
    query: {'profile': profile},
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    requests = ChatOpenRequests();
    shown = 0;
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'work', isDefault: true),
          profileRow(name: 'home'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));
    seedProfile('work', [sessionRow(id: 'recent', title: 'Recent chat')]);
    seedMessages('recent', 'work', 'the recent transcript');
  });

  tearDown(() => requests.dispose());

  Future<void> pumpChat(WidgetTester tester, {bool settle = true}) async {
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
          home: ChatScreen(
            repository: HermesChatRepository(server.client().raw),
            profiles: HermesProfilesRepository(server.client().raw),
            transport: FakeChatTransport(),
            onShowChat: () => shown++,
            openRequests: requests,
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Finder inTranscript(String text) => find.descendant(
    of: find.byType(Chat),
    matching: find.textContaining(text, findRichText: true),
  );

  Future<void> open(WidgetTester tester, NotificationTarget target) async {
    requests.request(target);
    await tester.pumpAndSettle();
  }

  testWidgets('opens a session the first page of sessions holds', (
    tester,
  ) async {
    seedProfile('work', [
      sessionRow(id: 'recent', title: 'Recent chat'),
      sessionRow(id: 'cron_job1_1', title: 'Morning brief run'),
    ]);
    seedMessages('cron_job1_1', 'work', 'good morning, all quiet');
    await pumpChat(tester);

    await open(
      tester,
      const NotificationTarget(threadId: 'cron_job1_1', profile: 'work'),
    );

    expect(inTranscript('good morning, all quiet'), findsOneWidget);
    expect(server.requestsTo('GET', '/api/sessions/cron_job1_1'), isEmpty);
    expect(shown, greaterThan(0));
  });

  testWidgets('fetches a session older than the first page and opens it', (
    tester,
  ) async {
    server.on(
      'GET',
      '/api/sessions/cron_job1_1',
      sessionRow(id: 'cron_job1_1', title: 'Morning brief run'),
    );
    seedMessages('cron_job1_1', 'work', 'an old run');
    await pumpChat(tester);

    await open(
      tester,
      const NotificationTarget(threadId: 'cron_job1_1', profile: 'work'),
    );

    final request = server
        .requestsTo('GET', '/api/sessions/cron_job1_1')
        .single;
    expect(request.queryParameters['profile'], 'work');
    expect(inTranscript('an old run'), findsOneWidget);
    expect(find.text('Morning brief run'), findsWidgets);
  });

  testWidgets('switches to the profile the session lives under', (
    tester,
  ) async {
    seedProfile('home', [sessionRow(id: 'cron_job2_1', title: 'Backup run')]);
    seedMessages('cron_job2_1', 'home', 'backup finished');
    await pumpChat(tester);

    await open(
      tester,
      const NotificationTarget(threadId: 'cron_job2_1', profile: 'home'),
    );

    expect(inTranscript('backup finished'), findsOneWidget);
    expect(
      server
          .requestsTo('GET', '/api/sessions')
          .map((r) => r.queryParameters['profile']),
      ['work', 'home'],
    );
  });

  testWidgets(
    'a request made while the sessions load still fetches its session',
    (tester) async {
      final gate = Completer<FakeResponse>();
      server.onRequest(
        'GET',
        '/api/sessions',
        (_) => gate.future,
        query: {'profile': 'work'},
      );
      server.on(
        'GET',
        '/api/sessions/cron_job1_1',
        sessionRow(id: 'cron_job1_1', title: 'Morning brief run'),
      );
      seedMessages('cron_job1_1', 'work', 'an old run');
      await pumpChat(tester, settle: false);
      await tester.pump();

      requests.request(
        const NotificationTarget(threadId: 'cron_job1_1', profile: 'work'),
      );
      await tester.pump();
      gate.complete((
        status: 200,
        body: sessionListBody([sessionRow(id: 'recent', title: 'Recent chat')]),
      ));
      await tester.pumpAndSettle();

      expect(inTranscript('an old run'), findsOneWidget);
      expect(find.text('Could not open that chat.'), findsNothing);
    },
  );

  testWidgets('says so when the session no longer exists', (tester) async {
    server.on('GET', '/api/sessions/cron_gone_1', {'detail': 'x'}, status: 404);
    await pumpChat(tester);

    await open(
      tester,
      const NotificationTarget(threadId: 'cron_gone_1', profile: 'work'),
    );

    expect(find.text('Could not open that chat.'), findsOneWidget);
  });

  testWidgets('says so when the other profile cannot be listed', (
    tester,
  ) async {
    server.on(
      'GET',
      '/api/sessions',
      {'detail': 'x'},
      status: 500,
      query: {'profile': 'home'},
    );
    await pumpChat(tester);

    await open(
      tester,
      const NotificationTarget(threadId: 'cron_job2_1', profile: 'home'),
    );

    expect(find.text('Could not open that chat.'), findsOneWidget);
    expect(server.requestsTo('GET', '/api/sessions/cron_job2_1'), isEmpty);
  });
}
