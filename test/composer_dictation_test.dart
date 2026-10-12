import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer_builder.dart';
import 'package:hermes_app/src/voice/composer_dictation.dart';
import 'package:hermes_app/src/voice/dictation_controller.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:hermes_app/src/voice/on_device_speech.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_voice_recorder.dart';
import 'support/fake_speech_channel.dart';

void main() {
  late FakeHermesServer server;
  late TextEditingController field;
  String? profile;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/audio/voice-config', {
        'ok': true,
        'stt': {'mode': 'relay', 'reason': 'local provider'},
        'tts': {'mode': 'relay'},
      });
    field = TextEditingController();
    profile = 'work';
  });

  tearDown(() => field.dispose());

  ComposerDictation build({
    DictationSettings? settings,
    ValueNotifier<bool>? activity,
    FakeVoiceRecorder? recorder,
    OnDeviceSpeech? onDevice,
    StreamChannelController<Object?>? socket,
  }) {
    final dictation = ComposerDictation(
      repository: HermesChatRepository(server.client().raw),
      connect: ([_ = const {}]) => socket == null
          ? Future.error(StateError('no socket'))
          : Future.value(socket.local),
      recorder: recorder ?? FakeVoiceRecorder(),
      field: field,
      profile: () => profile,
      settings: settings,
      activity: activity,
      onDevice: onDevice,
    );
    addTearDown(dictation.dispose);
    return dictation;
  }

  List<Object?> asked() => [
    for (final request in server.requestsTo('GET', '/api/audio/voice-config'))
      request.queryParameters['profile'],
  ];

  test('asks for the voice support of the profile it reads', () async {
    final dictation = build();

    await dictation.refresh();

    expect(asked(), ['work']);
    expect(dictation.controller.available, isTrue);
  });

  test('asks again only once the profile has changed', () async {
    final dictation = build();
    await dictation.refresh();

    dictation.followProfile();
    await pumpEventQueue();
    expect(asked(), ['work']);

    profile = 'home';
    dictation.followProfile();
    await pumpEventQueue();
    expect(asked(), ['work', 'home']);
  });

  test('waits for the Dictation setting before asking the server', () async {
    final settings = DictationSettings();
    build(settings: settings);

    await pumpEventQueue();
    expect(asked(), isEmpty);

    await settings.load();
    await pumpEventQueue();
    expect(asked(), ['work']);
  });

  test(
    'paused support lookup cannot restore availability after resume',
    () async {
      final pending = Completer<FakeResponse>();
      server.onRequest('GET', '/api/audio/voice-config', (_) => pending.future);
      final activity = ValueNotifier(true);
      final recorder = FakeVoiceRecorder();
      final dictation = build(activity: activity, recorder: recorder);
      final refreshing = dictation.refresh();
      await pumpEventQueue();

      activity.value = false;
      server.on('GET', '/api/audio/voice-config', {
        'stt': {'reason': 'stt disabled'},
      });
      activity.value = true;
      await pumpEventQueue();
      pending.complete((
        status: 200,
        body: {
          'stt': {'mode': 'relay'},
        },
      ));
      await refreshing;

      expect(asked(), ['work', 'work']);
      expect(dictation.controller.available, isFalse);
      expect(recorder.starts, 0);
    },
  );

  test('pause restores typed value before held microphone close', () async {
    final activity = ValueNotifier(true);
    final recorder = _HeldRecorder()..stopGate = Completer();
    final socket = StreamChannelController<Object?>();
    server.on('GET', '/api/audio/voice-config', {
      'stt': {'streaming': true},
    });
    final dictation = build(
      activity: activity,
      recorder: recorder,
      socket: socket,
    );
    const original = TextEditingValue(
      text: 'typed draft',
      selection: TextSelection(baseOffset: 2, extentOffset: 5),
    );
    field.value = original;
    await dictation.refresh();
    await dictation.controller.start();
    socket.foreign.sink.add(
      jsonEncode({'type': 'partial', 'text': 'provisional'}),
    );
    await pumpEventQueue();
    expect(field.text, contains('provisional'));

    activity.value = false;

    expect(field.value, original);
    expect(recorder.stopCalls, 1);
    expect(recorder.recording, isTrue);
    final elapsed = dictation.controller.elapsed;
    socket.foreign.sink.add(
      jsonEncode({'type': 'partial', 'text': 'late partial'}),
    );
    socket.foreign.sink.add(
      jsonEncode({'type': 'final', 'transcript': 'late final'}),
    );
    await pumpEventQueue();
    expect(field.value, original);
    expect(dictation.controller.liveTranscript, isEmpty);
    activity.value = true;
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(dictation.controller.elapsed, elapsed);
    expect(field.value, original);
    field.text = 'typed after resume';
    recorder.stopGate!.complete();
    await pumpEventQueue();
    expect(recorder.recording, isFalse);
    expect(field.text, 'typed after resume');
    expect(server.requestsTo('POST', '/api/audio/transcribe'), isEmpty);
  });

  test('pause ignores an already dispatched transcript upload', () async {
    final upload = Completer<FakeResponse>();
    server.onRequest('POST', '/api/audio/transcribe', (_) => upload.future);
    final activity = ValueNotifier(true);
    final recorder = FakeVoiceRecorder();
    final dictation = build(activity: activity, recorder: recorder);
    field.value = const TextEditingValue(
      text: 'typed',
      selection: TextSelection.collapsed(offset: 2),
    );
    final original = field.value;
    await dictation.refresh();
    await dictation.controller.start();
    recorder.speak([1]);
    await pumpEventQueue();
    final stopping = dictation.controller.stop();
    await pumpEventQueue();
    expect(server.requestsTo('POST', '/api/audio/transcribe'), hasLength(1));

    activity.value = false;
    expect(field.value, original);
    activity.value = true;
    await pumpEventQueue();
    upload.complete((status: 200, body: {'transcript': 'late upload'}));
    await stopping;

    expect(field.value, original);
    expect(dictation.controller.canRetry, isFalse);
    expect(server.requestsTo('POST', '/api/audio/transcribe'), hasLength(1));
  });

  test(
    'pause during transcript settlement cancels send and keeps the draft',
    () async {
      server.on('POST', '/api/audio/transcribe', {'transcript': 'voice reply'});
      final activity = ValueNotifier(true);
      final recorder = FakeVoiceRecorder();
      final dictation = build(activity: activity, recorder: recorder);
      const original = TextEditingValue(
        text: 'typed draft',
        selection: TextSelection.collapsed(offset: 5),
      );
      field.value = original;
      await dictation.refresh();
      await dictation.controller.start();
      recorder.speak([1]);
      await pumpEventQueue();
      var suspended = false;
      dictation.controller.addListener(() {
        if (!suspended && dictation.controller.phase == DictationPhase.idle) {
          suspended = true;
          activity.value = false;
          activity.value = true;
        }
      });
      final sent = <String>[];

      await sendAfterDictation(
        dictation.controller,
        field,
        sent.add,
        () => profile,
      );

      expect(suspended, isTrue);
      expect(field.value, original);
      expect(sent, isEmpty);
      expect(dictation.controller.lastOutcome, 'cancelled');
    },
  );

  test(
    'pause during silence settlement cancels send and keeps the draft',
    () async {
      final activity = ValueNotifier(true);
      final recorder = FakeVoiceRecorder();
      final dictation = build(activity: activity, recorder: recorder);
      const original = TextEditingValue(
        text: 'typed draft',
        selection: TextSelection.collapsed(offset: 5),
      );
      field.value = original;
      await dictation.refresh();
      await dictation.controller.start();
      var suspended = false;
      dictation.controller.addListener(() {
        if (!suspended &&
            dictation.controller.phase == DictationPhase.noSpeech) {
          suspended = true;
          activity.value = false;
          activity.value = true;
        }
      });
      final sent = <String>[];

      await sendAfterDictation(
        dictation.controller,
        field,
        sent.add,
        () => profile,
      );

      expect(suspended, isTrue);
      expect(field.value, original);
      expect(sent, isEmpty);
      expect(dictation.controller.lastOutcome, 'cancelled');
    },
  );

  test('paused refresh, start and retry send nothing', () async {
    final activity = ValueNotifier(false);
    final recorder = _HeldRecorder();
    final dictation = build(activity: activity, recorder: recorder);

    await dictation.refresh();
    dictation.followProfile();
    await dictation.controller.start();
    await dictation.controller.retry();
    await pumpEventQueue();

    expect(server.requests, isEmpty);
    expect(recorder.permissions, 0);
    expect(recorder.starts, 0);
  });

  test(
    'resume refreshes capabilities without recording or changing draft',
    () async {
      final activity = ValueNotifier(true);
      final recorder = FakeVoiceRecorder();
      final dictation = build(activity: activity, recorder: recorder);
      field.text = 'keep this draft';
      await dictation.refresh();

      activity.value = false;
      expect(dictation.controller.available, isFalse);
      await dictation.refresh();
      activity.value = true;
      await pumpEventQueue();

      expect(asked(), ['work', 'work']);
      expect(dictation.controller.available, isTrue);
      expect(field.text, 'keep this draft');
      expect(recorder.starts, 0);
      expect(server.requestsTo('POST', '/api/audio/transcribe'), isEmpty);
    },
  );

  test(
    'a held model check cannot download or offer dictation after pause',
    () async {
      final speech = FakeSpeechChannel()
        ..status = 'missing'
        ..statusGate = Completer();
      addTearDown(speech.dispose);
      final onDevice = OnDeviceSpeech();
      addTearDown(onDevice.dispose);
      final settings = DictationSettings();
      await settings.load();
      await settings.setEngine(DictationEngine.device);
      final activity = ValueNotifier(true);
      final dictation = build(
        activity: activity,
        settings: settings,
        onDevice: onDevice,
      );
      final refreshing = dictation.refresh();
      await pumpEventQueue();

      activity.value = false;
      speech.statusGate!.complete();
      await refreshing;
      await pumpEventQueue();

      expect(speech.methods, ['status']);
      expect(server.requests, isEmpty);
      expect(dictation.controller.available, isFalse);
    },
  );

  test('late recorder acquisition is closed before another start', () async {
    final activity = ValueNotifier(true);
    final recorder = _HeldRecorder()..startGate = Completer();
    final dictation = build(activity: activity, recorder: recorder);
    await dictation.refresh();
    final starting = dictation.controller.start();
    await pumpEventQueue();

    activity.value = false;
    activity.value = true;
    await pumpEventQueue();
    final overlapping = dictation.controller.start();
    await pumpEventQueue();
    expect(recorder.startCalls, 1);
    recorder.startGate!.complete();
    await starting;
    await overlapping;
    expect(recorder.recording, isFalse);
    expect(field.text, isEmpty);

    await dictation.controller.start();
    expect(recorder.startCalls, 2);
    expect(recorder.recording, isTrue);
    await dictation.controller.cancel();
  });

  test(
    'a held permission answer cannot start voice work after pause',
    () async {
      final activity = ValueNotifier(true);
      final recorder = _HeldRecorder()..permissionGate = Completer();
      final dictation = build(activity: activity, recorder: recorder);
      await dictation.refresh();
      final starting = dictation.controller.start();
      await pumpEventQueue();

      activity.value = false;
      recorder.permissionGate!.complete();
      await starting;
      await pumpEventQueue();

      expect(recorder.starts, 0);
      expect(server.requestsTo('POST', '/api/audio/stt-lease'), isEmpty);
      expect(server.requestsTo('POST', '/api/audio/transcribe'), isEmpty);
    },
  );
}

class _HeldRecorder extends FakeVoiceRecorder {
  Completer<void>? startGate;
  Completer<void>? stopGate;
  Completer<void>? permissionGate;
  var startCalls = 0;
  var stopCalls = 0;
  var permissions = 0;

  @override
  Future<bool> requestPermission() async {
    permissions++;
    await permissionGate?.future;
    return super.requestPermission();
  }

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    startCalls++;
    await startGate?.future;
    return super.start(sampleRate: sampleRate);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    await stopGate?.future;
    await super.stop();
  }
}
