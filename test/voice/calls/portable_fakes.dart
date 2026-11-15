// ignore_for_file: close_sinks, cancel_subscriptions

import 'dart:async';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:hermes_app/src/voice/calls/portable_call_bridge.dart';

class FakeRecorder implements CallRecorder {
  FakeRecorder(this.log);
  final List<String> log;
  int starts = 0, stops = 0, disposes = 0;
  Completer<void>? startGate, stopGate, disposeGate;
  Object? startError;
  StreamController<Uint8List>? _stream;

  /// Whether a capture is open as far as the fake knows.
  bool get open => _stream != null;

  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    log.add('recorder.start');
    await startGate?.future;
    if (startError != null) await Future<void>.error(startError!);
    final controller = _stream = StreamController<Uint8List>();
    return controller.stream;
  }

  void add(List<int> bytes) => _stream?.add(Uint8List.fromList(bytes));
  void fail(Object error) => _stream?.addError(error);
  void endStream() {
    unawaited(_stream?.close());
    _stream = null;
  }

  @override
  Future<void> stop() async {
    stops++;
    log.add('recorder.stop');
    await stopGate?.future;
    final stream = _stream;
    _stream = null;
    if (stream != null) unawaited(stream.close());
  }

  @override
  Future<void> dispose() async {
    disposes++;
    log.add('recorder.dispose');
    await disposeGate?.future;
  }
}

class FakePlayer implements CallPlayer {
  FakePlayer(this.log);
  final List<String> log;
  final played = <List<Object>>[];
  int inits = 0, stops = 0, drains = 0, disposes = 0;
  Completer<void>? drainGate, initGate;

  @override
  Future<void> init() async {
    inits++;
    await initGate?.future;
    log.add('player.init');
  }

  @override
  Future<void> play(Uint8List pcm, int rate) async {
    log.add('player.play');
    played.add([pcm.toList(), rate]);
  }

  @override
  Future<void> drain() async {
    drains++;
    log.add('player.drain');
    await drainGate?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    log.add('player.stop');
  }

  @override
  Future<void> dispose() async {
    disposes++;
    log.add('player.dispose');
  }
}

class FakeSession implements CallAudioSession {
  FakeSession(this.log);
  final List<String> log;
  final interruptionsController = StreamController<AudioInterruptionEvent>();
  final routesController = StreamController<void>();
  final speakerCalls = <bool>[];
  int activations = 0, deactivations = 0;
  Object? activateError;
  Completer<void>? activateGate;

  @override
  Stream<AudioInterruptionEvent> get interruptions =>
      interruptionsController.stream;
  @override
  Stream<void> get routeChanges => routesController.stream;
  @override
  Future<void> activate() async {
    activations++;
    await activateGate?.future;
    log.add('session.activate');
    if (activateError != null) await Future<void>.error(activateError!);
  }

  @override
  Future<void> deactivate() async {
    deactivations++;
    log.add('session.deactivate');
  }

  @override
  Future<void> setSpeaker(bool enabled) async => speakerCalls.add(enabled);
}

class Rig {
  Rig({bool bargeIn = false, bool session = false}) {
    recorder = FakeRecorder(log);
    player = FakePlayer(log);
    audioSession = session ? FakeSession(log) : null;
    bridge = PortableCallBridge(
      recorder: recorder,
      player: player,
      session: audioSession,
      bargeIn: bargeIn,
    );
    sub = bridge.events.listen(events.add);
  }

  final log = <String>[];
  final events = <Map<String, Object?>>[];
  late final FakeRecorder recorder;
  late final FakePlayer player;
  late final FakeSession? audioSession;
  late final PortableCallBridge bridge;
  late final StreamSubscription<Map<String, Object?>> sub;

  List<String> get types => [for (final e in events) e['type']! as String];
  Iterable<Map<String, Object?>> of(String type) =>
      events.where((e) => e['type'] == type);

  Future<void> started([String id = 'call-1']) async {
    await bridge.start(id, 'Hermes');
    await pump();
  }

  Future<void> pump() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}
