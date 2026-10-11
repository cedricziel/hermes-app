import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
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
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot_store.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_conversation_window_host.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_share_inbox.dart';
import '../support/fake_surface_storage.dart';
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
  late BreadcrumbTrail trail;
  FakeConversationWindowHost? host;
  ConversationWindows? windows;
  AppLockController? lock;
  SurfaceSnapshotStore? snapshots;

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
    trail = BreadcrumbTrail(capacity: 50);
    host = null;
    windows = null;
    lock = null;
    snapshots = null;
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
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          if (lock case final lock?)
            ChangeNotifierProvider<AppLockController>.value(value: lock),
          Provider<SurfaceSnapshotStore?>.value(value: snapshots),
          if (windows case final windows?)
            ChangeNotifierProvider<ConversationWindows?>.value(value: windows),
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
        fromLink: true,
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
        fromLink: true,
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
        fromLink: true,
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
        fromLink: true,
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
        fromLink: true,
      );
      await tester.pump();
      requests.request(
        const NotificationTarget(threadId: 'recent', profile: 'work'),
        fromLink: true,
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

    Future<void> storePending(List<(String, String, DateTime)> open) async {
      final store = snapshots = SurfaceSnapshotStore(
        storage: FakeSurfaceStorage(),
      );
      addTearDown(store.dispose);
      await store.write(
        SurfaceSnapshot(
          updatedAt: DateTime.utc(2026, 10, 11),
          profile: 'work',
          pending: [
            for (final (profile, thread, since) in open)
              PendingRequest(
                profile: profile,
                threadId: thread,
                threadTitle: 'Chat',
                kind: PendingKind.approval,
                requestId: 'req-$thread',
                createdAt: since,
              ),
          ],
        ),
      );
    }

    testWidgets('opens the oldest one the snapshot lists for another profile', (
      tester,
    ) async {
      seedProfile('home', [sessionRow(id: 'h1', title: 'Home chat')]);
      seedMessages('h1', 'home', 'the home transcript');
      transport.activeInProfile['home'] = {'h1': 'waiting'};
      await storePending([
        ('work', 'recent', DateTime.utc(2026, 10, 11, 7)),
        ('home', 'h1', DateTime.utc(2026, 10, 11, 8)),
      ]);
      await pumpChat(tester);

      requests.requestOldestPending();
      await tester.pumpAndSettle();

      // The work request is the open profile's: the live chats speak for it.
      expect(selectedId(tester), 'h1');
      expect(transport.activeAsked, contains('home'));
    });

    testWidgets('does not open a chat of the open profile the snapshot still '
        'lists after its request was answered', (tester) async {
      await storePending([('work', 'older', DateTime.utc(2026, 10, 11, 8))]);
      await pumpChat(tester);
      await openThread(tester, 'Recent chat');

      requests.requestOldestPending();
      await tester.pumpAndSettle();

      expect(selectedId(tester), 'recent');
    });

    testWidgets('a request that is no longer open switches no profile', (
      tester,
    ) async {
      seedProfile('home', [sessionRow(id: 'h1', title: 'Home chat')]);
      seedMessages('h1', 'home', 'the home transcript');
      // The server no longer lists h1 as waiting.
      transport.activeInProfile['home'] = {'h1': 'idle'};
      await storePending([('home', 'h1', DateTime.utc(2026, 10, 11, 8))]);
      await pumpChat(tester, size: const Size(400, 800));
      final before = server.requestsTo('GET', '/api/sessions').length;

      requests.requestOldestPending();
      await tester.pumpAndSettle();

      expect(transport.activeAsked, contains('home'));
      expect(server.requestsTo('GET', '/api/sessions'), hasLength(before));
      expect(selectedId(tester), isNull);
      expect(find.byType(ThreadSidebar), findsOneWidget);
    });

    testWidgets('tries the next request when the oldest is no longer open', (
      tester,
    ) async {
      seedProfile('home', [sessionRow(id: 'h1', title: 'Home chat')]);
      seedProfile('play', [sessionRow(id: 'p1', title: 'Play chat')]);
      seedMessages('p1', 'play', 'the play transcript');
      server.on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'work', isDefault: true),
          profileRow(name: 'home'),
          profileRow(name: 'play'),
        ]),
      );
      transport.activeInProfile['home'] = {};
      transport.activeInProfile['play'] = {'p1': 'waiting'};
      await storePending([
        ('home', 'h1', DateTime.utc(2026, 10, 11, 7)),
        ('play', 'p1', DateTime.utc(2026, 10, 11, 8)),
      ]);
      await pumpChat(tester);

      requests.requestOldestPending();
      await tester.pumpAndSettle();

      expect(selectedId(tester), 'p1');
      expect(
        server
            .requestsTo('GET', '/api/sessions')
            .map((r) => r.queryParameters['profile']),
        isNot(contains('home')),
      );
    });

    testWidgets('falls back to the loaded chats when the snapshot lists none', (
      tester,
    ) async {
      await storePending([]);
      await pumpChat(tester);
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

  List<String> crumbs() => [
    for (final c in trail.recent) '${c.name} ${c.attributes}',
  ];

  group('a profile that does not exist', () {
    testWidgets('is ignored by a chat link, which opens in the current one', (
      tester,
    ) async {
      await pumpChat(tester);

      requests.request(
        const NotificationTarget(threadId: 'older', profile: 'ghost'),
        prompt: 'Hi',
        fromLink: true,
      );
      await tester.pumpAndSettle();

      expect(selectedId(tester), 'older');
      expect(composerText(tester), 'Hi');
      expect(
        server
            .requestsTo('GET', '/api/sessions')
            .map((r) => r.queryParameters['profile']),
        ['work'],
      );
      expect(crumbs(), contains('deeplink.ignored {reason: unknown_profile}'));
    });

    testWidgets('is ignored by a new chat link', (tester) async {
      await pumpChat(tester);

      requests.requestNew(profile: 'ghost', prompt: 'Hi');
      await tester.pumpAndSettle();

      expect(newChatRows(), findsNWidgets(2));
      expect(composerText(tester), 'Hi');
      expect(
        server
            .requestsTo('GET', '/api/sessions')
            .map((r) => r.queryParameters['profile']),
        ['work'],
      );
      expect(crumbs(), contains('deeplink.ignored {reason: unknown_profile}'));
    });

    testWidgets('is still honoured for a request that is not a link', (
      tester,
    ) async {
      server.on('GET', '/api/sessions/x', {'detail': 'x'}, status: 404);
      await pumpChat(tester);

      requests.request(
        const NotificationTarget(threadId: 'x', profile: 'ghost'),
      );
      await tester.pumpAndSettle();

      expect(
        crumbs(),
        isNot(contains('deeplink.ignored {reason: unknown_profile}')),
      );
    });
  });

  group('the latest link', () {
    testWidgets('replaces a new chat still waiting for the threads', (
      tester,
    ) async {
      await pumpChat(tester, settle: false);
      requests.requestNew(prompt: 'First');
      requests.request(
        const NotificationTarget(threadId: 'older', profile: 'work'),
        fromLink: true,
      );
      await tester.pumpAndSettle();

      expect(selectedId(tester), 'older');
      expect(composerText(tester), isEmpty);
      expect(newChatRows(), findsOneWidget);
    });

    testWidgets('replaces a chat link with a new chat', (tester) async {
      await pumpChat(tester, settle: false);
      requests.request(
        const NotificationTarget(threadId: 'older', profile: 'work'),
        prompt: 'Stale',
        fromLink: true,
      );
      requests.requestNew(prompt: 'Fresh');
      await tester.pumpAndSettle();

      expect(composerText(tester), 'Fresh');
      expect(newChatRows(), findsNWidgets(2));
    });
  });

  testWidgets('a prompt does not outlive the open that carried it', (
    tester,
  ) async {
    final gate = Completer<FakeResponse>();
    server.onRequest('GET', '/api/sessions/ancient', (_) => gate.future);
    seedMessages('ancient', 'work', 'long ago');
    await pumpChat(tester);

    requests.request(
      const NotificationTarget(threadId: 'ancient', profile: 'work'),
      prompt: 'Too late',
      fromLink: true,
    );
    await tester.pump();
    await openThread(tester, 'Recent chat');
    gate.complete((
      status: 200,
      body: sessionRow(id: 'ancient', title: 'Ancient chat'),
    ));
    await tester.pumpAndSettle();

    expect(selectedId(tester), 'recent');
    expect(composerText(tester), isEmpty);
  });

  testWidgets('dictation does not start if the lock came on while the open '
      'was waiting', (tester) async {
    final voiceConfig = Completer<FakeResponse>();
    server.onRequest(
      'GET',
      '/api/audio/voice-config',
      (_) => voiceConfig.future,
    );
    final device = FakeDeviceAuthenticator();
    await tester.runAsync(() async {
      lock = AppLockController(authenticator: device, coverWhenInactive: true);
      await lock!.load();
      await lock!.setEnabled(true);
    });
    addTearDown(lock!.dispose);
    await pumpChat(tester, settle: false);
    await tester.pump(const Duration(seconds: 1));

    requests.requestNew(dictate: true, prompt: 'Hello');
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(lock!.covered, isTrue);
    voiceConfig.complete((
      status: 200,
      body: {
        'ok': true,
        'stt': {'mode': 'relay', 'reason': 'local provider'},
        'tts': {'mode': 'relay'},
      },
    ));
    await tester.pumpAndSettle();

    expect(recorder.starts, 0);
    expect(newChatRows(), findsNWidgets(2));
    expect(composerText(tester), 'Hello');
  });

  group('on a Mac with conversation windows', () {
    Future<void> pumpWithWindows(WidgetTester tester) async {
      host = FakeConversationWindowHost();
      windows = ConversationWindows(
        host: host!,
        store: ConversationWindowStore(SharedPreferencesAsync()),
        connection: () => (baseUrl: 'https://hermes.test', authRequired: true),
        headers: ({rejected}) async => const {},
      );
      addTearDown(() {
        windows!.dispose();
        host!.dispose();
      });
      await pumpChat(tester);
    }

    testWidgets('a chat that has a window is focused there', (tester) async {
      await pumpWithWindows(tester);
      await windows!.open('older', profile: 'work', title: 'Older chat');

      requests.request(
        const NotificationTarget(threadId: 'older', profile: 'work'),
        fromLink: true,
      );
      await tester.pumpAndSettle();

      expect(host!.focused, ['w0']);
      expect(host!.mainShown, 0);
      expect(selectedId(tester), isNull);
    });

    testWidgets('another chat opens in the main window, brought back', (
      tester,
    ) async {
      await pumpWithWindows(tester);

      requests.request(
        const NotificationTarget(threadId: 'older', profile: 'work'),
        fromLink: true,
      );
      await tester.pumpAndSettle();

      expect(host!.mainShown, 1);
      expect(selectedId(tester), 'older');
    });

    testWidgets('a new chat brings the main window back', (tester) async {
      await pumpWithWindows(tester);

      requests.requestNew(prompt: 'Hi');
      await tester.pumpAndSettle();

      expect(host!.mainShown, 1);
      expect(composerText(tester), 'Hi');
    });
  });
}
