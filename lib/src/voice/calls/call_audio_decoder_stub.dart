import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../synthesized_speech.dart';

Future<Uint8List> decodeCallAudio(
  SynthesizedSpeech speech,
  CancelToken cancellation,
) async {
  if (cancellation.isCancelled) throw cancellation.cancelError!;
  throw UnsupportedError('Call audio conversion requires a native platform');
}
