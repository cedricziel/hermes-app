import 'dart:convert';

import '../drag_out/drag_out_item.dart';
import '../drag_out/sanitize_drag_file_name.dart';
import 'chat_models.dart';
import 'thread_housekeeping.dart';

/// [messages] as Markdown for the clipboard: a heading per turn that has
/// something to say, skipping ones that are only attachments or tool calls.
String threadTranscript(Iterable<ChatMessage> messages) {
  final parts = <String>[];
  for (final message in messages) {
    final text = message.content.trim();
    if (text.isEmpty) continue;
    final speaker = message.role == ChatRole.user ? 'You' : 'Hermes';
    parts.add('## $speaker\n\n$text');
  }
  return parts.join('\n\n');
}

/// Every message of [thread]: all the pages when there is [housekeeping] to
/// read them, the loaded ones otherwise. [cancelled] is asked between pages.
Future<List<ChatMessage>> threadHistory(
  ChatThread thread,
  ThreadHousekeeping? housekeeping, {
  bool Function()? cancelled,
}) =>
    housekeeping?.history(thread, cancelled: cancelled) ??
    Future.value(thread.messages);

/// A chat as a Markdown file: its title as a heading, a blank line, then
/// [threadTranscript]. A chat with nothing to say is the heading alone.
///
/// The heading is one line: the title's whitespace and line breaks collapse
/// to single spaces, and a trailing `#` is escaped so it is not read as a
/// closing sequence. A blank title is called `Chat`.
String threadMarkdown(String title, Iterable<ChatMessage> messages) {
  final line = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  final heading = '# ${line.isEmpty ? 'Chat' : line}'.replaceFirstMapped(
    RegExp(r'(\s)(#+)$'),
    (m) => '${m[1]}\\${m[2]}',
  );
  final transcript = threadTranscript(messages);
  return transcript.isEmpty ? heading : '$heading\n\n$transcript';
}

/// The file name of an exported chat: its title made safe, with `.md`. A dot
/// inside the title (`Release 1.2 notes`) is not an extension, so `.md` is
/// always added unless the title already ends in it; leading dots and spaces
/// are dropped first, so a title of dots alone is called `Chat.md`.
String threadExportFileName(String title) {
  var base = title.trim();
  if (base.toLowerCase().endsWith('.md')) {
    base = base.substring(0, base.length - 3);
  }
  base = base.replaceFirst(RegExp(r'^[.\s]+'), '');
  return sanitizeDragFileName(
    base.isEmpty ? 'Chat.md' : '$base.md',
    fallback: 'Chat.md',
  );
}

/// What dragging the sidebar row of [thread] carries, or null for a chat the
/// server does not hold. Nothing is read until the receiver asks: then every
/// page of history, loaded or not, comes through [housekeeping] (the loaded
/// messages when there is none), as for Copy Transcript. If the receiver
/// waits too long the fetch is cancelled between pages.
DragOutFile? threadDragItem(
  ChatThread thread,
  ThreadHousekeeping? housekeeping,
) {
  if (!thread.remote) return null;
  var cancelled = false;
  return DragOutFile(
    name: threadExportFileName(thread.title),
    failure: DragOutFailure.history,
    cancel: () => cancelled = true,
    read: () async {
      final messages = await threadHistory(
        thread,
        housekeeping,
        cancelled: () => cancelled,
      );
      return utf8.encode(threadMarkdown(thread.title, messages));
    },
  );
}
