import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:stream_channel/stream_channel.dart';

import 'fakes.dart';

void main() {
  late FakeCallBridge bridge;
  late FakeCallAgent agent;
  late VoiceCall call;
  late Completer<String> transcript;
  late StreamChannelController<Object?> socket;
  var uploads = 0;
  setUp(() {
    bridge = FakeCallBridge();
    agent = FakeCallAgent();
    transcript = Completer<String>();
    socket = StreamChannelController<Object?>();
    socket.foreign.stream.listen((_) {});
    uploads = 0;
    call = VoiceCall(
      bridge: bridge,
      agent: agent,
      connect: ([_ = const {}]) async => socket.local,
      prepare: () async {},
      transcribe: (wav) {
        uploads++;
        expect(utf8.decode(wav.sublist(0, 4)), 'RIFF');
        return transcript.future;
      },
    );
    addTearDown(() async {
      await call.end();
      call.dispose();
      await bridge.controller.close();
    });
  });
  void utterance() {
    bridge.emit('pcm', {'data': pcm()});
    for (var i = 0; i < 9; i++) {
      bridge.emit('pcm', {'data': pcm(amplitude: 0)});
    }
  }

  Future<void> activate() async {
    await call.start();
    bridge.emit('activated');
  }

  test(
    'no microphone is processed before native activation or while muted',
    () async {
      await call.start();
      utterance();
      expect(uploads, 0);
      bridge.emit('activated');
      await call.setMuted(true);
      utterance();
      expect(uploads, 0);
      await call.setMuted(false);
      utterance();
      await pumpEventQueue();
      expect(uploads, 1);
    },
  );
  test(
    'hang-up discards an in-flight transcript and releases audio once',
    () async {
      await activate();
      utterance();
      await pumpEventQueue();
      expect(uploads, 1);
      await call.end();
      transcript.complete('Send this later');
      await pumpEventQueue();
      expect(agent.prompts, isEmpty);
      expect(bridge.ends, 1);
      expect(call.phase, CallPhase.ended);
    },
  );
  test('system mute during transcription discards that turn', () async {
    await activate();
    utterance();
    await pumpEventQueue();
    await call.setMuted(true);
    transcript.complete('Do not send');
    await pumpEventQueue();
    expect(agent.prompts, isEmpty);
  });
  test(
    'speaks a reply, then listens after playback; context stays in normal chat',
    () async {
      await activate();
      utterance();
      transcript.complete('What is next?');
      await pumpEventQueue();
      expect(agent.prompts, ['What is next?']);
      expect(call.phase, CallPhase.thinking);
      agent.text!('A meeting.');
      agent.pending!.complete();
      socket.foreign.sink
        ..add(
          jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}),
        )
        ..add([0, 1, 2, 3]);
      await pumpEventQueue();
      expect(call.phase, CallPhase.speaking);
      socket.foreign.sink.add(jsonEncode({'type': 'end'}));
      await pumpEventQueue();
      expect(call.phase, CallPhase.listening);
    },
  );
  test(
    'barge-in stops speech and the owned turn before accepting a new utterance',
    () async {
      await activate();
      utterance();
      transcript.complete('First');
      await pumpEventQueue();
      bridge.emit('pcm', {'data': pcm()});
      await pumpEventQueue();
      expect(agent.interrupts, 1);
      expect(bridge.stops, 1);
      expect(call.phase, CallPhase.listening);
    },
  );
  test(
    'route reset discards an in-flight transcript and resumes listening',
    () async {
      await activate();
      utterance();
      await pumpEventQueue();
      bridge.emit('audioReset');
      transcript.complete('Old route');
      await pumpEventQueue();
      expect(agent.prompts, isEmpty);
      expect(call.phase, CallPhase.listening);
      expect(call.caption, contains('Audio route changed'));
      expect(bridge.ends, 0);
    },
  );
  test('system end and audio interruption cancel the call', () async {
    await activate();
    bridge.emit('ended');
    await pumpEventQueue();
    expect(call.ended, isTrue);
    expect(bridge.ends, 1);
  });
  test('ending during readiness does not start a late native call', () async {
    call.dispose();
    final ready = Completer<void>();
    call = VoiceCall(
      bridge: bridge,
      agent: agent,
      connect: ([_ = const {}]) async => socket.local,
      transcribe: (_) async => '',
      prepare: () => ready.future,
    );
    final starting = call.start();
    await call.end();
    ready.complete();
    await starting;
    expect(bridge.starts, 0);
  });
}
