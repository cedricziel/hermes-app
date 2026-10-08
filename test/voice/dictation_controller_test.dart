import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/voice/dictation_controller.dart';
import 'package:hermes_app/src/voice/voice_support.dart';
import 'package:stream_channel/stream_channel.dart';

import '../support/fake_hermes_server.dart';
import '../support/fake_voice_recorder.dart';

const _live = VoiceSupport(speechToText: true, liveTranscription: true);
const _uploadOnly = VoiceSupport(speechToText: true);

void main() {
  late FakeHermesServer server;
  late FakeVoiceRecorder recorder;
  late List<String> inserted;
  late List<StreamChannelController<Object?>> sockets;
  late BreadcrumbTrail trail;

  setUp(() {
    server = FakeHermesServer()
      ..on('POST', '/api/audio/stt-lease', {'ok': true})
      ..on('POST', '/api/audio/transcribe', {
        'ok': true,
        'transcript': 'from the upload',
        'provider': 'local',
      });
    recorder = FakeVoiceRecorder();
    inserted = [];
    sockets = [];
    trail = BreadcrumbTrail();
  });

  DictationController controller({
    VoiceSupport support = _live,
    String? profile = 'work',
  }) => DictationController(
    api: server.client(),
    connect: ([query = const {}]) async {
      final socket = StreamChannelController<Object?>();
      sockets.add(socket);
      return socket.local;
    },
    recorder: recorder,
    onTranscript: inserted.add,
    breadcrumbs: Breadcrumbs.of(trail),
  )..configure(profile: profile, support: support);

  void serverSends(Map<String, Object?> frame) =>
      sockets.last.foreign.sink.add(jsonEncode(frame));

  Map<String, Object?> body(Object? data) =>
      (data is String ? jsonDecode(data) : data) as Map<String, Object?>;

  Map<String, Object?> uploadBody() =>
      body(server.requestsTo('POST', '/api/audio/transcribe').single.data);

  List<Map<String, Object?>> leases() => [
    for (final r in server.requestsTo('POST', '/api/audio/stt-lease'))
      body(r.data),
  ];

  test('records 16 kHz audio and inserts the live transcript', () async {
    final dictation = controller();

    await dictation.start();
    expect(dictation.phase, DictationPhase.recording);
    expect(recorder.sampleRate, 16000);
    recorder.speak([1000, -1000]);
    await pumpEventQueue();
    serverSends({'type': 'partial', 'text': 'book a'});
    await pumpEventQueue();
    expect(dictation.liveTranscript, 'book a');

    final stopping = dictation.stop();
    await pumpEventQueue();
    expect(dictation.phase, DictationPhase.settling);
    serverSends({'type': 'final', 'transcript': 'book a table'});
    await stopping;

    expect(inserted, ['book a table']);
    expect(dictation.phase, DictationPhase.idle);
    expect(recorder.recording, isFalse);
    expect(server.requestsTo('POST', '/api/audio/transcribe'), isEmpty);
  });

  test('an error frame falls back to uploading the recording as WAV', () async {
    final dictation = controller();
    await dictation.start();
    serverSends({'type': 'error', 'message': 'no live STT'});
    recorder.speak([1, 2, 3]);
    await pumpEventQueue();

    await dictation.stop();

    expect(inserted, ['from the upload']);
    final body = uploadBody();
    expect(body['mime_type'], 'audio/wav');
    final dataUrl = body['data_url'] as String;
    expect(dataUrl, startsWith('data:audio/wav;base64,'));
    final wav = base64Decode(dataUrl.split(',').last);
    expect(wav, hasLength(44 + 6));
    expect(
      server
          .requestsTo('POST', '/api/audio/transcribe')
          .single
          .queryParameters['profile'],
      'work',
    );
  });

  test('without live transcription the recording is uploaded', () async {
    final dictation = controller(support: _uploadOnly);
    await dictation.start();
    recorder.speak([5]);
    await pumpEventQueue();

    await dictation.stop();

    expect(sockets, isEmpty);
    expect(inserted, ['from the upload']);
  });

  test('an empty live transcript is checked by an upload', () async {
    final dictation = controller();
    await dictation.start();
    recorder.speak([5]);
    await pumpEventQueue();

    final stopping = dictation.stop();
    await pumpEventQueue();
    serverSends({'type': 'final', 'transcript': '  '});
    await stopping;

    expect(inserted, ['from the upload']);
  });

  test('silence from both paths reports that no speech was heard', () async {
    server.on('POST', '/api/audio/transcribe', {'ok': true, 'transcript': ''});
    final dictation = controller(support: _uploadOnly);
    await dictation.start();
    recorder.speak([0]);
    await pumpEventQueue();

    await dictation.stop();

    expect(inserted, isEmpty);
    expect(dictation.phase, DictationPhase.noSpeech);
  });

  test('a failed upload keeps the recording for a retry', () async {
    server.on('POST', '/api/audio/transcribe', {
      'detail': 'Transcription failed',
    }, status: 500);
    final dictation = controller(support: _uploadOnly);
    await dictation.start();
    recorder.speak([5]);
    await pumpEventQueue();

    await dictation.stop();
    expect(dictation.phase, DictationPhase.failed);
    expect(dictation.canRetry, isTrue);
    expect(inserted, isEmpty);

    server.on('POST', '/api/audio/transcribe', {
      'ok': true,
      'transcript': 'second try',
    });
    await dictation.retry();

    expect(inserted, ['second try']);
    expect(dictation.phase, DictationPhase.idle);
    expect(dictation.canRetry, isFalse);
  });

  test('cancel discards the recording and sends nothing', () async {
    final dictation = controller();
    await dictation.start();
    recorder.speak([5]);
    await pumpEventQueue();

    await dictation.cancel();
    await pumpEventQueue();

    expect(dictation.phase, DictationPhase.idle);
    expect(recorder.recording, isFalse);
    expect(server.requestsTo('POST', '/api/audio/transcribe'), isEmpty);
    expect(inserted, isEmpty);
  });

  test('switching profile drops a recording', () async {
    final dictation = controller();
    await dictation.start();

    dictation.configure(profile: 'home', support: _live);
    await pumpEventQueue();

    expect(dictation.phase, DictationPhase.idle);
    expect(recorder.recording, isFalse);
  });

  test('denied microphone access records nothing', () async {
    recorder.permission = false;
    final dictation = controller();

    await dictation.start();

    expect(dictation.phase, DictationPhase.denied);
    expect(recorder.starts, 0);
    expect(trail.recent.last.name, 'voice.dictation.ended');
    expect(trail.recent.last.attributes['outcome'], 'denied');
  });

  test('stops by itself after five minutes', () {
    fakeAsync((async) {
      final dictation = controller(support: _uploadOnly);
      dictation.start();
      async.flushMicrotasks();
      recorder.speak([5]);

      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(dictation.phase, DictationPhase.recording);
      expect(dictation.elapsed.inSeconds, greaterThanOrEqualTo(298));

      async.elapse(const Duration(seconds: 2));
      expect(recorder.recording, isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(inserted, ['from the upload']);
    });
  });

  test('holds a speech-to-text lease while recording', () async {
    final dictation = controller();
    await dictation.start();
    await pumpEventQueue();
    expect(leases().single['active'], isTrue);
    expect(leases().single['lease'], startsWith('app:voice-input:'));

    await dictation.cancel();
    await pumpEventQueue();

    expect(leases().map((l) => l['active']), [true, false]);
    expect(leases().last['lease'], leases().first['lease']);
  });

  test('a failing lease does not stop the recording', () async {
    server.on('POST', '/api/audio/stt-lease', {'detail': 'x'}, status: 500);
    final dictation = controller(support: _uploadOnly);

    await dictation.start();
    recorder.speak([5]);
    await pumpEventQueue();
    await dictation.stop();

    expect(inserted, ['from the upload']);
  });

  test('the level follows the input volume', () async {
    final dictation = controller(support: _uploadOnly);
    await dictation.start();

    recorder.speak(List.filled(320, 0));
    await pumpEventQueue();
    final quiet = dictation.level;
    recorder.speak(List.filled(320, 16000));
    await pumpEventQueue();

    expect(quiet, 0);
    expect(dictation.level, greaterThan(0.5));
  });

  test('breadcrumbs carry the outcome and path, never the text', () async {
    final dictation = controller();
    await dictation.start();
    final stopping = dictation.stop();
    await pumpEventQueue();
    serverSends({'type': 'final', 'transcript': 'secret words'});
    await stopping;

    final names = trail.recent.map((c) => c.name).toList();
    expect(names, ['voice.dictation.started', 'voice.dictation.ended']);
    expect(trail.recent.last.attributes, {
      'outcome': 'inserted',
      'path': 'stream',
    });
    expect(trail.recent.toString(), isNot(contains('secret')));
  });
}
