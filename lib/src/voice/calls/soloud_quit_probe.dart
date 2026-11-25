import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart' as soloud;

import '../../macos/mac_app.dart';
import 'portable_call_audio.dart';

/// Debug builds on macOS only: with `HERMES_SOLOUD_QUIT_PROBE=1` the app starts
/// SoLoud the way a portable call does (engine init, one buffer stream with a
/// little silence) and then quits through the app's own terminate call. CI
/// uses it to prove a quit after SoLoud ran does not crash (build-macos in
/// ci.yml). `kDebugMode` is a compile-time constant, so a release build has
/// no trace of it, and a real launch never starts audio.
///
/// It prints exactly one outcome line before `HERMES_PROBE terminating`: the
/// success pair (`initialised`, `played`), `no audio device` (the one permitted
/// skip, a runner without a playback device: the library is loaded all the
/// same), or `failed: <type>`, which CI treats as a failure.
Future<void> runSoloudQuitProbeIfAsked() async {
  if (!kDebugMode || !Platform.isMacOS) return;
  if (Platform.environment['HERMES_SOLOUD_QUIT_PROBE'] != '1') return;
  final player = SoLoudCallPlayer();
  try {
    await player.init();
    stdout.writeln('HERMES_PROBE soloud initialised');
    await player.play(Uint8List(3200), 16000);
    stdout.writeln('HERMES_PROBE soloud played');
    await Future<void>.delayed(const Duration(seconds: 1));
  } on soloud.SoLoudNoPlaybackDevicesFoundCppException {
    stdout.writeln('HERMES_PROBE soloud no audio device');
  } on Object catch (error) {
    stdout.writeln('HERMES_PROBE soloud failed: ${error.runtimeType}');
  }
  stdout.writeln('HERMES_PROBE terminating');
  await stdout.flush();
  await MacApp.terminate();
}
