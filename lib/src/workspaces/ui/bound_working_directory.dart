import 'package:flutter/material.dart';

import '../../chat/chat_controller.dart';
import '../../chat/chat_models.dart';
import '../folder_labels.dart';
import '../workspace_catalog_loader.dart';
import '../workspace_paths.dart';
import '../widgets/folder_mismatch_notice.dart';
import '../widgets/folder_toolbar_button.dart';
import '../widgets/working_directory_line.dart';
import '../widgets/working_directory_row.dart';
import 'thread_folder.dart';
import 'workspace_flows.dart';

/// Builds the folder line of an open chat for a bar: in its title slot, or
/// as a full-width row under the bar. [title] puts the chat's title in the
/// same tap target.
typedef FolderLineBuilder = Widget Function(
  BuildContext context, {
  bool? belowBar,
  String? title,
});

/// The row above a new chat's composer: where the first message will run.
/// Nothing on an older server that has no folder to show, and nothing without
/// a repository (the quick panel, a conversation window).
class BoundWorkingDirectoryRow extends StatelessWidget {
  const BoundWorkingDirectoryRow({super.key, required this.chat});

  final ChatController chat;

  @override
  Widget build(BuildContext context) {
    if (!workspacesOffered(chat)) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final view = chat.newChatWorkspace();
        if (view.hidden) return const SizedBox.shrink();
        final folder = view.folder;
        final home = chat.workspaceHome;
        return WorkingDirectoryRow(
          state: view.lookingUp
              ? WorkingDirectoryRowState.lookingUp
              : folder == null
              ? WorkingDirectoryRowState.stalled
              : WorkingDirectoryRowState.ready,
          folderName: folder == null ? null : folderLabelFor(folder),
          path: folder,
          branch: view.branch,
          projectName: view.projectName,
          serverDefault: view.isServerDefault,
          homeFolder:
              folder != null && isRiskyWorkspaceFolder(folder, home: home),
          offline: view.status == WorkspaceCatalogStatus.offline,
          onTap: view.lookingUp
              ? null
              : () => chooseNewChatFolder(context, chat),
        );
      },
    );
  }
}

/// The line under an open chat's title, which opens the details of its
/// folder. Without folder data it is the plain [title], or nothing.
class BoundWorkingDirectoryLine extends StatelessWidget {
  const BoundWorkingDirectoryLine({
    super.key,
    required this.chat,
    required this.thread,
    this.belowBar,
    this.title,
    this.conversationWindow = false,
  });

  final ChatController chat;
  final ChatThread thread;
  final bool? belowBar;
  final String? title;
  final bool conversationWindow;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: chat,
    builder: (context, _) {
      final folder = threadFolderOf(chat, thread);
      if (folder == null) {
        final plain = title;
        return plain == null
            ? const SizedBox.shrink()
            : Text(plain, maxLines: 1, overflow: TextOverflow.ellipsis);
      }
      return WorkingDirectoryLine(
        folderName: folder.name,
        branch: folder.branch,
        offline: chat.workspaceOffline,
        title: title,
        belowBar: belowBar,
        onTap: () => showWorkingDirectoryDetails(
          context,
          chat: chat,
          thread: thread,
          conversationWindow: conversationWindow,
        ),
      );
    },
  );
}

/// A [FolderLineBuilder] for [thread]; null when the chat has no folder data
/// to show yet is still drawn by the builder, which then shows the title only.
FolderLineBuilder folderLineBuilder(
  ChatController chat,
  ChatThread thread, {
  bool conversationWindow = false,
}) =>
    (context, {belowBar, title}) => BoundWorkingDirectoryLine(
      chat: chat,
      thread: thread,
      belowBar: belowBar,
      title: title,
      conversationWindow: conversationWindow,
    );

/// The Mac toolbar's folder button: on a new chat it opens the picker, on an
/// open chat the details. Nothing where the chat has no folder to name.
class BoundFolderToolbarButton extends StatelessWidget {
  const BoundFolderToolbarButton({
    super.key,
    required this.chat,
    required this.thread,
    this.conversationWindow = false,
  });

  final ChatController chat;

  /// The open chat, or null for a new one.
  final ChatThread? thread;
  final bool conversationWindow;

  @override
  Widget build(BuildContext context) {
    final open = thread;
    if (open == null && !workspacesOffered(chat)) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        if (open != null && (open.remote || open.workingDirectory != null)) {
          final folder = threadFolderOf(chat, open);
          if (folder == null) return const SizedBox.shrink();
          return FolderToolbarButton(
            folderName: folder.name,
            path: folder.path,
            branch: folder.branch,
            onPressed: () => showWorkingDirectoryDetails(
              context,
              chat: chat,
              thread: open,
              conversationWindow: conversationWindow,
            ),
          );
        }
        final view = chat.newChatWorkspace();
        final folder = view.folder;
        if (view.hidden || folder == null) return const SizedBox.shrink();
        return FolderToolbarButton(
          folderName: folderLabelFor(folder),
          path: folder,
          branch: view.branch,
          onPressed: () => chooseNewChatFolder(context, chat),
        );
      },
    );
  }
}

/// The notice that Hermes started a new chat in another folder than the one
/// picked, with "Choose another folder", which opens the chat's details where
/// the folder can be changed. Nothing without a notice.
class BoundFolderMismatchNotice extends StatelessWidget {
  const BoundFolderMismatchNotice({
    super.key,
    required this.chat,
    required this.thread,
  });

  final ChatController chat;
  final ChatThread thread;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: chat,
    builder: (context, _) {
      final mismatch = chat.workspaceMismatchOf(thread);
      if (mismatch == null) return const SizedBox.shrink();
      final names = mismatchNames(mismatch);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: FolderMismatchNotice(
          startedIn: names.startedIn,
          picked: names.picked,
          profileMayUseOwnFolder: mismatch.profileMayUseOwnFolder,
          onChoose: () => showWorkingDirectoryDetails(
            context,
            chat: chat,
            thread: thread,
            openPicker: true,
          ),
        ),
      );
    },
  );
}
