import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:media_kit/media_kit.dart';

import '../synthesized_speech.dart';

/// Uses the already bundled libmpv/FFmpeg codecs as a file converter only.
/// CallKit's existing voice-processing graph remains the sole audio output;
/// this player never opens an audio device or configures AVAudioSession.
Future<Uint8List> decodeCallAudio(
  SynthesizedSpeech speech,
  CancelToken cancellation,
) async {
  void checkCancellation() {
    if (cancellation.isCancelled) throw cancellation.cancelError!;
  }

  checkCancellation();
  if (speech.bytes.isEmpty ||
      speech.bytes.length > SynthesizedSpeech.maxBytes) {
    throw const FormatException('Invalid synthesized audio');
  }
  final directory = await Directory.systemTemp.createTemp('hermes-call-audio-');
  Player? player;
  Future<void>? disposal;
  Future<void> disposePlayer() =>
      disposal ??= player?.dispose() ?? Future.value();
  final subscriptions = <StreamSubscription<dynamic>>[];
  try {
    checkCancellation();
    final source = File('${directory.path}/speech.audio');
    final destination = File('${directory.path}/speech.pcm');
    await source.writeAsBytes(speech.bytes, flush: true);
    checkCancellation();
    MediaKit.ensureInitialized();
    final decoder = player = Player(
      configuration: const PlayerConfiguration(protocolWhitelist: ['file']),
    );
    final native = decoder.platform as NativePlayer;
    final finished = Completer<void>();
    unawaited(finished.future.then<void>((_) {}, onError: (Object _) {}));
    subscriptions.addAll([
      decoder.stream.completed.listen((done) {
        if (done && !finished.isCompleted) finished.complete();
      }),
      decoder.stream.error.listen((_) {
        if (!finished.isCompleted) {
          finished.completeError(StateError('Could not decode call audio'));
        }
      }),
    ]);
    Future<Uint8List> convert() async {
      for (final option in {
        'ao': 'pcm',
        'ao-pcm-file': destination.path,
        'ao-pcm-waveheader': 'no',
        'audio-format': 's16',
        'audio-samplerate': '24000',
        'audio-channels': 'mono',
        'keep-open': 'no',
      }.entries) {
        checkCancellation();
        await native.setProperty(option.key, option.value);
        // setProperty doesn't propagate libmpv's return code. Fail closed if
        // this build cannot select file output; never fall back to speakers.
        if (await native.getProperty(option.key) != option.value) {
          throw StateError('Call audio conversion is unavailable');
        }
      }
      checkCancellation();
      await decoder.open(Media(source.uri.toString()));
      await finished.future;
      await disposePlayer(); // Closes/flushes the PCM file before reading it.
      checkCancellation();
      final length = await destination.length();
      // Match the native call graph's two-minute queue limit, at 24 kHz mono.
      if (length == 0 || length.isOdd || length > 24000 * 2 * 120) {
        throw const FormatException('Invalid decoded call audio');
      }
      return destination.readAsBytes();
    }

    return await Future.any([
      convert(),
      cancellation.whenCancel.then<Uint8List>((error) => throw error),
    ]).timeout(const Duration(seconds: 30));
  } finally {
    await disposePlayer()
        .timeout(const Duration(seconds: 5))
        .catchError((Object _) {});
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await directory.delete(recursive: true).catchError((Object _) => directory);
  }
}
