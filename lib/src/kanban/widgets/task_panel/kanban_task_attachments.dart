import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../../widgets/busy_bar.dart';
import '../../../theme/app_icons.dart';
import '../../../widgets/named_icon_button.dart';
import '../../kanban_models.dart';
import 'draggable_kanban_attachment.dart';
import 'kanban_task_heading.dart';

/// The task's attachments, each to save or remove, and a button to attach
/// another. Nothing can start while a transfer runs. When [onRead] is given,
/// a row can also be dragged out of the app as a file, which a transfer in
/// progress does not stop.
class KanbanTaskAttachments extends StatelessWidget {
  const KanbanTaskAttachments({
    super.key,
    required this.attachments,
    required this.onAttach,
    required this.onDownload,
    required this.onRemove,
    this.transferring = false,
    this.onRead,
  });

  final List<KanbanAttachment> attachments;
  final bool transferring;
  final VoidCallback onAttach;
  final ValueChanged<KanbanAttachment> onDownload;
  final ValueChanged<KanbanAttachment> onRemove;

  /// Fetches an attachment's bytes for a drag out of the app.
  final Future<Uint8List> Function(KanbanAttachment attachment)? onRead;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const KanbanTaskHeading('Attachments'),
      if (transferring) const BusyBar(),
      for (final a in attachments)
        DraggableKanbanAttachment(
          attachment: a,
          onRead: onRead,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const AppIcon(AppIcons.attach),
            title: Text(a.filename),
            subtitle: Text(kanbanFileSize(a.size)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NamedIconButton(
                  label: 'Save ${a.filename}',
                  tooltip: 'Save attachment',
                  icon: AppIcons.download,
                  onPressed: transferring ? null : () => onDownload(a),
                ),
                NamedIconButton(
                  label: 'Remove ${a.filename}',
                  tooltip: 'Remove attachment',
                  icon: AppIcons.close,
                  onPressed: transferring ? null : () => onRemove(a),
                ),
              ],
            ),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: transferring ? null : onAttach,
          icon: const AppIcon(AppIcons.attach),
          label: const Text('Attach file'),
        ),
      ),
    ],
  );
}

/// `512 B`, `1.5 KB`, `2.0 MB`.
String kanbanFileSize(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
