import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart' as soloud;
import 'package:record/record.dart';

import 'call_bridge.dart';
import 'portable_call_bridge.dart';

/// The call's audio for this platform: CallKit's bridge on iOS, the portable
/// one everywhere else. Barge-in stays off on the portable one: it needs echo
/// cancellation of what the call plays, which only Apple's voice processing
/// gives, and Android's has to be proven on a device first.
CallBridge createCallBridge({TargetPlatform? platform}) {
  final target = platform ?? defaultTargetPlatform;
  if (target == TargetPlatform.iOS) return AppleCallBridge();
  final android = target == TargetPlatform.android;
  return PortableCallBridge(
    recorder: RecordCallRecorder(),
    player: SoLoudCallPlayer(voiceCommunication: android),
    session: android ? AndroidCallAudioSession() : null,
  );
}

/// The `record` plugin, asked for the call's capture: 16 kHz mono PCM through
/// the platform's echo canceller and noise suppressor. On Android the input is
/// the voice-communication source, which the canceller needs. The plugin takes
/// no audio focus here (the audio session does) and follows a changed input.
class RecordCallRecorder implements CallRecorder {
  AudioRecorder? _plugin;
  AudioRecorder get _recorder => _plugin ??= AudioRecorder();

  @override
  Future<Stream<Uint8List>> start() => _recorder.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      audioInterruption: AudioInterruptionMode.none,
      audioRouteChange: AudioRouteChangeMode.follow,
      androidConfig: AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceCommunication,
      ),
    ),
  );

  @override
  Future<void> stop() async {
    final recorder = _plugin;
    if (recorder != null) await recorder.stop();
  }

  @override
  Future<void> dispose() async {
    final recorder = _plugin;
    _plugin = null;
    await recorder?.dispose();
  }
}

/// Plays the call's PCM with SoLoud: one buffer stream per run of audio at one
/// rate, fed as it arrives and played from a short lead-in, so a reply starts
/// before it has all been generated. The engine is started on the first use
/// and stopped with [dispose], and never on iOS, where CallKit's graph plays.
///
/// On Android the output is tagged as voice communication (and so is
/// low-latency off), the stream the platform's echo canceller takes as the far
/// end of a call; SoLoud's default is media, which it does not.
class SoLoudCallPlayer implements CallPlayer {
  SoLoudCallPlayer({this.voiceCommunication = false});

  final bool voiceCommunication;
  final _engine = soloud.SoLoud.instance;
  final _voices = <_Voice>[];
  _Voice? _current;
  bool _owned = false;

  @override
  Future<void> init() async {
    if (_engine.isInitialized) return;
    await _engine.init(
      lowLatency: false,
      androidAAudioAttributes: voiceCommunication
          ? soloud.AndroidAAudioAttributes.voiceCommunication
          : soloud.AndroidAAudioAttributes.mediaMusic,
    );
    _owned = true;
  }

  @override
  Future<void> play(Uint8List pcm, int rate) async {
    if (!_engine.isInitialized) return;
    var voice = _current;
    if (voice == null || voice.rate != rate) {
      _end(voice);
      voice = _current = _open(rate);
    }
    _engine.addAudioDataStream(voice.source, pcm);
    voice.handle ??= _engine.play(voice.source);
  }

  _Voice _open(int rate) {
    final source = _engine.setBufferStream(
      bufferingType: soloud.BufferingType.released,
      // Playback starts once this much is buffered: long enough to ride over a
      // late network frame, short enough not to delay the first word.
      bufferingTimeNeeds: 0.15,
      sampleRate: rate,
      channels: soloud.Channels.mono,
      format: soloud.BufferType.s16le,
      maxBufferSizeDuration: const Duration(minutes: 10),
      autoDispose: true,
    );
    final voice = _Voice(source, rate);
    source.soundEvents.listen((event) {
      if (event.event == soloud.SoundEventType.handleIsNoMoreValid ||
          event.event == soloud.SoundEventType.soundDisposed) {
        voice.finished();
      }
    });
    _voices.add(voice);
    unawaited(voice.done.then((_) => _voices.remove(voice)));
    return voice;
  }

  /// Tells SoLoud no more audio comes for [voice]; it plays what it has.
  void _end(_Voice? voice) {
    if (voice == null || voice.ended) return;
    voice.ended = true;
    if (_current == voice) _current = null;
    if (voice.handle == null) {
      // Nothing was ever played: nothing to wait for.
      unawaited(_dispose(voice));
      return;
    }
    try {
      _engine.setDataIsEnded(voice.source);
    } on Object {
      voice.finished();
    }
  }

  Future<void> _dispose(_Voice voice) async {
    voice.finished();
    try {
      await _engine.disposeSource(voice.source);
    } on Object {
      // Already gone.
    }
  }

  @override
  Future<void> drain() async {
    _end(_current);
    await Future.wait([for (final voice in _voices.toList()) voice.done]);
  }

  @override
  Future<void> stop() async {
    _current = null;
    for (final voice in _voices.toList()) {
      voice.ended = true;
      await _dispose(voice);
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    if (_owned && _engine.isInitialized) {
      _owned = false;
      await _engine.deinitAsync();
    }
  }
}

class _Voice {
  _Voice(this.source, this.rate);
  final soloud.AudioSource source;
  final int rate;
  soloud.SoundHandle? handle;
  bool ended = false;
  final _done = Completer<void>();
  Future<void> get done => _done.future;
  void finished() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// Audio focus and routing on Android through `audio_session`: a voice
/// communication focus request, the in-communication audio mode (which the
/// platform's echo canceller expects) and the speakerphone switch. A loss of
/// focus other than ducking, and a changed device, reach the bridge as
/// events; nothing resumes by itself.
class AndroidCallAudioSession implements CallAudioSession {
  // Closed by deactivate.
  // ignore: close_sinks
  final _interruptions = StreamController<AudioInterruptionEvent>.broadcast();
  // ignore: close_sinks
  final _routes = StreamController<void>.broadcast();
  final _watches = <StreamSubscription<Object?>>[];
  final _manager = AndroidAudioManager();
  AudioSession? _session;

  @override
  Stream<AudioInterruptionEvent> get interruptions => _interruptions.stream;
  @override
  Stream<void> get routeChanges => _routes.stream;

  @override
  Future<void> activate() async {
    final session = _session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ),
    );
    _watches
      ..add(session.interruptionEventStream.listen(_interruptions.add))
      ..add(session.becomingNoisyEventStream.listen(_routes.add))
      ..add(session.devicesChangedEventStream.listen(_routes.add));
    if (!await session.setActive(true)) {
      await deactivate();
      throw StateError('Android did not give the call audio focus');
    }
    await _manager.setMode(AndroidAudioHardwareMode.inCommunication);
  }

  @override
  Future<void> deactivate() async {
    for (final watch in _watches) {
      await watch.cancel();
    }
    _watches.clear();
    unawaited(_interruptions.close());
    unawaited(_routes.close());
    final session = _session;
    _session = null;
    if (session == null) return;
    try {
      await _manager.setSpeakerphoneOn(false);
      await _manager.setMode(AndroidAudioHardwareMode.normal);
    } finally {
      await session.setActive(false);
    }
  }

  @override
  Future<void> setSpeaker(bool enabled) => _manager.setSpeakerphoneOn(enabled);
}
