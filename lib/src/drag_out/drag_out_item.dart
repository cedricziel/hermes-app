import 'dart:typed_data';

/// What a drag out of the app is for. The name goes into telemetry as
/// `kind`, so it is a fixed slug and never anything the user typed.
enum DragOutKind {
  attachment('attachment'),
  kanbanAttachment('kanban_attachment'),
  text('text'),
  thread('thread');

  const DragOutKind(this.slug);

  final String slug;
}

/// What a drag carries out of the app. An item is built when a drag begins
/// and costs nothing until the receiver asks for it: a [DragOutFile] reads its
/// bytes only on the drop, never at drag start.
sealed class DragOutItem {
  const DragOutItem();
}

/// A file the receiver creates when it asks for the content.
///
/// Prefer [localPath] when the content already is a file: the app copies it
/// natively and the bytes never cross the platform channel. Without one, [read]
/// supplies the bytes, which are held in memory while they are handed over (up
/// to the 25 MB attachment limit, for an embedded attachment or a Kanban
/// download).
final class DragOutFile extends DragOutItem {
  const DragOutFile({
    required this.name,
    required this.read,
    this.localPath,
    this.failure = DragOutFailure.fetch,
    this.cancel,
  });

  /// The file name the receiver proposes, already safe (see
  /// [sanitizeDragFileName]).
  final String name;

  /// Produces the content; called once, only when the receiver wants the
  /// file and [localPath] gave none. A throw ends the drop without a file.
  final Future<Uint8List> Function() read;

  /// The path of a file that holds the content, fetching it first if need be;
  /// null when there is none. Called once, only when the receiver wants the
  /// file. A throw ends the drop without a file.
  final Future<String?> Function()? localPath;

  /// What a failed [read] or [localPath] is logged as: the step that got the
  /// content, `history` for a thread export.
  final DragOutFailure failure;

  /// Called when the receiver gave up waiting (the promise timed out), so a
  /// long read can stop. The drop is logged as [DragOutFailure.timeout].
  final void Function()? cancel;
}

/// Text the receiver takes as plain text and as Markdown.
final class DragOutText extends DragOutItem {
  const DragOutText(this.text);

  final String text;
}

/// Why a drop that was accepted produced no data, as logged.
enum DragOutFailure { fetch, history, timeout, write }

/// How a drop ended, as logged.
enum DragOutOutcome { delivered, failed, cancelled }
