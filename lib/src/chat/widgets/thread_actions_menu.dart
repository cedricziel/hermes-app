import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/named_popup_menu_button.dart';
import '../chat_models.dart';
import '../thread_housekeeping.dart';

enum ThreadAction {
  openInNewWindow,
  copyTranscript,
  rename,
  pin,
  archive,
  delete,
}

/// The menu of one thread as a Mac app lists it, with the shortcuts the menu
/// bar gives them. Without [manageable] (a thread the dashboard does not
/// hold) only copying the transcript is offered; "Open in New Window" only
/// with [canOpenInNewWindow].
List<PopupMenuEntry<ThreadAction>> macThreadMenuItems({
  required bool pinned,
  required bool manageable,
  bool canOpenInNewWindow = false,
}) => [
  if (canOpenInNewWindow) ...[
    const AdaptiveMenuItem(
      value: ThreadAction.openInNewWindow,
      shortcut: '⌥⌘O',
      child: Text('Open in New Window'),
    ),
    const PopupMenuDivider(),
  ],
  if (manageable) ...[
    const AdaptiveMenuItem(value: ThreadAction.rename, child: Text('Rename…')),
    AdaptiveMenuItem(
      value: ThreadAction.pin,
      shortcut: '⇧⌘P',
      child: Text(pinned ? 'Unpin' : 'Pin'),
    ),
  ],
  const AdaptiveMenuItem(
    value: ThreadAction.copyTranscript,
    child: Text('Copy Transcript'),
  ),
  if (manageable) ...[
    const AdaptiveMenuItem(value: ThreadAction.archive, child: Text('Archive')),
    const PopupMenuDivider(),
    const AdaptiveMenuItem(
      value: ThreadAction.delete,
      shortcut: '⌘⌫',
      destructive: true,
      child: Text('Delete…'),
    ),
  ],
];

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
    this.onOpenInNewWindow,
  });

  final ChatThread thread;
  final ThreadHousekeeping? housekeeping;
  final bool includeCopyTranscript;

  /// Opens the thread in a window of its own; the menu leaves the item out
  /// without it. Mac only.
  final ValueChanged<ChatThread>? onOpenInNewWindow;

  /// A 28px icon-only button for a tight row, instead of a normal-sized
  /// [IconButton].
  final bool dense;

  @override
  State<ThreadActionsButton> createState() => ThreadActionsButtonState();
}

class ThreadActionsButtonState extends State<ThreadActionsButton> {
  final _menu = AdaptiveMenuController();

  /// Opens the menu from outside, for a long press or a secondary click
  /// elsewhere on the row this button sits in.
  void open() => _menu.open();

  ChatThread get _thread => widget.thread;

  Future<void> _run(ThreadAction action) => runThreadAction(
    context,
    action,
    thread: _thread,
    housekeeping: widget.housekeeping,
    onOpenInNewWindow: widget.onOpenInNewWindow,
  );

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final housekeeping = widget.housekeeping;
    return NamedPopupMenuButton<ThreadAction>(
      controller: _menu,
      label: 'Chat actions for ${_thread.title}',
      tooltip: 'Chat actions',
      icon: AppIcons.more,
      color: subtle,
      onSelected: _run,
      iconSize: widget.dense ? 16 : 24,
      padding: widget.dense ? EdgeInsets.zero : const EdgeInsets.all(8),
      style: widget.dense
          ? IconButton.styleFrom(
              minimumSize: const Size.square(28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      itemBuilder: (context) => [
        if (platformChromeOf(context) == PlatformChrome.macos)
          ...macThreadMenuItems(
            pinned: _thread.pinned,
            manageable: housekeeping != null,
            canOpenInNewWindow: widget.onOpenInNewWindow != null,
          )
        else ...[
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
      ],
    );
  }
}

/// Carries out [action] on [thread]: copying needs no [housekeeping], the rest
/// do. Rename asks for a title and delete for confirmation first. Copying
/// reads the whole history of a thread that is not loaded through
/// [housekeeping].
Future<void> runThreadAction(
  BuildContext context,
  ThreadAction action, {
  required ChatThread thread,
  required ThreadHousekeeping? housekeeping,
  ValueChanged<ChatThread>? onOpenInNewWindow,
}) async {
  switch ((action, housekeeping)) {
    case (ThreadAction.openInNewWindow, _):
      onOpenInNewWindow?.call(thread);
    case (ThreadAction.copyTranscript, _):
      await _copyTranscript(context, thread, housekeeping);
    case (_, null):
      break;
    case (ThreadAction.rename, final housekeeping?):
      final title = await showAdaptiveDialog<String>(
        context: context,
        builder: (_) => _RenameDialog(initial: thread.title),
      );
      if (title != null && title != thread.title) {
        await housekeeping.rename(thread, title);
      }
    case (ThreadAction.pin, final housekeeping?):
      await housekeeping.setPinned(thread, !thread.pinned);
    case (ThreadAction.archive, final housekeeping?):
      await housekeeping.archive(thread);
    case (ThreadAction.delete, final housekeeping?):
      final confirmed = await showConfirmDialog(
        context,
        title: 'Delete this chat?',
        message: '"${thread.title}" and its messages will be deleted for good.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (confirmed) await housekeeping.delete(thread);
  }
}

Future<void> _copyTranscript(
  BuildContext context,
  ChatThread thread,
  ThreadHousekeeping? housekeeping,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final String text;
  try {
    text = threadTranscript(
      await (housekeeping?.history(thread) ?? Future.value(thread.messages)),
    );
  } on Object {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Could not copy the transcript')),
    );
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
  messenger?.showSnackBar(const SnackBar(content: Text('Transcript copied')));
}

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
    return AppAlertDialog(
      title: const Text('Rename chat'),
      content: AppDialogTextField(
        controller: _controller,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        AppDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => AppDialogAction(
            isDefault: true,
            onPressed: _controller.text.trim().isEmpty ? null : _save,
            child: const Text('Save'),
          ),
        ),
      ],
    );
  }
}
