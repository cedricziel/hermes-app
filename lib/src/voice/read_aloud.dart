import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart' show CancelToken;

import '../chat/media/media_store.dart';
import 'synthesized_speech.dart';

/// Reads a finished reply aloud with the text to speech Hermes runs for
/// [profile] (`POST /api/audio/speak`). The audio is staged in [MediaStore]
/// and played by the transcript's one `VoicePlayback`, the player voice
/// messages use, so a reply and a voice message never play at once.
///
/// It exists only while `GET /api/audio/voice-config` says the profile can
/// speak; the chat screen provides it to the transcript and [cancel]s it when
/// it replaces or drops it.
class ReadAloud {
  ReadAloud({
    required this.profile,
    required this.synthesize,
    required this.store,
  });

  final String? profile;

  /// Hermes' speech for a text; [cancellation] abandons the request.
  final Future<SynthesizedSpeech> Function(
    String text,
    CancelToken cancellation,
  )
  synthesize;
  final MediaStore store;

  /// Audio already spoken in this run, by [_keyFor], so playing a reply again
  /// asks the provider nothing.
  final _spoken = <String, File>{};
  static const _remembered = 50;
  CancelToken? _pending;

  /// The player id of message [messageId], apart from its attachments'. The
  /// text is part of it, so a reply whose text changed is spoken again.
  static String playbackId(String messageId, String text) =>
      'read-aloud:$messageId:${_digest(speakableText(text))}';

  /// The spoken [text] of a reply as an audio file. A newer fetch, or
  /// [cancel], abandons the one before it.
  Future<File> fetch(String text) async {
    final spoken = speakableText(text);
    final key = _keyFor(spoken);
    final known = _spoken.remove(key);
    if (known != null && await known.exists()) return _spoken[key] = known;
    _pending?.cancel();
    final cancellation = _pending = CancelToken();
    try {
      final speech = await synthesize(spoken, cancellation);
      final file = await store.stageBytes(
        key,
        'reply.${audioExtension(speech.mimeType)}',
        speech.bytes,
      );
      _spoken[key] = file;
      while (_spoken.length > _remembered) {
        _spoken.remove(_spoken.keys.first);
      }
      return file;
    } finally {
      if (identical(_pending, cancellation)) _pending = null;
    }
  }

  /// Abandons a request still waiting for Hermes' speech.
  void cancel() {
    _pending?.cancel();
    _pending = null;
  }

  String _keyFor(String spoken) => 'read-aloud:$profile:${_digest(spoken)}';

  static String _digest(String text) =>
      sha256.convert(utf8.encode(text)).toString().substring(0, 16);

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

final _fenceBlock = RegExp(
  r'^ {0,3}(`{3,}|~{3,})[^\n]*\n?([\s\S]*?)(?:^ {0,3}\1[ \t]*(?:\n|$)|(?![\s\S]))',
  multiLine: true,
);
final _codeSpan = RegExp(r'(`+)(.+?)\1');
final _escape = RegExp(r'\\([\\`*_{}\[\]()#+\-.!|>~])');
final _escaped = RegExp('[-]');
final _image = RegExp(
  r'!\[([^\]]*)\]\((?:[^()\s]|\([^()]*\))*(?:\s+"[^"]*")?\)',
);
final _link = RegExp(r'\[([^\]]+)\]\((?:[^()\s]|\([^()]*\))*(?:\s+"[^"]*")?\)');
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
final _tableRow = RegExp(r'^[ \t]*\|.*$', multiLine: true);
final _strong = RegExp(r'(\*\*|__|~~)(.+?)\1');
final _emphasis = RegExp(r'(?<![\w*])([*_])([^*_\n]+)\1(?![\w*])');
final _blankLines = RegExp(r'\n{3,}');

/// [markdown] as it should be heard: the words of links, emphasis, headings,
/// lists, quotes and code without their marks, and no rules or table lines.
/// Code, fenced or inline, is read as it is written.
String speakableText(String markdown) {
  final out = StringBuffer();
  var last = 0;
  for (final block in _fenceBlock.allMatches(markdown)) {
    out
      ..write(_prose(markdown.substring(last, block.start)))
      ..write(block[2]);
    last = block.end;
  }
  out.write(_prose(markdown.substring(last)));
  return out.toString().replaceAll(_blankLines, '\n\n').trim();
}

String _prose(String text) {
  final lines = text
      .replaceAll(_tableDelimiter, '')
      .replaceAll(_rule, '')
      .replaceAllMapped(_tableRow, (m) => m[0]!.replaceAll('|', ' '))
      .replaceAll(_heading, '')
      .replaceAll(_quote, '')
      .replaceAllMapped(_bullet, (m) => m[1]!);
  final out = StringBuffer();
  var last = 0;
  for (final span in _codeSpan.allMatches(lines)) {
    out
      ..write(_inline(lines.substring(last, span.start)))
      ..write(span[2]);
    last = span.end;
  }
  out.write(_inline(lines.substring(last)));
  return out.toString();
}

/// Inline marks of prose without code; an escaped mark is read as itself.
String _inline(String text) => text
    .replaceAllMapped(
      _escape,
      (m) => String.fromCharCode(0xE000 + m[1]!.codeUnitAt(0)),
    )
    .replaceAllMapped(_image, (m) => m[1]!)
    .replaceAllMapped(_link, (m) => m[1]!)
    .replaceAllMapped(_strong, (m) => m[2]!)
    .replaceAllMapped(_emphasis, (m) => m[2]!)
    .replaceAll('`', '')
    .replaceAllMapped(
      _escaped,
      (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xE000),
    );
