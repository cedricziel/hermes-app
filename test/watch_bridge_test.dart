import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:hermes_app/src/voice/on_device_speech.dart';
import 'package:hermes_app/src/watch/watch_bridge.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';
import 'support/recorded_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = StandardMethodCodec();
  late FakeHermesServer server;
  late WatchBridge bridge;
  late RecordedEvents events;

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
    events = RecordedEvents();
    bridge = WatchBridge(
      events: events.call,
      authState: () => 'ready',
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

  test(
    'records operation, auth state, outcome and duration without content',
    () async {
      final result = await fromNative('request', {
        'op': 'send',
        'text': 'private message',
        'threadId': 'private thread',
        'audio': Uint8List.fromList([1, 2]),
      });

      expect(result, {'ok': false, 'error': 'bad_request'});
      expect(events.named('watch.request.started'), [
        {'watch.operation': 'send', 'auth.state': 'ready'},
      ]);
      final completed = events.named('watch.request.completed').single;
      expect(completed, {
        'watch.operation': 'send',
        'auth.state': 'ready',
        'watch.result': 'bad_request',
        'watch.duration_ms': isNonNegative,
      });
    },
  );

  test('records the failures the watch had reaching the phone', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await fromNative('request', {
      'op': 'threads',
      'diagnostics': [
        {'op': 'send', 'reason': 'not_reachable', 'at': now - 90},
        {'op': 'private text', 'reason': 'delivery:7012', 'at': now - 5},
        'not a map',
      ],
    });

    expect(events.named('watch.delivery.failed'), [
      {
        'watch.operation': 'send',
        'watch.failure': 'not_reachable',
        'watch.failure_age_s': inInclusiveRange(89, 95),
      },
      {
        'watch.operation': 'unknown',
        'watch.failure': 'delivery:7012',
        'watch.failure_age_s': inInclusiveRange(4, 10),
      },
    ]);
  });

  test('records signed out with the current phone auth state', () async {
    bridge.dispose();
    bridge = WatchBridge(
      events: events.call,
      authState: () => 'needsLogin',
      handler: WatchRequestHandler(
        repository: () => null,
        transport: () => null,
        activeProfile: () async => null,
      ),
    )..start();

    await fromNative('request', {'op': 'threads'});

    expect(events.named('watch.request.completed').single, {
      'watch.operation': 'threads',
      'auth.state': 'needsLogin',
      'watch.result': 'signed_out',
      'watch.duration_ms': isNonNegative,
    });
  });

  test('does not record arbitrary operation names', () async {
    await fromNative('request', {'op': 'private user input'});

    expect(
      events.named('watch.request.started').single['watch.operation'],
      'unknown',
    );
  });

  test('records successful requests', () async {
    server.on('GET', '/api/sessions', sessionListBody([]));

    await fromNative('request', {'op': 'threads'});

    expect(
      events.named('watch.request.completed').single['watch.result'],
      'ok',
    );
  });

  test('telemetry failure does not prevent a watch reply', () async {
    bridge.dispose();
    bridge = WatchBridge(
      events: (name, [attributes = const {}]) =>
          throw StateError('logger failed'),
      handler: WatchRequestHandler(
        repository: () => null,
        transport: () => null,
        activeProfile: () async => null,
      ),
    )..start();

    expect(await fromNative('request', {'op': 'threads'}), {
      'ok': false,
      'error': 'signed_out',
    });
  });

  for (final error in [null, 42, 'private error details']) {
    test('records a safe fallback for handler error $error', () async {
      bridge.dispose();
      final reply = <String, Object?>{'ok': false, 'error': error};
      bridge = WatchBridge(events: events.call, handler: _ReplyHandler(reply))
        ..start();

      expect(await fromNative('request', {'op': 'threads'}), reply);
      expect(
        events.named('watch.request.completed').single['watch.result'],
        'failed',
      );
    });
  }

  test('records which engine transcribed a voice message', () async {
    bridge.dispose();
    bridge = WatchBridge(
      events: events.call,
      authState: () => 'ready',
      handler: _ReplyHandler({'ok': true, 'text': 'Hi', 'engine': 'device'}),
    )..start();

    expect(await fromNative('request', {'op': 'transcribe'}), {
      'ok': true,
      'text': 'Hi',
    });
    expect(events.named('watch.request.completed').single, {
      'watch.operation': 'transcribe',
      'auth.state': 'ready',
      'watch.result': 'ok',
      'watch.duration_ms': isNonNegative,
      'watch.transcribe_engine': 'device',
    });
  });

  group('onDeviceTranscriber', () {
    final audio = Uint8List.fromList([1, 2, 3]);
    late _FakeSpeech speech;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      speech = _FakeSpeech();
    });

    test('transcribes in the device language for the device engine', () async {
      final dictation = DictationSettings();
      await dictation.setEngine(DictationEngine.device);

      final text = await WatchBridge.onDeviceTranscriber(speech, dictation)(
        audio,
      );

      expect(text, 'Remind me to call Sam');
      expect(speech.files, [(audio, OnDeviceSpeech.deviceLocale())]);
    });

    test('leaves the recording to the server for the Hermes engine', () async {
      final dictation = DictationSettings();
      await dictation.setEngine(DictationEngine.hermes);

      expect(
        await WatchBridge.onDeviceTranscriber(speech, dictation)(audio),
        isNull,
      );
      expect(speech.files, isEmpty);
    });

    test('reads the saved engine first when the app just woke', () async {
      await DictationSettings().setEngine(DictationEngine.device);
      final dictation = DictationSettings();

      await WatchBridge.onDeviceTranscriber(speech, dictation)(audio);

      expect(dictation.loaded, isTrue);
      expect(speech.files, hasLength(1));
    });
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

    test('shows the notification while notifications are on', () async {
      expect(
        await WatchBridge.announcer(service, settings)(notification),
        isTrue,
      );

      expect(service.shown, [notification]);
    });

    test('shows nothing while notifications are off', () async {
      await settings.setEnabled(false);

      expect(
        await WatchBridge.announcer(service, settings)(notification),
        isFalse,
      );
      expect(service.shown, isEmpty);
    });

    test('shows nothing while the permission was denied', () async {
      await settings.recordPermission(granted: false);

      expect(
        await WatchBridge.announcer(service, settings)(notification),
        isFalse,
      );
      expect(service.shown, isEmpty);
    });

    test('reads the saved setting first when it has not loaded', () async {
      final fresh = NotificationSettings();

      expect(await WatchBridge.announcer(service, fresh)(notification), isTrue);
      expect(fresh.loaded, isTrue);
    });

    test('shows the notification when there are no settings', () async {
      await WatchBridge.announcer(service, null)(notification);

      expect(service.shown, [notification]);
    });

    test('says nothing was posted without a service', () async {
      expect(
        await WatchBridge.announcer(null, settings)(notification),
        isFalse,
      );
    });

    test('never asks for permission', () async {
      await WatchBridge.announcer(service, settings)(notification);

      expect(service.permissionRequests, 0);
    });

    test('a service that fails says nothing was posted', () async {
      final announce = WatchBridge.announcer(_FailingService(), settings);

      expect(await announce(notification), isFalse);
    });
  });
}

class _FailingService extends FakeNotificationService {
  @override
  Future<void> show(AttentionNotification notification) =>
      Future.error(StateError('no notifications here'));
}

class _ReplyHandler extends WatchRequestHandler {
  _ReplyHandler(this.reply)
    : super(
        repository: () => null,
        transport: () => null,
        activeProfile: () async => null,
      );

  final Map<String, Object?> reply;

  @override
  Future<Map<String, Object?>> handle(Map<Object?, Object?> request) async =>
      reply;
}

class _FakeSpeech extends OnDeviceSpeech {
  final files = <(Uint8List, String)>[];

  @override
  Future<String> transcribeFile(
    Uint8List audio, {
    required String locale,
  }) async {
    files.add((audio, locale));
    return 'Remind me to call Sam';
  }
}
