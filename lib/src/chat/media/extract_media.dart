import '../chat_models.dart';

/// An assistant message's text once its `MEDIA:` tags are taken out of it.
class ExtractedMedia {
  const ExtractedMedia(this.text, this.attachments);

  final String text;
  final List<ChatAttachment> attachments;
}

const _marker = 'MEDIA:';

// A tag starts a word: `NOMEDIA:` is not one. The path is quoted, when it
// holds spaces, or runs to the next whitespace.
final _tag = RegExp(r'(?<!\w)MEDIA:(?:"([^"\n]*)"|(\S+))');
final _openQuote = RegExp(r'(?<!\w)MEDIA:"[^"\n]*$');
final _code = RegExp(r'```[\s\S]*?(?:```|$)|`[^`\n]*`');
final _sentenceEnd = RegExp(r'''[.,;:!?)\]}>'"`]+$''');
final _trailingBlanks = RegExp(r'[ \t]+$');
final _whitespace = RegExp(r'\s');
final _pathSeparator = RegExp(r'[/\\]');
const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'ico'};

/// Reads the `MEDIA:<absolute path>` tags Hermes' agent writes to hand a file
/// to the user. Each becomes an attachment, in the order the tags appear, and
/// leaves the [ExtractedMedia.text]; a path named twice counts once. A tag
/// with a relative path, or inside code, stays text. A text without a tag is
/// returned as it is.
///
/// While the reply is still arriving ([complete] false) a tag whose path may
/// not have finished, and a start of one such as `MED`, is held back, so a
/// half-read path is never fetched or shown.
ExtractedMedia extractMedia(String content, {bool complete = true}) {
  if (!content.contains('M')) return ExtractedMedia(content, const []);
  final protected = [
    for (final match in _code.allMatches(content)) (match.start, match.end),
  ];
  bool isCode(int at) => protected.any((r) => r.$1 <= at && at < r.$2);

  final removals = <(int, int)>[];
  final attachments = <ChatAttachment>[];
  final seen = <String>{};
  for (final match in _tag.allMatches(content)) {
    if (isCode(match.start)) continue;
    if (!complete && match.end == content.length) {
      removals.add((match.start, match.end));
      continue;
    }
    final path = match[1] ?? match[2]!.replaceFirst(_sentenceEnd, '');
    if (!isAbsoluteServerPath(path)) continue;
    removals.add((match.start, match.end));
    if (seen.add(path)) attachments.add(_attachmentFor(path));
  }

  if (!complete) {
    final open = _openQuote.firstMatch(content);
    if (open != null && !isCode(open.start)) {
      removals.add((open.start, content.length));
    } else {
      final start = content.lastIndexOf(_whitespace) + 1;
      final tail = content.substring(start);
      if (tail.isNotEmpty && _marker.startsWith(tail) && !isCode(start)) {
        removals.add((start, content.length));
      }
    }
  }
  if (removals.isEmpty) return ExtractedMedia(content, const []);

  final out = StringBuffer();
  var from = 0;
  for (final (start, end) in removals) {
    out.write(content.substring(from, start));
    from = end;
    var kept = out.toString();
    kept = kept.replaceFirst(_trailingBlanks, '');
    // A line that held only a tag goes away with its line break.
    final lineEmpty = kept.substring(kept.lastIndexOf('\n') + 1).isEmpty;
    if (lineEmpty && from < content.length && content[from] == '\n') from++;
    out
      ..clear()
      ..write(kept);
  }
  out.write(content.substring(from));
  return ExtractedMedia(out.toString().trim(), attachments);
}

ChatAttachment _attachmentFor(String path) {
  final name = path
      .split(_pathSeparator)
      .lastWhere((part) => part.isNotEmpty, orElse: () => path);
  final dot = name.lastIndexOf('.');
  final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return ChatAttachment(
    name: name,
    kind: _imageExtensions.contains(extension)
        ? AttachmentKind.image
        : AttachmentKind.file,
    remotePath: path,
  );
}
