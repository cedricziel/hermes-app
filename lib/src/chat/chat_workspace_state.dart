import '../workspaces/workspace_catalog_loader.dart';
import '../workspaces/workspace_models.dart';

/// Hermes started a new chat in a folder other than the one picked. The
/// screen words it once, with the folders, and offers to choose another. Held
/// in memory only.
class WorkspaceMismatch {
  const WorkspaceMismatch({
    required this.picked,
    required this.reported,
    this.profileMayUseOwnFolder = false,
  });

  /// The folder the user picked.
  final String picked;

  /// The folder Hermes reports.
  final String reported;

  /// Whether the create was retried without `cwd_explicit`, so the profile
  /// may have used a folder of its own. The notice names that cause only
  /// then.
  final bool profileMayUseOwnFolder;
}

/// Where a move of a chat's folder stands. Every phase says what is known,
/// never what was expected: the folder comes from the server's answer or from
/// reading the chat again.
enum WorkspaceMovePhase {
  idle,

  /// The move is sent and has no answer yet.
  moving,

  /// The answer was lost or was a server error, and the chat is being read
  /// again. Nothing is sent again.
  checking,

  /// The server's answer or the chat's row names the new folder.
  changed,

  /// The chat's row still names the old folder.
  unchanged,

  /// The chat could not be read again within 10 s. The move was sent once;
  /// "check again" reads the chat only.
  couldNotConfirm,

  /// The server refused: the folder does not exist (`4017`). Nothing changed.
  folderMissing,

  /// The chat does not exist on the server (`4007`). Nothing changed.
  chatGone,

  /// The chat's profile does not exist on the server (`4064`). Nothing
  /// changed.
  profileGone,
}

class WorkspaceMoveState {
  const WorkspaceMoveState(this.phase, {this.folder});

  static const idle = WorkspaceMoveState(WorkspaceMovePhase.idle);

  final WorkspaceMovePhase phase;

  /// The folder the server reported, for [WorkspaceMovePhase.changed].
  final String? folder;

  /// Whether the chat must not be sent to: Hermes lets a live agent follow a
  /// move, even mid-turn.
  bool get inFlight =>
      phase == WorkspaceMovePhase.moving ||
      phase == WorkspaceMovePhase.checking;
}

/// Why nothing was sent for a move, or why the action is not offered.
enum WorkspaceMoveBlock {
  /// The server has no `session.workspace.move`: hide the action.
  unsupported,

  /// A Bot Chat registry chat.
  botChat,

  /// Not a stored chat of the profile in view: a draft, or a chat of another
  /// profile that is not open.
  notAvailable,

  /// A reply is running or arriving. Also what a confirmation that was
  /// answered after a reply started gets.
  replying,

  /// An earlier move of this chat is still being settled.
  moving,

  /// The path is neither absolute nor `~`-led. Nothing was sent.
  notAServerPath,
}

/// What the row above a new chat's composer shows, without any wording.
class NewChatWorkspace {
  const NewChatWorkspace({
    required this.status,
    this.choice,
    this.folder,
    this.projectName,
    this.branch,
    this.stalled = false,
  });

  /// The state of the profile's catalog read.
  final WorkspaceCatalogStatus status;

  /// The folder picked, when one was.
  final WorkspaceChoice? choice;

  /// The folder the chat will run in: the pick, else the profile's default
  /// when known.
  final String? folder;
  final String? projectName;
  final String? branch;

  /// Whether the default is still being looked up and has had no answer for
  /// 10 s: the row then says the server's default folder, without a path.
  final bool stalled;

  /// No pick; [folder] is the server's default.
  bool get isServerDefault => choice == null;

  /// The default is being looked up and the row has nothing to show yet.
  bool get lookingUp =>
      folder == null && status == WorkspaceCatalogStatus.loading && !stalled;

  /// The row has nothing to say: an older server and no folder known.
  bool get hidden =>
      folder == null && status == WorkspaceCatalogStatus.unsupported;
}
