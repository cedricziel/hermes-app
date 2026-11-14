import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../chat/chat_controller.dart';
import '../../widgets/app_banner.dart';
import '../../chat/chat_models.dart';
import '../../chat/chat_workspace_state.dart';
import '../../widgets/adaptive_sheet.dart';
import '../folder_labels.dart';
import '../widgets/change_folder_confirmation.dart';
import '../widgets/working_directory_details.dart';
import '../workspace_catalog_loader.dart';
import '../workspace_picker_controller.dart';
import 'thread_folder.dart';
import 'workspace_guard.dart';
import 'workspace_picker_sheet.dart';

/// Whether the folders of this chat controller are offered at all: it has a
/// workspaces repository, which only a main window gives it.
bool workspacesOffered(ChatController chat) => chat.workspaces != null;

/// Picks the folder a new chat will run in, once, on the person's say-so: the
/// picker opens, a pick is kept in the draft (never sent until the chat's
/// first message) and the server default clears it. Closes by itself when
/// the app locks, the session ends or the recipient's profile changes.
Future<void> chooseNewChatFolder(
  BuildContext context,
  ChatController chat,
) async {
  if (!workspacesOffered(chat)) return;
  // The pick belongs to the draft that was open: switching drafts closes it.
  final guard = WorkspaceGuard(chat, trackSelection: true);
  try {
    await showWorkspacePicker(
      context,
      chat: chat,
      guard: guard,
      onPick: (FolderPick pick) async {
        chat.chooseWorkspace(pick.choice);
        return true;
      },
    );
  } finally {
    guard.dispose();
  }
}

/// Opens the details of where [thread] runs: its folder, path, branch and
/// project, how a move stands, and "Change folder…" where the chat can be
/// moved. With [openPicker] the picker opens over it at once (the Mac menu's
/// "Change Folder…"). In a [conversationWindow] it only shows.
Future<void> showWorkingDirectoryDetails(
  BuildContext context, {
  required ChatController chat,
  required ChatThread thread,
  bool conversationWindow = false,
  bool openPicker = false,
}) async {
  final guard = WorkspaceGuard(chat, thread: thread);
  try {
    await showAdaptiveSheet<void>(
      context,
      maxWidth: 480,
      builder: (sheet) => _DetailsSheet(
        chat: chat,
        threadId: thread.id,
        first: thread,
        guard: guard,
        conversationWindow: conversationWindow,
        openPicker: openPicker,
      ),
    );
  } finally {
    guard.dispose();
  }
}

class _DetailsSheet extends StatefulWidget {
  const _DetailsSheet({
    required this.chat,
    required this.threadId,
    required this.first,
    required this.guard,
    required this.conversationWindow,
    required this.openPicker,
  });

  final ChatController chat;
  final String threadId;
  final ChatThread first;
  final WorkspaceGuard guard;
  final bool conversationWindow;
  final bool openPicker;

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  String? _target;
  var _pickerOpen = false;
  WorkspaceCatalogLoader? _loader;

  ChatController get _chat => widget.chat;

  /// The chat as the controller holds it now: a reload replaces the objects.
  ChatThread get _thread => _chat.threads.firstWhere(
    (t) => t.id == widget.threadId && t.remote == widget.first.remote,
    orElse: () => widget.first,
  );

