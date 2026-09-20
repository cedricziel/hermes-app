import 'dart:convert';
import 'dart:typed_data';

import 'chat_models.dart';

/// What a stored message says once its attachments are taken out of it.
class StoredContent {
  const StoredContent(this.text, this.attachments);

  /// The visible text, without the reference lines.
  final String text;
  final List<ChatAttachment> attachments;
}

final _reference = RegExp(r'^@(image|file):(.+)$');
final _attachedFile = RegExp(r'^\[User attached file: (.+)\]$');
final _dataImageHeader = RegExp(r'^data:image/([a-zA-Z0-9.+-]+)?;base64,');
final _whitespace = RegExp(r'\s+');
final _pathSeparator = RegExp(r'[/\\]');
const _textParts = {'text', 'input_text', 'output_text'};
const _imageParts = {'image_url', 'input_image', 'image'};

/// Reads the `content` of a stored message, which the dashboard returns as a
/// string, or as a list of parts for a turn the model saw natively.
///
/// A line made only of `@image:<path>`, `@file:<path>` or
/// `[User attached file: <path>]` is an attachment and leaves the text; any
/// other line stays. Images embedded as `data:` URLs are decoded and attached
/// to the matching `@image:` line, or on their own when none matches. Returns
/// null when [content] is neither text nor a list, so the caller can skip the
/// row.
StoredContent? parseStoredContent(Object? content) {
  final texts = <String>[];
  final embedded = <({Uint8List bytes, String extension})>[];
  switch (content) {
    case null:
      break;
    case String text:
      texts.add(text);
    case List<Object?> parts:
      for (final part in parts) {
        if (part is String) {
          texts.add(part);
        } else if (part is Map) {
          final text = part['text'];
          final type = part['type'];
          if (text is String && (type == null || _textParts.contains(type))) {
            texts.add(text);
          } else if (_imageParts.contains(type)) {
            if (_decodeDataImage(part['image_url']) case final image?) {
              embedded.add(image);
            }
          }
        }
      }
    default:
      return null;
  }

  final kept = <String>[];
  var attachments = <ChatAttachment>[];
  for (final line in const LineSplitter().convert(texts.join('\n'))) {
    final attachment = _attachmentOf(line.trim());
    if (attachment == null) {
      kept.add(line);
    } else {
      attachments.add(attachment);
    }
  }

  var text = kept.join('\n');
  if (attachments.isNotEmpty) text = text.trim();

  var next = 0;
  attachments = [
    for (final a in attachments)
      if (a.kind == AttachmentKind.image && next < embedded.length)
        _withBytes(a, embedded[next++].bytes)
      else
        a,
  ];
  for (final (i, image) in embedded.skip(next).indexed) {
    final suffix = i == 0 ? '' : '-${i + 1}';
    attachments.add(
      ChatAttachment(
        name: 'image$suffix.${image.extension}',
        kind: AttachmentKind.image,
        size: image.bytes.length,
        bytes: image.bytes,
      ),
    );
  }
  return StoredContent(text, attachments);
}

ChatAttachment? _attachmentOf(String line) {
  final String path;
  final AttachmentKind kind;
  if (_reference.firstMatch(line) case final match?) {
    path = _unquote(match[2]!);
    kind = match[1] == 'image' ? AttachmentKind.image : AttachmentKind.file;
  } else if (_attachedFile.firstMatch(line) case final match?) {
    path = _unquote(match[1]!);
    kind = AttachmentKind.file;
  } else {
    return null;
  }
  if (path.isEmpty) return null;
  return ChatAttachment(name: _fileName(path), kind: kind, remotePath: path);
}

/// Hermes wraps a path that holds whitespace or brackets in one kind of quote.
String _unquote(String value) {
  if (value.length >= 2 &&
      '`"\''.contains(value[0]) &&
      value.endsWith(value[0])) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

String _fileName(String path) => path
    .split(_pathSeparator)
    .lastWhere((part) => part.isNotEmpty, orElse: () => path);

ChatAttachment _withBytes(ChatAttachment a, Uint8List bytes) => ChatAttachment(
  name: a.name,
  kind: a.kind,
  remotePath: a.remotePath,
  size: bytes.length,
  bytes: bytes,
);

({Uint8List bytes, String extension})? _decodeDataImage(Object? value) {
  final url = value is Map ? value['url'] : value;
  if (url is! String) return null;
  final header = _dataImageHeader.matchAsPrefix(url);
  if (header == null) return null;
  try {
    final bytes = base64Decode(
      url.substring(header.end).replaceAll(_whitespace, ''),
    );
    if (bytes.isEmpty) return null;
    final subtype = (header[1] ?? 'png').toLowerCase();
    return (bytes: bytes, extension: subtype == 'jpeg' ? 'jpg' : subtype);
  } on FormatException {
    return null;
  }
}
