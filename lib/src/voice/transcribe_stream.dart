import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

import '../chat/gateway/gateway_connection.dart';
import 'live_transcriber.dart';

/// Live transcription over the dashboard's `/api/audio/transcribe-stream`:
/// 16-bit mono PCM goes in while the user speaks, partial text and then the
/// final transcript come back.
///
/// Any failure (no socket within [openTimeout], an `error` frame, a socket
/// that closes before the final frame) leaves the stream [failed], and
/// [finish] answers null so the caller uploads its recording instead.
class TranscribeStream implements LiveTranscriber {
  TranscribeStream.start({
    required MixedSocketConnect connect,
    required int sampleRate,
    Map<String, String> query = const {},
    Duration openTimeout = const Duration(seconds: 5),
    this._finalTimeout = const Duration(seconds: 30),
  }) {
    _open(connect, sampleRate, query, openTimeout);
  }

  /// How long [finish] waits for the final transcript.
  final Duration _finalTimeout;

  final _partials = StreamController<String>.broadcast();
  final _result = Completer<String?>();
  final _pending = <Uint8List>[];
  StreamChannel<Object?>? _channel;
  StreamSubscription<Object?>? _frames;
  var _done = false;

  @override
  Stream<String> get partials => _partials.stream;

  /// Whether live transcription gave up.
  bool get failed => _result.isCompleted && !_done;

  Future<void> _open(
    MixedSocketConnect connect,
    int sampleRate,
    Map<String, String> query,
    Duration openTimeout,
  ) async {
    final StreamChannel<Object?> channel;
    try {
      channel = await connect(query).timeout(openTimeout);
    } on Object {
      _fail();
      return;
    }
    if (_result.isCompleted) {
      unawaited(channel.sink.close());
      return;
    }
    _channel = channel;
    _frames = channel.stream.listen(
      _onFrame,
      onDone: _fail,
      onError: (_) => _fail(),
    );
    channel.sink.add(jsonEncode({'sample_rate': sampleRate}));
    _pending.forEach(channel.sink.add);
    _pending.clear();
  }

  void _onFrame(Object? frame) {
    if (frame is! String) return;
    final Object? data;
    try {
      data = jsonDecode(frame);
    } on FormatException {
      return;
    }
    if (data is! Map) return;
    switch (data['type']) {
      case 'partial':
        if (data['text'] case final String text) _partials.add(text);
      case 'final':
        _complete((data['transcript'] as String?)?.trim() ?? '');
      case 'error':
        _fail();
    }
  }

  /// Held until the socket opens.
  @override
  void add(Uint8List pcm) {
    if (_result.isCompleted) return;
    if (_channel case final channel?) {
      channel.sink.add(pcm);
    } else {
      _pending.add(pcm);
    }
  }

  @override
  Future<String?> finish() {
    final channel = _channel;
    if (channel == null) {
      _fail();
    } else if (!_result.isCompleted) {
      channel.sink.add(jsonEncode({'eos': true}));
    }
    return _result.future.timeout(
      _finalTimeout,
      onTimeout: () {
        _fail();
        return null;
      },
    );
  }

  /// Closes the socket without asking for a transcript.
  @override
  void cancel() => _fail();

  void _complete(String transcript) {
    if (_result.isCompleted) return;
    _done = true;
    _result.complete(transcript);
    _close();
  }

  void _fail() {
    if (_result.isCompleted) return;
    _result.complete(null);
    _close();
  }

  void _close() {
    _pending.clear();
    unawaited(_frames?.cancel());
    unawaited(_channel?.sink.close());
    unawaited(_partials.close());
  }
}
