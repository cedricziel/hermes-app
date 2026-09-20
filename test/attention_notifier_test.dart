import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';

import 'support/fake_notification_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNotificationService service;
  late NotificationSettings settings;
  late List<NotificationTarget> opened;
  late AttentionNotifier notifier;
  final thread = ChatThread(
    id: 's1',
    title: 'Run failure',
    updatedAt: DateTime(2026),
  );

  AttentionNotifier build({NotificationSettings? withSettings}) =>
      notifier = AttentionNotifier(
        service: service,
        settings: withSettings ?? settings,
        onOpen: opened.add,
      );

  void leaveTheApp() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
  }

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    service = FakeNotificationService();
    settings = NotificationSettings();
    opened = [];
    await settings.load();
  });

  tearDown(() => notifier.dispose());

  group('announce', () {
    test('shows what the policy asks for', () {
      build();
      leaveTheApp();

      notifier.announce(
        thread,
        const ReplyCompleted('Nothing new.'),
        selectedThreadId: 's1',
        profile: 'work',
      );

      final n = service.shown.single;
      expect(n.threadId, 's1');
      expect(n.title, 'Run failure');
      expect(n.body, 'Nothing new.');
      expect(n.profile, 'work');
    });

    test('says nothing about the thread that is on screen', () {
      build();

      notifier.announce(
        thread,
        const ReplyCompleted('Nothing new.'),
        selectedThreadId: 's1',
        profile: null,
      );

      expect(service.shown, isEmpty);
    });

    test('says nothing without a service', () {
      notifier = AttentionNotifier(
        service: null,
        settings: settings,
        onOpen: opened.add,
      );
      leaveTheApp();

      notifier.announce(
        thread,
        const ReplyCompleted('Nothing new.'),
        selectedThreadId: 's1',
        profile: null,
      );

      expect(service.shown, isEmpty);
    });

    test('says nothing when notifications are off', () async {
      await settings.setEnabled(false);
      build();
      leaveTheApp();

      notifier.announce(
        thread,
        const ReplyCompleted('Nothing new.'),
        selectedThreadId: 's1',
        profile: null,
      );

      expect(service.shown, isEmpty);
    });

    test('says nothing before the saved settings are known', () {
      build(withSettings: NotificationSettings());
      leaveTheApp();

      notifier.announce(
        thread,
        const ReplyCompleted('Nothing new.'),
        selectedThreadId: 's1',
        profile: null,
      );

      expect(service.shown, isEmpty);
    });

    test('waits for a permission answer that is still open', () async {
      final gate = service.permissionGate = Completer<NotificationPermission>();
      build();
      leaveTheApp();
      final asking = notifier.askForPermission();

      notifier.announce(
        thread,
        const ReplyCompleted('Nothing new.'),
        selectedThreadId: 's1',
        profile: null,
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.shown, isEmpty);

      gate.complete(NotificationPermission.granted);
      await asking;
      await Future<void>.delayed(Duration.zero);

      expect(service.shown.single.body, 'Nothing new.');
    });
  });

  group('askForPermission', () {
    test('asks and records the answer', () async {
      build();

      await notifier.askForPermission();

      expect(service.permissionRequests, 1);
      expect(settings.permissionAsked, isTrue);
      expect(settings.permissionDenied, isFalse);
    });

    test('records a refusal', () async {
      service.permission = NotificationPermission.denied;
      build();

      await notifier.askForPermission();

      expect(settings.permissionAsked, isTrue);
      expect(settings.permissionDenied, isTrue);
    });

    test('does not record an answer the system could not give', () async {
      service.permission = NotificationPermission.unavailable;
      build();

      await notifier.askForPermission();

      expect(settings.permissionAsked, isFalse);
    });

    test('asks only once', () async {
      build();

      await notifier.askForPermission();
      await notifier.askForPermission();

      expect(service.permissionRequests, 1);
    });

    test('does not ask twice at the same time', () async {
      service.permissionGate = Completer<NotificationPermission>();
      build();

      final first = notifier.askForPermission();
      final second = notifier.askForPermission();
      service.permissionGate!.complete(NotificationPermission.granted);
      await Future.wait([first, second]);

      expect(service.permissionRequests, 1);
    });

    test('does not ask when notifications are off', () async {
      await settings.setEnabled(false);
      build();

      await notifier.askForPermission();

      expect(service.permissionRequests, 0);
    });

    test('does not ask before the saved settings are known', () async {
      build(withSettings: NotificationSettings());

      await notifier.askForPermission();

      expect(service.permissionRequests, 0);
    });
  });

  group('taps', () {
    test('open the chat that was tapped', () async {
      build();

      service.tap('s2', profile: 'work');
      await Future<void>.delayed(Duration.zero);

      expect(opened.single.threadId, 's2');
      expect(opened.single.profile, 'work');
    });

    test('are ignored after dispose', () async {
      build();
      notifier.dispose();

      service.tap('s2');
      await Future<void>.delayed(Duration.zero);

      expect(opened, isEmpty);
    });
  });

  group('launch', () {
    test('hands over the chat that started the app once', () async {
      service.launchThread = 's2';
      build();

      final first = await notifier.takeLaunchTarget();
      final second = await notifier.takeLaunchTarget();

      expect(first?.threadId, 's2');
      expect(second, isNull);
    });

    test('is empty when no notification started the app', () async {
      build();

      expect(await notifier.takeLaunchTarget(), isNull);
    });
  });

  group('focus', () {
    void announceOnScreen() => notifier.announce(
      thread,
      const ReplyCompleted('Nothing new.'),
      selectedThreadId: 's1',
      profile: null,
    );

    test('follows the app lifecycle', () {
      build();
      leaveTheApp();
      announceOnScreen();
      expect(service.shown, hasLength(1));

      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      announceOnScreen();
      expect(service.shown, hasLength(1));
    });

    test('stops following after dispose', () {
      build();
      notifier.dispose();

      leaveTheApp();
      announceOnScreen();

      expect(service.shown, isEmpty);
    });
  });
}
