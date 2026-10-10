import 'dart:typed_data';

/// What a drag out of the app is for. The name goes into telemetry as
/// `kind`, so it is a fixed slug and never anything the user typed.
enum DragOutKind {
  attachment('attachment'),
  kanbanAttachment('kanban_attachment');

  const DragOutKind(this.slug);

  final String slug;
}

/// What a drag carries out of the app. An item is built when a drag begins
/// and costs nothing until the receiver asks for it: a [DragOutFile] reads its
/// bytes only on the drop, never at drag start.
sealed class DragOutItem {
  const DragOutItem();
}

/// A file the receiver creates by asking for its bytes.
final class DragOutFile extends DragOutItem {
  const DragOutFile({required this.name, required this.read});

  /// The file name the receiver proposes, already safe (see
  /// [sanitizeDragFileName]).
  final String name;

  /// Produces the content; called once, only when the receiver wants the
  /// file. A throw ends the drop without a file.
  final Future<Uint8List> Function() read;
}

/// Text the receiver takes as plain text and as Markdown.
final class DragOutText extends DragOutItem {
  const DragOutText(this.text);

  final String text;
}

/// Why a drop that was accepted produced no data, as logged.
enum DragOutFailure { fetch, write }

/// How a drop ended, as logged.
enum DragOutOutcome { delivered, failed, cancelled }
