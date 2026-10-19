import 'dart:convert';
import 'dart:typed_data';

/// A bounded, inline server response. Never give provider URLs or credentials
/// to the native decoder.
class SynthesizedSpeech {
  const SynthesizedSpeech(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
  static const maxBytes = 12 * 1024 * 1024;

  factory SynthesizedSpeech.fromJson(Object? body) {
    const invalid = FormatException('Invalid synthesized audio');
    if (body is! Map || body['ok'] != true) throw invalid;
    final url = body['data_url'];
    if (url is! String || url.length > maxBytes * 4 ~/ 3 + 128) throw invalid;
    final header = RegExp(r'^data:(audio/[a-zA-Z0-9.+-]+);base64,')
        .firstMatch(url);
    if (header == null) throw invalid;
    try {
      final bytes = base64Decode(url.substring(header.end));
      if (bytes.isEmpty || bytes.length > maxBytes) throw invalid;
      return SynthesizedSpeech(bytes, header.group(1)!.toLowerCase());
    } on FormatException {
      throw invalid;
    }
  }
}
