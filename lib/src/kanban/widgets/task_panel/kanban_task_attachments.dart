import 'package:flutter/material.dart';

import '../../kanban_models.dart';
import 'kanban_task_heading.dart';

/// The task's attachments, each to save or remove, and a button to attach
/// another. Nothing can start while a transfer runs.
class KanbanTaskAttachments extends StatelessWidget {
  const KanbanTaskAttachments({
    super.key,
    required this.attachments,
    required this.onAttach,
    required this.onDownload,
    required this.onRemove,
    this.transferring = false,
  });

  final List<KanbanAttachment> attachments;
  final bool transferring;
  final VoidCallback onAttach;
  final ValueChanged<KanbanAttachment> onDownload;
  final ValueChanged<KanbanAttachment> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const KanbanTaskHeading('Attachments'),
      if (transferring) const LinearProgressIndicator(),
      for (final a in attachments)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.attach_file),
          title: Text(a.filename),
          subtitle: Text(kanbanFileSize(a.size)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Save attachment',
                icon: const Icon(Icons.download_outlined),
                onPressed: transferring ? null : () => onDownload(a),
              ),
              IconButton(
                tooltip: 'Remove attachment',
                icon: const Icon(Icons.close),
                onPressed: transferring ? null : () => onRemove(a),
              ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: transferring ? null : onAttach,
          icon: const Icon(Icons.attach_file),
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
