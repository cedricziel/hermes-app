import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:stream_channel/stream_channel.dart';

import '../../chat/gateway/gateway_connection.dart';
import 'call_bridge.dart';

/// Hermes' /api/audio/speak-stream: incremental text in, s16le mono PCM out.
/// Completion includes native speaker drain, rather than just socket EOF.
class CallSpeechStream {
  CallSpeechStream({
    required this.connect,
    required this.output,
    this.onAudio,
    this.onFailure,
  }) {
    unawaited(
      _done.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }
  final void Function()? onAudio;
  final void Function()? onFailure;
  bool hasText = false;
  final MixedSocketConnect connect;
  final CallBridge output;
  StreamChannel<Object?>? _socket;
  StreamSubscription<Object?>? _frames;
  final _done = Completer<void>();
  final _pending = <String>[];
  Future<void> _writes = Future.value();
  int? _rate;
  int? _oddByte;
  bool _stopped = false;
  bool _ended = false;
  bool _finishRequested = false;
  bool _produced = false;

  Future<void> open(String? profile) async {
    try {
      final opening = connect({'profile': ?profile});
      unawaited(
        opening.then<void>((socket) {
          if (_stopped) {
            unawaited(socket.sink.close().catchError((Object _) {}));
          }
        }, onError: (Object _, StackTrace _) {}),
      );
      final socket = await opening.timeout(const Duration(seconds: 10));
      if (_stopped) {
        await socket.sink.close();
        return;
      }
      _socket = socket;
      _frames = socket.stream.listen(
        _frame,
        onError: _fail,
        onDone: () {
          if (!_ended && !_stopped) {
            _fail(StateError('Speech stream ended early'));
          }
        },
      );
      for (final text in _pending) {
        socket.sink.add(jsonEncode({'text': text}));
      }
      _pending.clear();
      if (_finishRequested) socket.sink.add(jsonEncode({'done': true}));
    } on Object catch (error, stack) {
      _fail(error, stack);
      rethrow;
    }
  }

  void append(String text) {
    if (_stopped || _ended || text.isEmpty) return;
    hasText = true;
    if (_socket case final socket?) {
      socket.sink.add(jsonEncode({'text': text}));
    } else {
      _pending.add(text);
    }
  }

  Future<void> finish() {
    if (_stopped) return _done.future;
    _finishRequested = true;
    _socket?.sink.add(jsonEncode({'done': true}));
    return _done.future.timeout(const Duration(minutes: 3));
  }

  void _frame(Object? data) {
    if (_stopped || _ended) return;
    if (data is List<int>) {
      final rate = _rate;
      if (rate == null) {
        _fail(StateError('Speech format missing'));
        return;
      }
      final bytes = Uint8List.fromList([?_oddByte, ...data]);
      _oddByte = bytes.length.isOdd ? bytes.last : null;
      final even = bytes.length - (bytes.length % 2);
      if (even == 0) return;
      if (!_produced) onAudio?.call();
      _produced = true;
      _writes = _writes
          .then((_) async {
            if (!_stopped) {
              await output.play(Uint8List.sublistView(bytes, 0, even), rate);
            }
          })
          .catchError(_fail);
      return;
    }
    try {
      final frame = jsonDecode(data as String);
      switch (frame) {
        case {'type': 'start', 'sample_rate': final int rate, 'channels': 1}
            when rate >= 8000 && rate <= 96000:
          _rate = rate;
        case {'type': 'end'}:
          _ended = true;
          unawaited(_drain());
        case {'type': 'fallback'} || {'type': 'error'}:
          _fail(StateError('The server could not produce call audio'));
        default:
          _fail(StateError('Unsupported speech frame'));
      }
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  Future<void> _drain() async {
    try {
      await _writes;
      if (_stopped) return;
      if (!_produced || _oddByte != null) {
        throw StateError('Incomplete call audio');
      }
      await output.drain();
      if (!_done.isCompleted) _done.complete();
      await _close();
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _fail(Object error, [StackTrace? stack]) {
    if (_stopped) return;
    _stopped = true;
    if (!_done.isCompleted) _done.completeError(error, stack);
    unawaited(_close().catchError((Object _) {}));
    onFailure?.call();
  }

  Future<void> close() async {
    _stopped = true;
    if (!_done.isCompleted) _done.complete();
    await _close();
  }

  Future<void> stop() async {
    _stopped = true;
    _pending.clear();
    if (!_done.isCompleted) _done.complete();
    await output.stopPlayback();
    await _close();
  }

  Future<void> _close() async {
    final cancelled = _frames?.cancel();
    final socket = _socket;
    _frames = null;
    _socket = null;
    await cancelled
        ?.timeout(const Duration(seconds: 2))
        .catchError((Object _) {});
    await socket?.sink
        .close()
        .timeout(const Duration(seconds: 2))
        .catchError((Object _) {});
  }
}
