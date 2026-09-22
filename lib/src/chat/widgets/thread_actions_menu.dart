import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/hermes_theme.dart';
import '../chat_models.dart';
import '../thread_housekeeping.dart';

enum ThreadAction { copyTranscript, rename, pin, archive, delete }

/// The rename / pin / archive / delete menu for one thread, shared by the
/// sidebar row (dense, no copy) and the chat header (roomier, with
/// [includeCopyTranscript]). Without [housekeeping] only copying the
/// transcript is offered, for a local or mock thread the dashboard does not
/// hold.
class ThreadActionsButton extends StatefulWidget {
  const ThreadActionsButton({
    super.key,
    required this.thread,
    this.housekeeping,
    this.includeCopyTranscript = false,
    this.dense = false,
  });

  final ChatThread thread;
  final ThreadHousekeeping? housekeeping;
  final bool includeCopyTranscript;

  /// A 28px icon-only button for a tight row, instead of a normal-sized
  /// [IconButton].
  final bool dense;

  @override
  State<ThreadActionsButton> createState() => ThreadActionsButtonState();
}

class ThreadActionsButtonState extends State<ThreadActionsButton> {
  final _menu = GlobalKey<PopupMenuButtonState<ThreadAction>>();

  /// Opens the menu from outside, for a long press or a secondary click
  /// elsewhere on the row this button sits in.
  void open() => _menu.currentState?.showButtonMenu();

  ChatThread get _thread => widget.thread;

  Future<void> _run(ThreadAction action) async {
    if (action == ThreadAction.copyTranscript) {
      await Clipboard.setData(ClipboardData(text: threadTranscript(_thread)));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Transcript copied')));
      }
      return;
    }
    final housekeeping = widget.housekeeping;
    if (housekeeping == null) return;
    switch (action) {
      case ThreadAction.copyTranscript:
        break; // handled above
      case ThreadAction.rename:
        final title = await showDialog<String>(
          context: context,
          builder: (_) => _RenameDialog(initial: _thread.title),
        );
        if (title != null && title != _thread.title) {
          await housekeeping.rename(_thread, title);
        }
      case ThreadAction.pin:
        await housekeeping.setPinned(_thread, !_thread.pinned);
      case ThreadAction.archive:
        await housekeeping.archive(_thread);
      case ThreadAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => _DeleteDialog(title: _thread.title),
        );
        if (confirmed ?? false) await housekeeping.delete(_thread);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final housekeeping = widget.housekeeping;
    return PopupMenuButton<ThreadAction>(
      key: _menu,
      tooltip: 'Chat actions',
      icon: Icon(Icons.more_horiz, color: subtle),
      onSelected: _run,
      iconSize: widget.dense ? 16 : 24,
      padding: widget.dense ? EdgeInsets.zero : const EdgeInsets.all(8),
      style: widget.dense
          ? IconButton.styleFrom(
              minimumSize: const Size.square(28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      itemBuilder: (_) => [
        if (widget.includeCopyTranscript) ...[
          const PopupMenuItem(
            value: ThreadAction.copyTranscript,
            child: Text('Copy transcript'),
          ),
          if (housekeeping != null) const PopupMenuDivider(),
        ],
        if (housekeeping != null) ...[
          const PopupMenuItem(
            value: ThreadAction.rename,
            child: Text('Rename'),
          ),
          PopupMenuItem(
            value: ThreadAction.pin,
            child: Text(_thread.pinned ? 'Unpin' : 'Pin'),
          ),
          const PopupMenuItem(
            value: ThreadAction.archive,
            child: Text('Archive'),
          ),
          const PopupMenuItem(
            value: ThreadAction.delete,
            child: Text('Delete'),
          ),
        ],
      ],
    );
  }
}

/// A plain-text rendering of [thread] for the clipboard: one paragraph per
/// turn that has something to say, skipping ones that are only attachments
/// or tool calls.
String threadTranscript(ChatThread thread) {
  final parts = <String>[];
  for (final message in thread.messages) {
    final text = message.content.trim();
    if (text.isEmpty) continue;
    final speaker = message.role == ChatRole.user ? 'You' : 'Hermes';
    parts.add('$speaker: $text');
  }
  return parts.join('\n\n');
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename chat'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            onPressed: _controller.text.trim().isEmpty ? null : _save,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete this chat?'),
      content: Text('"$title" and its messages will be deleted for good.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
