import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/transcribe_stream.dart';
import 'package:stream_channel/stream_channel.dart';

/// The server's end of one transcribe-stream socket.
class _Server {
  final controller = StreamChannelController<Object?>();
  final received = <Object?>[];
  var closed = false;

  _Server() {
    controller.foreign.stream.listen(received.add, onDone: () => closed = true);
  }

  void send(Map<String, Object?> frame) =>
      controller.foreign.sink.add(jsonEncode(frame));

  List<Map<String, Object?>> get textFrames => [
    for (final f in received)
      if (f is String) (jsonDecode(f) as Map).cast<String, Object?>(),
  ];

  List<Uint8List> get pcmFrames => [
    for (final f in received)
      if (f is List<int>) Uint8List.fromList(f),
  ];
}

Uint8List _pcm(int byte) => Uint8List.fromList([byte, byte]);

void main() {
  late _Server server;
  late Completer<StreamChannel<Object?>> opened;
  late List<Map<String, String>> queries;

  setUp(() {
    server = _Server();
    opened = Completer();
    queries = [];
  });

  TranscribeStream start({Map<String, String> query = const {}}) =>
      TranscribeStream.start(
        connect: ([q = const {}]) {
          queries.add(q);
          return opened.future;
        },
        sampleRate: 16000,
        query: query,
      );

  test('announces the sample rate, then sends PCM buffered before the socket '
      'opened', () async {
    final stream = start(query: {'profile': 'work'});
    stream.add(_pcm(1));
    stream.add(_pcm(2));

    opened.complete(server.controller.local);
    await pumpEventQueue();
    stream.add(_pcm(3));
    await pumpEventQueue();

    expect(queries.single, {'profile': 'work'});
    expect(server.received.first, jsonEncode({'sample_rate': 16000}));
    expect(server.pcmFrames, [_pcm(1), _pcm(2), _pcm(3)]);
  });

  test('passes on each partial and returns the final transcript', () async {
    final stream = start();
    final partials = <String>[];
    stream.partials.listen(partials.add);
    opened.complete(server.controller.local);
    await pumpEventQueue();

    server.send({'type': 'partial', 'text': 'book a'});
    server.send({'type': 'partial', 'text': 'book a table'});
    await pumpEventQueue();
    final result = stream.finish();
    await pumpEventQueue();
    expect(server.textFrames.last, {'eos': true});
    server.send({
      'type': 'final',
      'transcript': 'book a table for two',
      'provider': 'groq',
    });

    expect(await result, 'book a table for two');
    expect(partials, ['book a', 'book a table']);
  });

  test('an error frame fails the stream, so the caller uploads', () async {
    final stream = start();
    opened.complete(server.controller.local);
    await pumpEventQueue();

    server.send({
      'type': 'error',
      'message': 'no live STT for the configured provider',
    });
    await pumpEventQueue();

    expect(stream.failed, isTrue);
    expect(await stream.finish(), isNull);
  });

  test('a socket that closes before the final frame fails', () async {
    final stream = start();
    opened.complete(server.controller.local);
    await pumpEventQueue();

    final result = stream.finish();
    await pumpEventQueue();
    await server.controller.foreign.sink.close();

    expect(await result, isNull);
  });

  test('a socket that cannot connect fails', () async {
    final stream = start();
    opened.completeError(StateError('refused'));
    await pumpEventQueue();

    expect(stream.failed, isTrue);
    expect(await stream.finish(), isNull);
  });

  test('a socket that does not open within 5 s fails', () {
    fakeAsync((async) {
      final stream = start();
      async.elapse(const Duration(seconds: 5));

      expect(stream.failed, isTrue);
    });
  });

  test('cancel closes the socket without sending eos', () async {
    final stream = start();
    opened.complete(server.controller.local);
    await pumpEventQueue();

    stream.cancel();
    await pumpEventQueue();

    expect(server.closed, isTrue);
    expect(server.textFrames.where((f) => f['eos'] == true), isEmpty);
  });
}
