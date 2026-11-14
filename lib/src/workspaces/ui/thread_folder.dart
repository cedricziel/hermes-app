import '../../chat/chat_controller.dart';
import '../../chat/chat_models.dart';
import '../../chat/thread_sections.dart' show folderLabelUniverse;
import '../folder_labels.dart';
import '../workspace_paths.dart';

/// Where an open chat runs, as the header line and the details show it.
class ThreadFolder {
  const ThreadFolder({
    required this.name,
    required this.path,
    this.branch,
    this.projectName,
    this.home = false,
  });

  /// The folder's label, the same one the chat list's section headers use.
  final String name;

  /// The folder's full path on the server: where the chat runs, which may be
  /// below its git root.
  final String path;
  final String? branch;
  final String? projectName;

  /// The folder is the server's home folder or `/`.
  final bool home;
}

/// [thread]'s folder, or null when the chat has no folder data (an older
/// server, a chat not stored yet). Nothing is read: the fields come from the
/// chat's own row, from where Hermes said it started, or from a move.
ThreadFolder? threadFolderOf(ChatController chat, ChatThread thread) {
  final path = thread.workingDirectory ?? thread.folderPath;
  if (path == null || path.trim().isEmpty) return null;
  // The same folders the list's section headers are named against.
  final among = folderLabelUniverse(chat.threads);
  final home = chat.workspaceHome;
  return ThreadFolder(
    name: folderLabelFor(path, among: among),
    path: path,
    branch: thread.branch,
    projectName: chat.workspaceProjectNameOf(thread, path),
    home: isRiskyWorkspaceFolder(path, home: home),
  );
}
