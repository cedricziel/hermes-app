import 'dart:typed_data';

/// Wraps 16-bit little-endian mono [pcm] in a WAV file, so a recording can be
/// uploaded to a transcription route that wants a whole audio file.
Uint8List wavFromPcm16(Uint8List pcm, {required int sampleRate}) {
  const headerLength = 44;
  final wav = Uint8List(headerLength + pcm.length);
  final header = ByteData.sublistView(wav, 0, headerLength);
  void ascii(int offset, String text) =>
      wav.setRange(offset, offset + text.length, text.codeUnits);

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVEfmt ');
  header
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  wav.setRange(headerLength, wav.length, pcm);
  return wav;
}
