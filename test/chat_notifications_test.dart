import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';
import 'support/pump_chat.dart';

const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: ['once', 'deny'],
);

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late FakeNotificationService service;
  late NotificationSettings settings;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    service = FakeNotificationService();
    settings = NotificationSettings();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Why did the run fail?'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s2/messages',
        messageListBody('s2', [
          messageRow(id: 2, role: 'user', content: 'Draft the notes.'),
        ]),
      );
  });

  Future<void> pump(
    WidgetTester tester, {
    bool load = true,
    bool withProfiles = false,
    bool settle = true,
    VoidCallback? onShowChat,
  }) async {
    if (load) await tester.runAsync(settings.load);
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      withProfiles: withProfiles,
      settle: settle,
      onShowChat: onShowChat,
      providers: [
        ChangeNotifierProvider<NotificationSettings>.value(value: settings),
        Provider<NotificationService>.value(value: service),
      ],
    );
  }

  Future<FakeSend> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    return transport.sends.last;
  }

  void leaveTheApp(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
  }

  Future<void> finish(WidgetTester tester, FakeSend turn, String text) async {
    turn.emit(ReplyCompleted(text));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  String? selected(WidgetTester tester) =>
      tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).selectedId;

  testWidgets('a reply that finishes while the app is away is announced', (
    tester,
  ) async {
    await pump(tester);
    await openThread(tester, 'Run failure');
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    await finish(tester, turn, 'Nothing new.');

    final n = service.shown.single;
    expect(n.threadId, 's1');
    expect(n.title, 'Run failure');
    expect(n.body, 'Nothing new.');
  });

  testWidgets('nothing is said while the app is focused on that thread', (
    tester,
  ) async {
    await pump(tester);
    final turn = await send(tester, 'Any news?');

    await finish(tester, turn, 'Nothing new.');

    expect(service.shown, isEmpty);
  });

  testWidgets('a reply for a thread you are not looking at is announced', (
    tester,
  ) async {
    await pump(tester);
    await openThread(tester, 'Run failure');
    final turn = await send(tester, 'Any news?');
    await openThread(tester, 'Release notes');

    await finish(tester, turn, 'Nothing new.');

    expect(service.shown.single.threadId, 's1');
  });

  testWidgets('an approval is announced without its command', (tester) async {
    await pump(tester);
    final turn = await send(tester, 'Clean up');
    leaveTheApp(tester);

    turn.emit(const ApprovalRequested(_approval));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(service.shown.single.body, kApprovalBody);
  });

  testWidgets('a clarify question is announced generically', (tester) async {
    await pump(tester);
    final turn = await send(tester, 'Ask me');
    leaveTheApp(tester);

    turn.emit(
      const ClarifyRequested(
        ClarifyRequest(
          requestId: 'r2',
          questions: [ClarifyQuestion(qid: '', question: 'Which colour?')],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(service.shown.single.body, kQuestionBody);
  });

  testWidgets('nothing is said when notifications are off', (tester) async {
    await tester.runAsync(() => settings.setEnabled(false));
    await pump(tester);
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    await finish(tester, turn, 'Nothing new.');

    expect(service.shown, isEmpty);
  });

  testWidgets('nothing is said before the saved settings are known', (
    tester,
  ) async {
    await pump(tester, load: false);
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    await finish(tester, turn, 'Nothing new.');

    expect(service.shown, isEmpty);
  });

  testWidgets('permission is not asked before the saved settings are known', (
    tester,
  ) async {
    await pump(tester, load: false);

    await send(tester, 'One');
    await tester.pump();

    expect(service.permissionRequests, 0);
    expect(settings.permissionAsked, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a reply is shown only once the permission request resolves', (
    tester,
  ) async {
    final gate = service.permissionGate = Completer<NotificationPermission>();
    await pump(tester);
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    await finish(tester, turn, 'Nothing new.');
    expect(service.permissionRequests, 1);
    expect(service.shown, isEmpty);

    gate.complete(NotificationPermission.granted);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(service.shown.single.body, 'Nothing new.');
  });

  testWidgets('permission is asked once, after the first send', (tester) async {
    await pump(tester);
    expect(service.permissionRequests, 0);

    final first = await send(tester, 'One');
    await finish(tester, first, 'Done.');
    await send(tester, 'Two');
    await tester.pump();

    expect(transport.sends, hasLength(2));
    expect(service.permissionRequests, 1);
    expect(settings.permissionAsked, isTrue);
    expect(settings.permissionDenied, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a refusal is remembered', (tester) async {
    service.permission = NotificationPermission.denied;
    await pump(tester);

    await send(tester, 'One');
    await tester.pump();

    expect(settings.permissionDenied, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a grant is remembered', (tester) async {
    await pump(tester);

    await send(tester, 'One');
    await tester.pump();

    expect(settings.permissionAsked, isTrue);
    expect(settings.permissionDenied, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an unavailable answer records nothing and asks again', (
    tester,
  ) async {
    service.permission = NotificationPermission.unavailable;
    await pump(tester);

    final first = await send(tester, 'One');
    await tester.pump();

    expect(settings.permissionAsked, isFalse);
    expect(settings.permissionDenied, isFalse);

    await finish(tester, first, 'Done.');
    service.permission = NotificationPermission.granted;
    await send(tester, 'Two');
    await tester.pump();

    expect(service.permissionRequests, 2);
    expect(settings.permissionAsked, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('permission is not asked when notifications are off', (
    tester,
  ) async {
    await tester.runAsync(() => settings.setEnabled(false));
    await pump(tester);

    await send(tester, 'One');
    await tester.pump();

    expect(service.permissionRequests, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('permission is not asked again once it was asked', (
    tester,
  ) async {
    await tester.runAsync(() => settings.recordPermission(granted: true));
    await pump(tester);

    await send(tester, 'One');
    await tester.pump();

    expect(service.permissionRequests, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tapping a notification opens its thread', (tester) async {
    await pump(tester);
    expect(selected(tester), isNull);

    service.tap('s2');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(selected(tester), 's2');
  });

  testWidgets('a tap for a thread that is not listed changes nothing', (
    tester,
  ) async {
    await pump(tester);

    service.tap('gone');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(selected(tester), isNull);
  });

  testWidgets('a notification carries the profile the chat is on', (
    tester,
  ) async {
    server.on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));
    await pump(tester, withProfiles: true);
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    await finish(tester, turn, 'Nothing new.');

    expect(service.shown.single.profile, 'work');
  });

  group('on the work profile', () {
    setUp(() {
      server.on(
        'GET',
        '/api/profiles/active',
        activeProfileBody(active: 'work'),
      );
    });

    testWidgets('a tap made under another profile does not open and says so', (
      tester,
    ) async {
      await pump(tester, withProfiles: true);

      service.tap('s2', profile: 'default');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(selected(tester), isNull);
      expect(find.text('Could not open that chat.'), findsOneWidget);
    });

    testWidgets('a tap made under this profile opens its thread', (
      tester,
    ) async {
      await pump(tester, withProfiles: true);

      service.tap('s2', profile: 'work');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(selected(tester), 's2');
    });

    testWidgets('a tap without a profile still matches by thread id', (
      tester,
    ) async {
      await pump(tester, withProfiles: true);

      service.tap('s2');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(selected(tester), 's2');
    });

    testWidgets(
      'a launch under another profile stays on the welcome view and says so',
      (tester) async {
        service
          ..launchThread = 's2'
          ..launchProfile = 'default';

        await pump(tester, withProfiles: true);
        await tester.pump(const Duration(seconds: 1));

        expect(selected(tester), isNull);
        expect(find.text('Could not open that chat.'), findsOneWidget);
      },
    );

    testWidgets('a launch under this profile opens its thread', (tester) async {
      service
        ..launchThread = 's2'
        ..launchProfile = 'work';

      await pump(tester, withProfiles: true);

      expect(selected(tester), 's2');
    });
  });

  testWidgets('a turn that breaks while the app is away is announced', (
    tester,
  ) async {
    await pump(tester);
    await openThread(tester, 'Run failure');
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    turn.fail();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final n = service.shown.single;
    expect(n.threadId, 's1');
    expect(n.body, kReplyFailedBody);
  });

  testWidgets('a broken turn is not announced while you are looking at it', (
    tester,
  ) async {
    await pump(tester);
    final turn = await send(tester, 'Any news?');

    turn.fail();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(service.shown, isEmpty);
  });

  testWidgets('a reply that ended normally is announced once', (tester) async {
    await pump(tester);
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    turn.emit(const ReplyCompleted('Nothing new.'));
    await tester.pump();
    turn.finish();
    await tester.pump(const Duration(seconds: 1));

    expect(service.shown, hasLength(1));
    expect(service.shown.single.body, 'Nothing new.');
  });

  testWidgets('a tap for a thread that is not listed says so', (tester) async {
    await pump(tester);

    service.tap('gone');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Could not open that chat.'), findsOneWidget);
    expect(selected(tester), isNull);
  });

  testWidgets('a tap does not close a screen that sits above the chat', (
    tester,
  ) async {
    await pump(tester);
    tester.view.physicalSize = const Size(500, 900);
    await tester.pump();
    unawaited(
      Navigator.of(tester.element(find.byType(Scaffold).first)).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('a screen above the chat')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    service.tap('s2');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('a screen above the chat'), findsOneWidget);
  });

  testWidgets('a tap made while the chats load opens its thread', (
    tester,
  ) async {
    await pump(tester, settle: false);

    service.tap('s2');
    await tester.pumpAndSettle();

    expect(selected(tester), 's2');
    expect(find.text('Could not open that chat.'), findsNothing);
  });

  testWidgets('a tap closes the thread drawer that is open', (tester) async {
    await pump(tester);
    tester.view.physicalSize = const Size(500, 900);
    await tester.pump();
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    service.tap('s2');
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('a notification that started the app opens its thread', (
    tester,
  ) async {
    service.launchThread = 's2';

    await pump(tester);

    expect(selected(tester), 's2');
  });

  testWidgets('a notification that started the app puts the chat in front', (
    tester,
  ) async {
    service.launchThread = 's2';
    var shown = 0;

    await pump(tester, onShowChat: () => shown++);

    expect(shown, 1);
  });

  testWidgets('a plain launch does not ask for the chat', (tester) async {
    var shown = 0;

    await pump(tester, onShowChat: () => shown++);

    expect(shown, 0);
  });

  testWidgets(
    'a launch thread that is not listed stays on the welcome view and says so',
    (tester) async {
      service.launchThread = 'gone';

      await pump(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(selected(tester), isNull);
      expect(find.text('Could not open that chat.'), findsOneWidget);
    },
  );
}
