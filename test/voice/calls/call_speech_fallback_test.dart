import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/voice/calls/call_speech_stream.dart';
import 'package:hermes_app/src/voice/synthesized_speech.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../support/fake_hermes_server.dart';
import 'fakes.dart';

void main() {
  for (final early in [true, false]) {
    test(
      'fallback ${early ? 'before' : 'after'} completion speaks the whole reply once and drains',
      () async {
        final socket = StreamChannelController<Object?>();
        final frames = <Object?>[];
        socket.foreign.stream.listen(frames.add);
        final output = FakeCallBridge()..drainGate = Completer<void>();
        final requests = <String>[];
        var failures = 0, audible = 0;
        final stream = CallSpeechStream(
          connect: ([_ = const {}]) async => socket.local,
          output: output,
          onFailure: (_) => failures++,
          onAudio: () => audible++,
          fallback: (text, profile, cancellation) async {
            expect(profile, 'work');
            expect(cancellation.isCancelled, isFalse);
            requests.add(text);
            return Uint8List.fromList([1, 2, 3, 4]);
          },
        );
        stream.append('Hello ');
        await stream.open('work');
        if (early) {
          socket.foreign.sink.add(jsonEncode({'type': 'fallback'}));
          await pumpEventQueue();
          expect(
            requests,
            isEmpty,
            reason: 'Wait for the complete assistant reply',
          );
        }
        stream.append('from Piper.');
        var drained = false;
        final done = stream.finish().then((_) => drained = true);
        if (!early) socket.foreign.sink.add(jsonEncode({'type': 'fallback'}));
        await pumpEventQueue();
        expect(requests, ['Hello from Piper.']);
        expect(output.played, hasLength(1));
        expect(output.played.single.$1, [1, 2, 3, 4]);
        expect(output.played.single.$2, 24000);
        expect(failures, 0);
        expect(audible, 1);
        expect(drained, isFalse);
        output.drainGate!.complete();
        await done;
        expect(drained, isTrue);
        await stream.close();
      },
    );
  }

  for (final closeOnly in [false, true]) {
    test(
      '${closeOnly ? 'close' : 'hang-up'} cancels fallback and ignores late audio',
      () async {
        final socket = StreamChannelController<Object?>();
        socket.foreign.stream.listen((_) {});
        final pending = Completer<Uint8List>();
        CancelToken? cancellation;
        var failures = 0;
        final output = FakeCallBridge();
        final stream = CallSpeechStream(
          connect: ([_ = const {}]) async => socket.local,
          output: output,
          onFailure: (_) => failures++,
          fallback: (_, _, token) {
            cancellation = token;
            return pending.future;
          },
        );
        await stream.open(null);
        stream.append('Old turn');
        final done = stream.finish();
        socket.foreign.sink.add(jsonEncode({'type': 'fallback'}));
        await pumpEventQueue();
        expect(cancellation, isNotNull);
        if (closeOnly) {
          await stream.close();
        } else {
          await stream.stop();
        }
        expect(cancellation!.isCancelled, isTrue);
        pending.complete(Uint8List.fromList([1, 2]));
        await done;
        await pumpEventQueue();
        expect(output.played, isEmpty);
        expect(failures, 0);
        expect(output.stops, closeOnly ? 0 : 1);
      },
    );
  }

  test('a fallback frame after PCM counts as finished and never repeats spoken text', () async {
    final socket = StreamChannelController<Object?>();
    socket.foreign.stream.listen((_) {});
    var requested = false, failures = 0;
    final output = FakeCallBridge();
    final stream = CallSpeechStream(
      connect: ([_ = const {}]) async => socket.local,
      output: output,
      onFailure: (_) => failures++,
      fallback: (_, _, _) async {
        requested = true;
        return Uint8List(2);
      },
    );
    await stream.open(null);
    socket.foreign.sink
      ..add(jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}))
      ..add([1, 2])
      ..add(jsonEncode({'type': 'fallback'}));
    await pumpEventQueue();
    await stream.finish();
    expect(requested, isFalse);
    expect(failures, 0);
  });

  test('a socket that drops after audio counts as finished', () async {
    final socket = StreamChannelController<Object?>();
    socket.foreign.stream.listen((_) {});
    var requested = false, failures = 0;
    final stream = CallSpeechStream(
      connect: ([_ = const {}]) async => socket.local,
      output: FakeCallBridge(),
      onFailure: (_) => failures++,
      fallback: (_, _, _) async {
        requested = true;
        return Uint8List(2);
      },
    );
    await stream.open(null);
    stream.append('Hello. ');
    socket.foreign.sink
      ..add(jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}))
      ..add([1, 2, 3, 4]);
    await pumpEventQueue();
    await socket.foreign.sink.close();
    await pumpEventQueue();
    await stream.finish();
    expect(requested, isFalse);
    expect(failures, 0);
  });

  for (final cause in ['dropped socket', 'error frame', 'failed open']) {
    test('a $cause before any audio falls back once', () async {
      final socket = StreamChannelController<Object?>();
      socket.foreign.stream.listen((_) {});
      final requests = <String>[];
      var failures = 0;
      final output = FakeCallBridge();
      final stream = CallSpeechStream(
        connect: ([_ = const {}]) async => cause == 'failed open'
            ? throw StateError('no socket')
            : socket.local,
        output: output,
        onFailure: (_) => failures++,
        fallback: (text, _, _) async {
          requests.add(text);
          return Uint8List.fromList([1, 2, 3, 4]);
        },
      );
      stream.append('Hello ');
      await stream.open(null);
      if (cause == 'dropped socket') {
        await socket.foreign.sink.close();
      } else if (cause == 'error frame') {
        socket.foreign.sink.add(jsonEncode({'type': 'error'}));
      }
      await pumpEventQueue();
      stream.append('there.');
      await stream.finish();
      expect(requests, ['Hello there.']);
      expect(output.played.single.$1, [1, 2, 3, 4]);
      expect(failures, 0);
    });
  }

  test('a failed fallback fails once, without a second fallback', () async {
    final socket = StreamChannelController<Object?>();
    socket.foreign.stream.listen((_) {});
    var requests = 0, failures = 0;
    final stream = CallSpeechStream(
      connect: ([_ = const {}]) async => socket.local,
      output: FakeCallBridge(),
      onFailure: (_) => failures++,
      fallback: (_, _, _) async {
        requests++;
        throw StateError('provider down');
      },
    );
    await stream.open(null);
    stream.append('Hello');
    final done = stream.finish();
    final failed = expectLater(done, throwsStateError);
    socket.foreign.sink.add(jsonEncode({'type': 'error'}));
    await failed;
    expect(requests, 1);
    expect(failures, 1);
  });

  test('without a fallback a failure before audio fails the stream', () async {
    final socket = StreamChannelController<Object?>();
    socket.foreign.stream.listen((_) {});
    var failures = 0;
    final stream = CallSpeechStream(
      connect: ([_ = const {}]) async => socket.local,
      output: FakeCallBridge(),
      onFailure: (_) => failures++,
    );
    await stream.open(null);
    socket.foreign.sink.add(jsonEncode({'type': 'error'}));
    await pumpEventQueue();
    expect(failures, 1);
  });

  test(
    'fallback failures reach the existing recoverable call failure',
    () async {
      final socket = StreamChannelController<Object?>();
      socket.foreign.stream.listen((_) {});
      var failures = 0;
      final stream = CallSpeechStream(
        connect: ([_ = const {}]) async => socket.local,
        output: FakeCallBridge(),
        onFailure: (_) => failures++,
        fallback: (_, _, _) async => throw StateError('Speech unavailable'),
      );
      await stream.open(null);
      stream.append('Hello');
      final done = stream.finish();
      final failed = expectLater(done, throwsStateError);
      socket.foreign.sink.add(jsonEncode({'type': 'fallback'}));
      await failed;
      expect(failures, 1);
    },
  );

  test(
    'POST uses the generated client, captured profile and cancel token',
    () async {
      final server = FakeHermesServer()
        ..on('POST', '/api/audio/speak', {
          'ok': true,
          'data_url': 'data:audio/ogg;base64,AQIDBA==',
          'mime_type': 'audio/ogg',
        });
      final speech = await HermesChatRepository(server.client().raw).synthesize(
        'Hello Piper.',
        profile: 'work',
        cancellation: CancelToken(),
      );
      expect(speech.mimeType, 'audio/ogg');
      expect(speech.bytes, [1, 2, 3, 4]);
      expect(server.requests.single.queryParameters, {'profile': 'work'});
      expect(jsonBody(server.requests.single), {'text': 'Hello Piper.'});
      final cancelled = CancelToken()..cancel();
      await expectLater(
        HermesChatRepository(server.client().raw)
            .synthesize('Do not send', cancellation: cancelled),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(server.requests, hasLength(1));
    },
  );

  test('rejects remote URLs, malformed audio and server errors', () {
    for (final body in [
      {'ok': false, 'data_url': 'data:audio/ogg;base64,AQI='},
      {'ok': true, 'data_url': 'https://provider.example/secret'},
      {'ok': true, 'data_url': 'data:text/html;base64,AQI='},
      {'ok': true, 'data_url': 'data:audio/ogg;base64,invalid!'},
      {'ok': true, 'data_url': 'data:audio/ogg;base64,'},
    ]) {
      expect(() => SynthesizedSpeech.fromJson(body), throwsFormatException);
    }
  });
}
