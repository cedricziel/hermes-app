import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'call_harness.dart';

void main() {
  late CallHarness h;

  setUp(() async {
    h = CallHarness();
    await h.activate();
  });
  tearDown(() => h.dispose());

  Map<String, Object> turn() =>
      h.logged.singleWhere((e) => e.$1 == 'voice_call.turn').$2;

  test('a spoken turn logs where its time went, in buckets only', () async {
    await h.say('Secret question');
    h.clock = h.clock.add(const Duration(seconds: 3));
    h.agent.text!('Secret answer.');
    h.clock = h.clock.add(const Duration(seconds: 1));
    h.socket.foreign.sink
      ..add(jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}))
      ..add([0, 1, 2, 3]);
    await pumpEventQueue();
    h.clock = h.clock.add(const Duration(seconds: 6));
    h.socket.foreign.sink.add(jsonEncode({'type': 'end'}));
    h.agent.pending!.complete();
    await pumpEventQueue();
    expect(turn(), {
      'transcription': '<0.5s',
      'speech_open': '<0.5s',
      'first_text': '2-5s',
      'first_audio': '2-5s',
      'reply_complete': '10-30s',
      'device_speech': false,
      'fallback': false,
      'outcome': 'spoken',
    });
    expect(h.logged.where((e) => e.$1 == 'voice_call.turn'), hasLength(1));
    expect(h.logged.toString(), isNot(contains("Secret")));
  });

  test(
    'a turn the chat refuses logs failed and the stages it never reached',
    () async {
      h.agent.replyError = StateError('refused');
      await h.say('Hello');
      expect(turn(), containsPair('outcome', 'failed'));
      expect(turn(), containsPair('first_text', 'none'));
      expect(turn(), containsPair('first_audio', 'none'));
      expect(turn(), containsPair('reply_complete', 'none'));
    },
  );

  test('a turn cut off by speaking over it logs interrupted', () async {
    await h.say('Hello');
    h.agent.text!('Hi.');
    await pumpEventQueue();
    h.utterance();
    h.transcripts.add('Wait');
    await pumpEventQueue();
    h.agent.pending!.complete();
    await pumpEventQueue();
    final turns = h.logged.where((e) => e.$1 == 'voice_call.turn');
    expect(turns.first.$2, containsPair('outcome', 'interrupted'));
  });

  test('a transient speech open failure is retried and counted', () async {
    var attempts = 0;
    h.openSocket = () {
      if (attempts++ == 0) {
        final options = RequestOptions(path: '/api/audio/speak-stream');
        return Future.error(
          DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 502),
          ),
        );
      }
      return Future.value(h.socket.local);
    };
    await h.say('Hello');
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await pumpEventQueue();
    expect(attempts, 2);
    expect(h.call.ended, isFalse);
    expect(h.agent.prompts, ['Hello']);
    h.agent.text!('Hi.');
    h.agent.pending!.complete();
    h.socket.foreign.sink
      ..add(jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}))
      ..add([0, 1])
      ..add(jsonEncode({'type': 'end'}));
    await pumpEventQueue();
    await h.call.end();
    expect(h.ended(), containsPair('speech_retries', '1'));
    expect(h.ended(), containsPair('outcome', 'ended'));
  });
}
