import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_open_requests.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_share_inbox.dart';
import '../support/fake_voice_recorder.dart';
import '../support/pump_chat.dart';

const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: ['once', 'deny'],
);

/// What the chat does with the requests a `hermes://` link makes through
/// [ChatOpenRequests].
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late FakeVoiceRecorder recorder;
  late ChatOpenRequests requests;

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

  void voice({required bool on}) => on
      ? server.on('GET', '/api/audio/voice-config', {
          'ok': true,
          'stt': {'mode': 'relay', 'reason': 'local provider'},
          'tts': {'mode': 'relay'},
        })
      : server.on('GET', '/api/audio/voice-config', {
          'detail': 'Not Found',
        }, status: 404);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    requests = ChatOpenRequests();
    transport = FakeChatTransport();
    recorder = FakeVoiceRecorder();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'work', isDefault: true),
          profileRow(name: 'home'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('POST', '/api/audio/stt-lease', {'ok': true});
    seedProfile('work', [
      sessionRow(id: 'recent', title: 'Recent chat'),
      sessionRow(id: 'older', title: 'Older chat'),
    ]);
    seedMessages('recent', 'work', 'the recent transcript');
    seedMessages('older', 'work', 'the older transcript');
    voice(on: true);
  });

  tearDown(() => requests.dispose());

  Future<void> pumpChat(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
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
            transport: transport,
            voiceRecorder: recorder,
            openRequests: requests,
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  String composerText(WidgetTester tester) =>
      tester.widget<EditableText>(composerField).controller.text;

  String? selectedId(WidgetTester tester) =>
      tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).selectedId;

  Finder newChatRows() => find.descendant(
    of: find.byType(ThreadSidebar),
    matching: find.text('New chat'),
  );

  Future<FakeSend> sendIn(WidgetTester tester, String thread) async {
    await openThread(tester, thread, settle: false);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(composerField, 'Go on');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    return transport.sends.last;
  }

  group('a new chat', () {
    testWidgets('fills the composer and sends nothing', (tester) async {
      await pumpChat(tester);

      requests.requestNew(prompt: 'Summarize my day');
      await tester.pumpAndSettle();

      expect(composerText(tester), 'Summarize my day');
      expect(newChatRows(), findsNWidgets(2));
      expect(transport.sends, isEmpty);
    });

    testWidgets('keeps what the user already typed', (tester) async {
      await pumpChat(tester);
      await tester.enterText(composerField, 'Remember to');

      requests.requestNew(prompt: 'Summarize my day');
      await tester.pumpAndSettle();

      expect(composerText(tester), 'Remember to\nSummarize my day');
    });

    testWidgets('in another profile switches to it first', (tester) async {
      seedProfile('home', [sessionRow(id: 'h1', title: 'Home chat')]);
      await pumpChat(tester);

      requests.requestNew(profile: 'home', prompt: 'Lights off');
      await tester.pumpAndSettle();

      expect(
        server
            .requestsTo('GET', '/api/sessions')
            .map((r) => r.queryParameters['profile']),
        ['work', 'home'],
      );
      expect(find.text('Home chat'), findsWidgets);
      expect(newChatRows(), findsNWidgets(2));
      expect(composerText(tester), 'Lights off');
    });

    testWidgets('says so when the profile cannot be switched to', (
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

      requests.requestNew(profile: 'home', prompt: 'Lights off');
      await tester.pumpAndSettle();

      expect(find.text('Could not switch profile'), findsOneWidget);
      expect(find.text('Could not load your chats'), findsOneWidget);
    });

    testWidgets('waits for the threads that are still loading', (tester) async {
      await pumpChat(tester, settle: false);
      requests.requestNew(prompt: 'Early bird');
      await tester.pumpAndSettle();

      expect(composerText(tester), 'Early bird');
      expect(newChatRows(), findsNWidgets(2));
    });

    testWidgets('starts dictation when the profile offers it', (tester) async {
      await pumpChat(tester);

      requests.requestNew(dictate: true);
      await tester.pumpAndSettle();

      expect(recorder.starts, 1);
      expect(recorder.recording, isTrue);

      await tester.tap(find.bySemanticsLabel('Cancel voice input'));
      await tester.pumpAndSettle();
    });

    testWidgets('skips dictation when the profile offers none', (tester) async {
      voice(on: false);
      await pumpChat(tester);

      requests.requestNew(dictate: true, prompt: 'Hello');
      await tester.pumpAndSettle();

      expect(recorder.starts, 0);
      expect(composerText(tester), 'Hello');
    });

    testWidgets('does not dictate unless asked', (tester) async {
      await pumpChat(tester);

      requests.requestNew(prompt: 'Hello');
      await tester.pumpAndSettle();

      expect(recorder.starts, 0);
    });
  });

  group('a chat with a prompt', () {
    testWidgets('fills the composer of a loaded chat', (tester) async {
      await pumpChat(tester);

      requests.request(
        const NotificationTarget(threadId: 'older', profile: 'work'),
        prompt: 'Yes, book it',
      );
      await tester.pumpAndSettle();

      expect(selectedId(tester), 'older');
      expect(composerText(tester), 'Yes, book it');
      expect(transport.sends, isEmpty);
    });

    testWidgets('fills the composer of a chat it had to fetch', (tester) async {
      server.on(
        'GET',
        '/api/sessions/ancient',
        sessionRow(id: 'ancient', title: 'Ancient chat'),
      );
      seedMessages('ancient', 'work', 'long ago');
      await pumpChat(tester);

      requests.request(
        const NotificationTarget(threadId: 'ancient', profile: 'work'),
        prompt: 'Still there?',
      );
      await tester.pumpAndSettle();

      expect(selectedId(tester), 'ancient');
      expect(composerText(tester), 'Still there?');
    });

    testWidgets('is dropped when the chat cannot be opened', (tester) async {
      server.on('GET', '/api/sessions/gone', {'detail': 'x'}, status: 404);
      await pumpChat(tester);

      requests.request(
        const NotificationTarget(threadId: 'gone', profile: 'work'),
        prompt: 'Hello?',
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not open that chat.'), findsOneWidget);
      expect(composerText(tester), isEmpty);
    });

    testWidgets('waits for the threads that are still loading', (tester) async {
      await pumpChat(tester, settle: false);
      requests.request(
        const NotificationTarget(threadId: 'older', profile: 'work'),
        prompt: 'Early bird',
      );
      await tester.pumpAndSettle();

      expect(selectedId(tester), 'older');
      expect(composerText(tester), 'Early bird');
    });

    testWidgets('a later request without a prompt does not inherit it', (
      tester,
    ) async {
      await pumpChat(tester, settle: false);
      requests.request(
        const NotificationTarget(threadId: 'older', profile: 'work'),
        prompt: 'Stale',
      );
      await tester.pump();
      requests.request(
        const NotificationTarget(threadId: 'recent', profile: 'work'),
      );
      await tester.pumpAndSettle();

      expect(selectedId(tester), 'recent');
      expect(composerText(tester), isEmpty);
    });
  });

  group('the oldest request', () {
    testWidgets('opens the chat that has waited longest', (tester) async {
      await pumpChat(tester);
      // "older" is asked first, though "recent" is listed above it.
      final first = await sendIn(tester, 'Older chat');
      first.emit(const ApprovalRequested(_approval));
      await tester.pump();
      final second = await sendIn(tester, 'Recent chat');
      second.emit(
        const ApprovalRequested(
          ApprovalRequest(
            requestId: 'r2',
            command: 'ls',
            description: 'list',
            choices: ['once', 'deny'],
          ),
        ),
      );
      await tester.pump();
      expect(selectedId(tester), 'recent');

      requests.requestOldestPending();
      await tester.pump(const Duration(milliseconds: 500));

      expect(selectedId(tester), 'older');
    });

    testWidgets('leaves a wide layout as it is when nothing waits', (
      tester,
    ) async {
      await pumpChat(tester);
      await openThread(tester, 'Recent chat');

      requests.requestOldestPending();
      await tester.pumpAndSettle();

      expect(selectedId(tester), 'recent');
      expect(find.byType(ThreadSidebar), findsOneWidget);
    });

    testWidgets('shows the chat list on a phone when nothing waits', (
      tester,
    ) async {
      await pumpChat(tester, size: const Size(400, 800));
      await tester.tap(find.byTooltip('Open navigation menu').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ThreadSidebar),
          matching: find.text('Recent chat'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ThreadSidebar), findsNothing);

      requests.requestOldestPending();
      await tester.pumpAndSettle();

      expect(find.byType(ThreadSidebar), findsOneWidget);
      expect(selectedId(tester), isNull);
    });
  });
}