  @override
  void initState() {
    super.initState();
    widget.guard.closed.addListener(_guardChanged);
    // The project line needs the catalog; read it for the details.
    _loader = _chat.workspaceCatalog();
    if (widget.openPicker) {
      _loader?.addListener(_openPickerWhenKnown);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPickerWhenKnown(),
      );
    }
  }

  @override
  void dispose() {
    widget.guard.closed.removeListener(_guardChanged);
    _loader?.removeListener(_openPickerWhenKnown);
    super.dispose();
  }

  /// Own route only: a picker or confirmation opened over this sheet closes
  /// by its own guard.
  void _guardChanged() {
    if (widget.guard.closed.value && mounted) closeOwnRoute(context);
  }

  /// "Change Folder…" from the menu opens the picker once the catalog has
  /// said the server can move a chat: never on an older server.
  void _openPickerWhenKnown() {
    if (!mounted || _pickerAsked) return;
    final status = _loader?.status;
    if (status == WorkspaceCatalogStatus.idle ||
        status == WorkspaceCatalogStatus.loading) {
      return;
    }
    _pickerAsked = true;
    _loader?.removeListener(_openPickerWhenKnown);
    if (_chat.workspaceChangeOffered(_thread)) unawaited(_change());
  }

  /// Why the last confirmed move was not sent, shown over the details.
  WorkspaceMoveBlock? _blocked;
  var _pickerAsked = false;

  Future<void> _change() async {
    if (_pickerOpen || !_chat.workspaceChangeOffered(_thread)) return;
    _pickerOpen = true;
    setState(() => _blocked = null);
    final thread = _thread;
    final guard = WorkspaceGuard(_chat, thread: thread);
    try {
      await showWorkspacePicker(
        context,
        chat: _chat,
        guard: guard,
        moving: thread,
        onPick: (pick) async {
          final path = pick.path;
          if (path == null) return false;
          final confirmed = await showChangeFolderConfirmation(
            context,
            folderName: folderLabelFor(path),
            path: path,
            dismissWhen: guard.closed,
          );
          if (!confirmed || guard.closed.value || !mounted) return false;
          // The chat as it is now: a reload replaces the objects, and a reply
          // may have started while the person chose.
          final current = _thread;
          final block = _chat.workspaceMoveBlock(current);
          if (block != null) {
            setState(() => _blocked = block);
            return true;
          }
          setState(() => _target = path);
          // Sent once; what came of it is [workspaceMoveOf].
          unawaited(
            _chat.moveWorkspace(current, path).then((late) {
              if (late != null && mounted) setState(() => _blocked = late);
            }),
          );
          return true;
        },
      );
    } finally {
      guard.dispose();
      _pickerOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_chat, ?_loader]),
    builder: (context, _) {
      final thread = _thread;
      final folder = threadFolderOf(_chat, thread);
      if (folder == null) {
        return const SizedBox(height: 120);
      }
      final block = _chat.workspaceMoveBlock(thread);
      final move = _chat.workspaceMoveOf(thread);
      final catalogStatus = _loader?.status;
      final canChange =
          !widget.conversationWindow &&
          block != WorkspaceMoveBlock.unsupported &&
          block != WorkspaceMoveBlock.botChat &&
          block != WorkspaceMoveBlock.notAvailable &&
          catalogStatus != WorkspaceCatalogStatus.unsupported;
      final details = WorkingDirectoryDetails(
        folderName: folder.name,
        path: folder.path,
        branch: folder.branch,
        projectName: folder.projectName,
        homeFolder: folder.home,
        replying: block == WorkspaceMoveBlock.replying,
        offline: catalogStatus == WorkspaceCatalogStatus.offline,
        canChange: canChange,
        conversationWindow: widget.conversationWindow,
        move: move,
        moveTarget: _target,
        moveTimedOut: move.timedOut,
        onChange: () => unawaited(_change()),
        onTryAgain: () => unawaited(_change()),
        onCheckAgain: () => unawaited(_chat.recheckWorkspaceMove(thread)),
        onClose: () => Navigator.of(context).pop(),
      );
      final blocked = _blocked;
      if (blocked == null) return details;
      final l10n = context.l10n;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AppBanner(
              key: const Key('working-directory-blocked'),
              tone: AppBannerTone.neutral,
              title: switch (blocked) {
                WorkspaceMoveBlock.replying => l10n.workspacesReasonReplying,
                WorkspaceMoveBlock.moving => l10n.workspacesReasonChanging,
                _ => l10n.workspacesMoveNotChanged,
              },
              detail: l10n.workspacesMoveNothingChanged,
            ),
          ),
          Flexible(child: details),
        ],
      );
    },
  );
}

/// The words of the mismatch notice's folders: the folder names the chat list
/// uses.
({String startedIn, String picked}) mismatchNames(WorkspaceMismatch mismatch) =>
    (
      startedIn: folderLabelFor(mismatch.reported),
      picked: folderLabelFor(mismatch.picked),
    );
