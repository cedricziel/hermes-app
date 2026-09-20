import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';

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
  }) async {
    if (load) await tester.runAsync(settings.load);
    await pumpChatScreen(
      tester,
      server: server,
      transport: transport,
      withProfiles: withProfiles,
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
    final turn = await send(tester, 'Any news?');
    await tester.tap(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.text('Release notes'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

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

    await send(tester, 'One');
    await send(tester, 'Two');
    await tester.pump();

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

    await send(tester, 'One');
    await tester.pump();

    expect(settings.permissionAsked, isFalse);
    expect(settings.permissionDenied, isFalse);

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
    expect(selected(tester), 's1');

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

    expect(selected(tester), 's1');
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

    testWidgets('a tap made under another profile is ignored', (tester) async {
      await pump(tester, withProfiles: true);

      service.tap('s2', profile: 'default');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(selected(tester), 's1');
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

    testWidgets('a launch under another profile is ignored', (tester) async {
      service
        ..launchThread = 's2'
        ..launchProfile = 'default';

      await pump(tester, withProfiles: true);

      expect(selected(tester), 's1');
    });

    testWidgets('a launch under this profile opens its thread', (tester) async {
      service
        ..launchThread = 's2'
        ..launchProfile = 'work';

      await pump(tester, withProfiles: true);

      expect(selected(tester), 's2');
    });
  });

  testWidgets('a notification that started the app opens its thread', (
    tester,
  ) async {
    service.launchThread = 's2';

    await pump(tester);

    expect(selected(tester), 's2');
  });

  testWidgets('a launch thread that is not listed falls back to the first', (
    tester,
  ) async {
    service.launchThread = 'gone';

    await pump(tester);

    expect(selected(tester), 's1');
  });
}
