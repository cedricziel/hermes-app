import 'dart:typed_data';

/// Turns speech into text while the user speaks: 16-bit little-endian mono
/// PCM goes in, the text recognized so far comes out, and [finish] answers
/// the transcript.
abstract interface class LiveTranscriber {
  /// The latest recognized text, revised as more speech arrives.
  Stream<String> get partials;

  /// Feeds a chunk of the recording.
  void add(Uint8List pcm);

  /// Ends the recording and waits for the transcript; null when recognition
  /// failed.
  Future<String?> finish();

  /// Drops the recording without a transcript.
  void cancel();
}
