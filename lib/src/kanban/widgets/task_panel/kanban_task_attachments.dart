import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../../chat/widgets/quick_look_target.dart';
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
///
/// On macOS a row is a Finder item (see [QuickLookTarget]): a click selects
/// it, a double-click runs [onOpen], Space runs [onToggleQuickLook], and its
/// context menu offers Quick Look ([onQuickLook]), Open and Save. Without
/// the callbacks the entries are disabled.
class KanbanTaskAttachments extends StatelessWidget {
  const KanbanTaskAttachments({
    super.key,
    required this.attachments,
    required this.onAttach,
    required this.onDownload,
    required this.onRemove,
    this.transferring = false,
    this.onRead,
    this.onOpen,
    this.onQuickLook,
    this.onToggleQuickLook,
  });

  final List<KanbanAttachment> attachments;
  final bool transferring;
  final VoidCallback onAttach;
  final ValueChanged<KanbanAttachment> onDownload;
  final ValueChanged<KanbanAttachment> onRemove;

  /// Fetches an attachment's bytes for a drag out of the app.
  final Future<Uint8List> Function(KanbanAttachment attachment)? onRead;

  /// Downloads an attachment and opens it in the system's app for its type.
  final ValueChanged<KanbanAttachment>? onOpen;

  /// Shows an attachment in Quick Look.
  final ValueChanged<KanbanAttachment>? onQuickLook;

  /// Shows an attachment in Quick Look, or closes the panel when it already
  /// shows it.
  final ValueChanged<KanbanAttachment>? onToggleQuickLook;

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
          child: _QuickLookRow(
            attachment: a,
            transferring: transferring,
            onOpen: onOpen,
            onQuickLook: onQuickLook,
            onToggleQuickLook: onToggleQuickLook,
            onDownload: onDownload,
            child: ListTile(
              dense: true,
              contentPadding: quickLookTargetsAt(context)
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : EdgeInsets.zero,
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

/// Makes the row of [attachment] a [QuickLookTarget]. Its actions do nothing
/// while a transfer runs.
class _QuickLookRow extends StatelessWidget {
  const _QuickLookRow({
    required this.attachment,
    required this.transferring,
    required this.onOpen,
    required this.onQuickLook,
    required this.onToggleQuickLook,
    required this.onDownload,
    required this.child,
  });

  final KanbanAttachment attachment;
  final bool transferring;
  final ValueChanged<KanbanAttachment>? onOpen;
  final ValueChanged<KanbanAttachment>? onQuickLook;
  final ValueChanged<KanbanAttachment>? onToggleQuickLook;
  final ValueChanged<KanbanAttachment> onDownload;
  final Widget child;

  VoidCallback? _bind(ValueChanged<KanbanAttachment>? action) =>
      action == null || transferring ? null : () => action(attachment);

  @override
  Widget build(BuildContext context) => QuickLookTarget(
    borderRadius: BorderRadius.circular(8),
    onOpen: _bind(onOpen),
    onShow: _bind(onQuickLook),
    onToggle: onToggleQuickLook == null
        ? null
        : () {
            if (!transferring) onToggleQuickLook!(attachment);
          },
    onSave: _bind(onDownload),
    child: child,
  );
}

/// `512 B`, `1.5 KB`, `2.0 MB`.
String kanbanFileSize(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
