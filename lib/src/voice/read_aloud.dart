import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;

import '../chat/media/media_store.dart';
import 'synthesized_speech.dart';

/// Reads a finished reply aloud with the text to speech Hermes runs for
/// [profile] (`POST /api/audio/speak`). The audio is staged in [MediaStore]
/// and played by the transcript's one `VoicePlayback`, the player voice
/// messages use, so a reply and a voice message never play at once.
///
/// It exists only while `GET /api/audio/voice-config` says the profile can
/// speak; the chat screen provides it to the transcript.
class ReadAloud {
  ReadAloud({
    required this.profile,
    required this.synthesize,
    required this.store,
  });

  final String? profile;

  /// Hermes' speech for a text.
  final Future<SynthesizedSpeech> Function(String text) synthesize;
  final MediaStore store;

  /// The player id of message [messageId], apart from its attachments'.
  static String playbackId(String messageId) => 'read-aloud:$messageId';

  /// The spoken [text] of a reply as an audio file.
  Future<File> fetch(String text) async {
    final speech = await synthesize(speakableText(text));
    final digest = sha256.convert(speech.bytes).toString();
    return store.stageBytes(
      'read-aloud:$digest',
      'reply.${audioExtension(speech.mimeType)}',
      speech.bytes,
    );
  }

  @override
  String toString() => 'ReadAloud';
}

/// A file extension for audio of [mimeType], so the player need not guess.
String audioExtension(String mimeType) => switch (mimeType) {
  'audio/mpeg' || 'audio/mp3' => 'mp3',
  'audio/ogg' || 'audio/opus' => 'ogg',
  'audio/wav' || 'audio/x-wav' || 'audio/wave' => 'wav',
  'audio/aac' => 'aac',
  'audio/mp4' || 'audio/m4a' || 'audio/x-m4a' => 'm4a',
  'audio/flac' || 'audio/x-flac' => 'flac',
  'audio/webm' => 'webm',
  _ => 'audio',
};

final _fenceLine = RegExp(r'^ {0,3}(`{3,}|~{3,}).*(\n|$)', multiLine: true);
final _image = RegExp(r'!\[([^\]]*)\]\([^)]*\)');
final _link = RegExp(r'\[([^\]]+)\]\([^)]*\)');
final _heading = RegExp(r'^ {0,3}#{1,6}[ \t]+', multiLine: true);
final _quote = RegExp(r'^[ \t]*>[ \t]?', multiLine: true);
final _bullet = RegExp(
  r'^([ \t]*)[-*+][ \t]+(\[[ xX]\][ \t]+)?',
  multiLine: true,
);
final _rule = RegExp(
  r'^[ \t]*([-*_])([ \t]*\1){2,}[ \t]*(\n|$)',
  multiLine: true,
);
final _tableDelimiter = RegExp(
  r'^[ \t]*\|?[ \t]*:?-{3,}[-|: \t]*(\n|$)',
  multiLine: true,
);
final _strong = RegExp(r'(\*\*|__|~~)(.+?)\1');
final _emphasis = RegExp(r'(?<![\w*])[*_]([^*_\n]+)[*_](?![\w*])');
final _blankLines = RegExp(r'\n{3,}');

/// [markdown] as it should be heard: the words of links, emphasis, headings,
/// lists, quotes and code without their marks, and no rules or table lines.
String speakableText(String markdown) => markdown
    .replaceAll(_fenceLine, '')
    .replaceAll(_tableDelimiter, '')
    .replaceAll(_rule, '')
    .replaceAllMapped(_image, (m) => m[1]!)
    .replaceAllMapped(_link, (m) => m[1]!)
    .replaceAll(_heading, '')
    .replaceAll(_quote, '')
    .replaceAllMapped(_bullet, (m) => m[1]!)
    .replaceAllMapped(_strong, (m) => m[2]!)
    .replaceAllMapped(_emphasis, (m) => m[1]!)
    .replaceAll('`', '')
    .replaceAll('|', ' ')
    .replaceAll(_blankLines, '\n\n')
    .trim();
