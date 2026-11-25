import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';
import 'package:flutter/services.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';

import '../../../l10n/l10n.dart';
import '../../telemetry/report_bug.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/named_popup_menu_button.dart';
import '../chat_models.dart';
import '../thread_export.dart';
import '../thread_housekeeping.dart';
import 'thread_rename_dialog.dart';

// Where the transcript used to live; the conversation window still imports it
// from here.
export '../thread_export.dart' show threadTranscript;

enum ThreadAction {
  openInNewWindow,
  showFiles,
  changeFolder,
  copyTranscript,
  exportJson,
  branch,
  rename,
  pin,
  archive,
  delete,
}

/// "Change Folder…" in a thread's menu: offered while the server can move a
/// chat's folder, and disabled while the chat replies.
class ChangeFolderOffer {
  const ChangeFolderOffer({required this.onSelected, this.enabled = true});

  final VoidCallback onSelected;
  final bool enabled;
}

/// "Export Chat as JSON…" in a thread's menu: offered for a chat the server
/// holds under a known profile, and disabled while an export runs.
/// [onSelected] opens the confirmation for that chat.
class ExportJsonOffer {
  const ExportJsonOffer({required this.onSelected, this.enabled = true});

  final VoidCallback onSelected;
  final bool enabled;
}

/// The menu of one thread as a Mac app lists it, with the shortcuts the menu
/// bar gives them. Without [manageable] (a thread the dashboard does not
/// hold) only copying the transcript is offered; "Open in New Window" only
/// with [canOpenInNewWindow], and "Branch in New Chat" only with [canBranch].
List<PopupMenuEntry<ThreadAction>> macThreadMenuItems(
  AppLocalizations l10n, {
  required bool pinned,
  required bool manageable,
  bool canOpenInNewWindow = false,
  bool canonical = false,
  bool canBranch = false,
  ChangeFolderOffer? changeFolder,
  ExportJsonOffer? exportJson,
}) => [
  if (canOpenInNewWindow) ...[
    AdaptiveMenuItem(
      value: ThreadAction.openInNewWindow,
      shortcut: '⌥⌘O',
      child: Text(l10n.macosMenuOpenInNewWindow),
    ),
    const PopupMenuDivider(),
  ],
  if (manageable) ...[
    if (!canonical)
      AdaptiveMenuItem(
        value: ThreadAction.rename,
        child: Text(l10n.macosMenuRename),
      ),
    if (changeFolder != null && !canonical)
      AdaptiveMenuItem(
        value: ThreadAction.changeFolder,
        enabled: changeFolder.enabled,
        child: Text(l10n.macosMenuChangeFolder),
      ),
    AdaptiveMenuItem(
      value: ThreadAction.pin,
      shortcut: '⇧⌘P',
      child: Text(pinned ? l10n.macosMenuUnpin : l10n.macosMenuPin),
    ),
  ],
  AdaptiveMenuItem(
    value: ThreadAction.copyTranscript,
    child: Text(l10n.macosMenuCopyTranscript),
  ),
  if (exportJson != null)
    AdaptiveMenuItem(
      value: ThreadAction.exportJson,
      enabled: exportJson.enabled,
      child: Text(l10n.macosMenuExportChat),
    ),
  if (manageable && canBranch && !canonical)
    AdaptiveMenuItem(
      value: ThreadAction.branch,
      child: Text(l10n.chatWidgetsThreadMenuBranch),
    ),
  if (manageable) ...[
    AdaptiveMenuItem(
      value: ThreadAction.archive,
      child: Text(
        canonical ? l10n.chatWidgetsThreadMenuRetire : l10n.macosMenuArchive,
      ),
    ),
    const PopupMenuDivider(),
    AdaptiveMenuItem(
      value: ThreadAction.delete,
      shortcut: '⌘⌫',
      destructive: true,
      child: Text(l10n.macosMenuDelete),
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
    this.onShowFiles,
    this.changeFolder,
    this.exportJson,
  });

  final ChatThread thread;

  /// "Export Chat as JSON…" after Copy transcript; null leaves it out. Only a
  /// menu with [includeCopyTranscript] (or the Mac's) shows it.
  final ExportJsonOffer? exportJson;

  /// "Change Folder…" in the Mac menu; null leaves it out.
  final ChangeFolderOffer? changeFolder;

  /// Opens the chat's Files page; the menu has no Files item without it.
  final VoidCallback? onShowFiles;
  final ThreadHousekeeping? housekeeping;
  final bool includeCopyTranscript;

  /// Opens the thread in a window of its own; the menu leaves the item out
  /// without it. Mac only.
  final ValueChanged<ChatThread>? onOpenInNewWindow;

  /// A 28px icon-only button for a tight row, instead of a normal-sized
  /// [IconButton]. On Android it grows to the 48dp touch target.
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

  Future<void> _run(ThreadAction action) => action == ThreadAction.showFiles
      ? Future(() => widget.onShowFiles?.call())
      : action == ThreadAction.changeFolder
      ? Future(() => widget.changeFolder?.onSelected())
      : runThreadAction(
          context,
          action,
          thread: _thread,
          housekeeping: widget.housekeeping,
          onOpenInNewWindow: widget.onOpenInNewWindow,
          exportJson: widget.exportJson,
        );

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final housekeeping = widget.housekeeping;
    return NamedPopupMenuButton<ThreadAction>(
      controller: _menu,
      label: context.l10n.chatWidgetsThreadMenuLabel(_thread.title),
      tooltip: context.l10n.chatWidgetsThreadMenuTooltip,
      icon: AppIcons.more,
      color: subtle,
      onSelected: _run,
      iconSize: widget.dense ? 16 : 24,
      padding: widget.dense ? EdgeInsets.zero : const EdgeInsets.all(8),
      style: widget.dense
          ? IconButton.styleFrom(
              minimumSize: const Size.square(28),
              tapTargetSize: isAndroid(context)
                  ? MaterialTapTargetSize.padded
                  : MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      itemBuilder: (context) => [
        if (platformChromeOf(context) == PlatformChrome.macos)
          ...macThreadMenuItems(
            context.l10n,
            pinned: _thread.pinned,
            canonical: _thread.isCanonicalBotChat,
            manageable: housekeeping != null,
            canOpenInNewWindow: widget.onOpenInNewWindow != null,
            canBranch: housekeeping?.branch != null && _thread.remote,
            changeFolder: widget.changeFolder,
            exportJson: widget.exportJson,
          )
        else ...[
          if (widget.onShowFiles != null)
            PopupMenuItem(
              value: ThreadAction.showFiles,
              child: Text(context.l10n.filesEntryLabel),
            ),
          if (widget.includeCopyTranscript) ...[
            PopupMenuItem(
              value: ThreadAction.copyTranscript,
              child: Text(context.l10n.chatWidgetsThreadMenuCopyTranscript),
            ),
            if (widget.exportJson case final offer?)
              PopupMenuItem(
                value: ThreadAction.exportJson,
                enabled: offer.enabled,
                child: Text(context.l10n.chatWidgetsThreadMenuExportJson),
              ),
            if (housekeeping != null) const PopupMenuDivider(),
          ],
          if (housekeeping != null) ...[
            if (!_thread.isCanonicalBotChat)
              PopupMenuItem(
                value: ThreadAction.rename,
                child: Text(context.l10n.chatWidgetsThreadMenuRename),
              ),
            PopupMenuItem(
              value: ThreadAction.pin,
              child: Text(
                _thread.pinned
                    ? context.l10n.chatWidgetsThreadMenuUnpin
                    : context.l10n.chatWidgetsThreadMenuPin,
              ),
            ),
            PopupMenuItem(
              value: ThreadAction.archive,
              child: Text(
                _thread.isCanonicalBotChat
                    ? context.l10n.chatWidgetsThreadMenuRetire
                    : context.l10n.chatWidgetsThreadMenuArchive,
              ),
            ),
            PopupMenuItem(
              value: ThreadAction.delete,
              child: Text(context.l10n.chatWidgetsThreadMenuDelete),
            ),
          ],
        ],
      ],
    );
  }
}

