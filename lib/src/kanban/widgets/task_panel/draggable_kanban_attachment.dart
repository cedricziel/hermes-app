import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/widgets.dart';

import '../../../drag_out/drag_out_item.dart';
import '../../../drag_out/drag_out_source.dart';
import '../../../drag_out/sanitize_drag_file_name.dart';
import '../../kanban_models.dart';

/// Lets the row of [attachment] be dragged out of the app as a file, where
/// drag-out exists (see [DragOut]); [child] unchanged elsewhere.
///
/// The file is named by the attachment's filename and fetched with [onRead]
/// only when the receiver asks for it. With no [onRead] nothing is draggable.
class DraggableKanbanAttachment extends StatelessWidget {
  const DraggableKanbanAttachment({
    super.key,
    required this.attachment,
    required this.onRead,
    required this.child,
  });

  final KanbanAttachment attachment;
  final Future<Uint8List> Function(KanbanAttachment attachment)? onRead;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final read = onRead;
    if (read == null) return child;
    return DragOut(
      kind: DragOutKind.kanbanAttachment,
      item: () => DragOutFile(
        name: sanitizeDragFileName(attachment.filename, fallback: 'Attachment'),
        read: () => read(attachment),
      ),
      child: child,
    );
  }
}
