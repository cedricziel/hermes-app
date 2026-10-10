import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../drag_out/drag_out_item.dart';
import '../../drag_out/drag_out_source.dart';
import '../../drag_out/sanitize_drag_file_name.dart';
import '../chat_models.dart';
import '../media/media_store.dart';

/// Lets the card or thumbnail of [attachment] be dragged out of the app as a
/// file, where drag-out exists (see [DragOut]); [child] unchanged elsewhere.
///
/// The file carries the attachment's name. Its bytes come from the data the
/// message already holds, else the file the user picked, else the server
/// through the [MediaStore], and are read only when the receiver asks for
/// them. An attachment with no source on this device and no absolute server
/// path starts no drag.
class DraggableAttachment extends StatelessWidget {
  const DraggableAttachment({
    super.key,
    required this.attachment,
    required this.child,
  });

  final ChatAttachment attachment;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragOut(
    kind: DragOutKind.attachment,
    item: () => attachmentDragItem(attachment, context.read<MediaStore?>()),
    child: child,
  );
}

/// What dragging [attachment] carries, or null when there is nothing to hand
/// out. Reads nothing until the receiver asks.
///
/// A file on this device (the picked file, or the copy in the media cache,
/// downloaded first if need be) is named as `localPath` and copied natively, so
/// its bytes are never loaded. Only an attachment the message embedded has no
/// file; its bytes are held in memory while they are handed over.
DragOutFile? attachmentDragItem(ChatAttachment attachment, MediaStore? store) {
  final bytes = attachment.bytes;
  final path = attachment.path;
  final remote = attachment.fetchPath;
  final fetchable = remote != null && store != null;
  if (bytes == null && path == null && !fetchable) return null;

  Future<Uint8List> read() async {
    if (bytes != null) return bytes;
    if (path != null) {
      try {
        return await File(path).readAsBytes();
      } on FileSystemException {
        // The picked file moved or went away; the server may still have it.
        if (!fetchable) rethrow;
      }
    }
    return (await store!.file(remote!, attachment.name)).readAsBytes();
  }

  Future<String?> localPath() async {
    if (bytes != null) return null;
    if (path != null && await File(path).exists()) return path;
    if (!fetchable) return null;
    return (await store.file(remote, attachment.name)).path;
  }

  return DragOutFile(
    name: sanitizeDragFileName(
      fileNameOf(attachment.name),
      fallback: 'Attachment',
    ),
    read: read,
    localPath: localPath,
  );
}
