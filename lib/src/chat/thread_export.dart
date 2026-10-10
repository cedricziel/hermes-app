import 'dart:convert';
import 'dart:typed_data';

import '../drag_out/drag_out_item.dart';
import '../drag_out/sanitize_drag_file_name.dart';
import 'chat_models.dart';
import 'thread_housekeeping.dart';
import 'widgets/thread_actions_menu.dart' show threadTranscript;

/// A chat as a Markdown file: its title as a heading, a blank line, then the
/// text Copy Transcript puts on the clipboard. A chat with nothing to say is
/// the heading alone.
String threadMarkdown(String title, Iterable<ChatMessage> messages) {
  final heading = '# ${title.trim().isEmpty ? 'Chat' : title}';
  final transcript = threadTranscript(messages);
  return transcript.isEmpty ? heading : '$heading\n\n$transcript';
}

/// The file name of an exported chat: its title made safe, with `.md`. A
/// dot inside the title (`Release 1.2 notes`) is not an extension, so `.md` is
/// always added unless the title already ends in it.
String threadExportFileName(String title) {
  var base = title.trim();
  if (base.toLowerCase().endsWith('.md')) {
    base = base.substring(0, base.length - 3);
  }
  return sanitizeDragFileName(
    base.isEmpty ? 'Chat.md' : '$base.md',
    fallback: 'Chat.md',
  );
}

/// What dragging the sidebar row of [thread] carries, or null for a chat the
/// server does not hold. Nothing is read until the receiver asks: then every
/// page of history, loaded or not, comes through [housekeeping] (the loaded
/// messages when there is none), as for Copy Transcript.
DragOutFile? threadDragItem(
  ChatThread thread,
  ThreadHousekeeping? housekeeping,
) {
  if (!thread.remote) return null;
  return DragOutFile(
    name: threadExportFileName(thread.title),
    failure: DragOutFailure.history,
    read: () async {
      final messages =
          await (housekeeping?.history(thread) ??
              Future.value(thread.messages));
      return Uint8List.fromList(
        utf8.encode(threadMarkdown(thread.title, messages)),
      );
    },
  );
}