/// Carries out [action] on [thread]: copying needs no [housekeeping], the rest
/// do. Exporting goes through [exportJson] and only while it is enabled. Rename asks for a title and delete for confirmation first. Copying
/// reads the whole history of a thread that is not loaded through
/// [housekeeping].
Future<void> runThreadAction(
  BuildContext context,
  ThreadAction action, {
  required ChatThread thread,
  required ThreadHousekeeping? housekeeping,
  ValueChanged<ChatThread>? onOpenInNewWindow,
  ExportJsonOffer? exportJson,
}) async {
  switch ((action, housekeeping)) {
    case (ThreadAction.showFiles, _) || (ThreadAction.changeFolder, _):
      break;
    case (ThreadAction.openInNewWindow, _):
      onOpenInNewWindow?.call(thread);
    case (ThreadAction.copyTranscript, _):
      await _copyTranscript(context, thread, housekeeping);
    case (ThreadAction.exportJson, _):
      if (exportJson != null && exportJson.enabled) exportJson.onSelected();
    case (_, null):
      break;
    case (ThreadAction.branch, final housekeeping?):
      await housekeeping.branch?.call(thread);
    case (ThreadAction.rename, final housekeeping?):
      if (thread.isCanonicalBotChat) return;
      final title = await showAppDialog<String>(
        context: context,
        // A stray click on macOS must not throw away the typed title.
        barrierDismissible: platformChromeOf(context) == PlatformChrome.macos
            ? false
            : null,
        builder: (_) => ThreadRenameDialog(initial: thread.title),
      );
      if (title != null && title != thread.title) {
        await housekeeping.rename(thread, title);
      }
    case (ThreadAction.pin, final housekeeping?):
      await housekeeping.setPinned(thread, !thread.pinned);
    case (ThreadAction.archive, final housekeeping?):
      if (thread.isCanonicalBotChat) {
        final l10n = context.l10n;
        final confirmed = await showConfirmDialog(
          context,
          title: l10n.chatWidgetsThreadMenuRetireConfirmTitle,
          message: l10n.chatWidgetsThreadMenuRetireConfirmMessage,
          confirmLabel: l10n.chatWidgetsThreadMenuRetireConfirmButton,
          cancelLabel: l10n.chatWidgetsThreadMenuCancel,
          destructive: true,
        );
        if (confirmed) {
          await housekeeping.archive(thread, retireCanonical: true);
        }
      } else {
        await housekeeping.archive(thread);
      }
    case (ThreadAction.delete, final housekeeping?):
      final l10n = context.l10n;
      final confirmed = await showDestructiveConfirm(
        context,
        title: l10n.chatWidgetsThreadMenuDeleteTitle,
        message: l10n.chatWidgetsThreadMenuDeleteMessage(thread.title),
        confirmLabel: l10n.chatWidgetsThreadMenuDelete,
        cancelLabel: l10n.chatWidgetsThreadMenuCancel,
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
  final l10n = context.l10n;
  final String text;
  try {
    text = threadTranscript(await threadHistory(thread, housekeeping));
  } on Object catch (e, stack) {
    reportBug(e, stack, 'a transcript copy');
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.chatWidgetsThreadMenuCopyFailed)),
    );
    return;
  }
  await Clipboard.setData(ClipboardData(text: text));
  messenger?.showSnackBar(
    SnackBar(content: Text(l10n.chatWidgetsThreadMenuCopied)),
  );
}
