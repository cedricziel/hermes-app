import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/watch/watch_bridge.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = StandardMethodCodec();
  late FakeHermesServer server;
  late WatchBridge bridge;

  /// Calls the bridge the way the iOS runner does and decodes the reply.
  Future<Object?> fromNative(String method, Object? arguments) async {
    final reply = Completer<ByteData?>();
    unawaited(
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            WatchBridge.channelName,
            codec.encodeMethodCall(MethodCall(method, arguments)),
            reply.complete,
          ),
    );
    final data = await reply.future;
    return data == null ? null : codec.decodeEnvelope(data);
  }

  setUp(() {
    server = FakeHermesServer();
    bridge = WatchBridge(
      handler: WatchRequestHandler(
        repository: () => HermesChatRepository(server.client().raw),
        transport: () => FakeChatTransport(),
        activeProfile: () async => null,
      ),
    )..start();
  });

  tearDown(() => bridge.dispose());

  test(
    'hands a relayed request to the handler and returns its reply',
    () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Groceries')]),
      );

      final result = await fromNative('request', {
        'op': 'threads',
      }) as Map<Object?, Object?>;

      expect(result['ok'], isTrue);
      final threads = result['threads'] as List<Object?>;
      expect((threads.single as Map<Object?, Object?>)['id'], '/s1');
    },
  );

  test('answers a malformed request instead of throwing', () async {
    final result = await fromNative('request', null) as Map;

    expect(result, {'ok': false, 'error': 'bad_request'});
  });

  test('ignores calls it does not know', () async {
    expect(await fromNative('nope', null), isNull);
  });

  group('announcer', () {
    const notification = AttentionNotification(
      threadId: 's1',
      title: 'Hermes',
      body: 'Done',
    );
    late FakeNotificationService service;
    late NotificationSettings settings;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      service = FakeNotificationService();
      settings = NotificationSettings();
      await settings.load();
    });

    test('shows the notification while notifications are on', () {
      WatchBridge.announcer(service, settings)(notification);

      expect(service.shown, [notification]);
    });

    test('shows nothing while notifications are off', () async {
      await settings.setEnabled(false);

      WatchBridge.announcer(service, settings)(notification);

      expect(service.shown, isEmpty);
    });

    test('shows nothing until the saved setting has loaded', () {
      WatchBridge.announcer(service, NotificationSettings())(notification);

      expect(service.shown, isEmpty);
    });

    test('shows the notification when there are no settings', () {
      WatchBridge.announcer(service, null)(notification);

      expect(service.shown, [notification]);
    });

    test('does nothing without a service', () {
      expect(
        () => WatchBridge.announcer(null, settings)(notification),
        returnsNormally,
      );
    });

    test('never asks for permission', () {
      WatchBridge.announcer(service, settings)(notification);

      expect(service.permissionRequests, 0);
    });

    test('a service that fails does not reach the caller', () async {
      final announce = WatchBridge.announcer(_FailingService(), settings);

      expect(() => announce(notification), returnsNormally);
      await pumpEventQueue();
    });
  });
}

class _FailingService extends FakeNotificationService {
  @override
  Future<void> show(AttentionNotification notification) =>
      Future.error(StateError('no notifications here'));
}
