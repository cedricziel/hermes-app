import '../chat/thread_sections.dart' show sessionFolderPath;

/// Why a workspaces call failed, with nothing of the request in it: no URL,
/// path, or text from the server. A kind is all a caller may keep or log.
enum WorkspacesFailure {
  /// The folder, or for a move the target folder, is not there. For a move
  /// this is the server's refusal (`4017`), which can still follow a stored
  /// update, so read the chat again if the old folder matters.
  notFound,

  /// The server would not let Hermes read the folder.
  notAllowed,

  /// The path exists but is not a folder.
  notADirectory,

  /// The read is outside the root the server lets this app browse.
  outsideBoundary,

  /// The profile does not exist on the server.
  unknownProfile,

  /// The chat does not exist on the server.
  sessionGone,

  /// No answer: offline, a dropped socket, a timeout. For a move this means
  /// it may have happened; read the chat again rather than send it twice.
  unreachable,

  /// The server answered with an error of its own (`5xxx`: a database it
  /// needs is unavailable, "move failed"). A move that fails this way may
  /// have happened as well, so read the chat again before anything else.
  busy,

  /// The text is not an absolute server path or `~`-led, so nothing was
  /// sent. Not a statement about the server.
  notAServerPath,

  /// Anything else, including an answer that does not fit.
  unknown,
}

/// What a workspaces call came to. Failures are values, never thrown.
sealed class WorkspacesResult<T> {
  const WorkspacesResult();
}

final class WorkspacesOk<T> extends WorkspacesResult<T> {
  const WorkspacesOk(this.value);

  final T value;

  @override
  String toString() => 'WorkspacesOk(${value.runtimeType})';
}

/// The server has no such route or method (an older Hermes).
final class WorkspacesUnsupported<T> extends WorkspacesResult<T> {
  const WorkspacesUnsupported();

  @override
  String toString() => 'WorkspacesUnsupported';
}

final class WorkspacesFailed<T> extends WorkspacesResult<T> {
  const WorkspacesFailed(this.kind);

  final WorkspacesFailure kind;

  @override
  String toString() => 'WorkspacesFailed(${kind.name})';
}

/// One folder of a project.
class WorkspaceFolder {
  const WorkspaceFolder({
    required this.path,
    this.label,
    this.isPrimary = false,
  });

  final String path;
  final String? label;
  final bool isPrimary;
}

/// A named set of folders on the server. `GET /api/chat/workspaces` omits
/// archived projects, but [archived] is kept so
/// `WorkspaceProjects.projectFor` ignores one that slips through.
class WorkspaceProject {
  const WorkspaceProject({
    required this.id,
    required this.name,
    this.slug,
    this.folders = const [],
    this.archived = false,
  });

  final String id;
  final String name;
  final String? slug;
  final List<WorkspaceFolder> folders;
  final bool archived;
}

/// A git root the server saw in the profile's chats or found by a scan.
class WorkspaceRepo {
  const WorkspaceRepo({
    required this.root,
    this.label,
    this.sessions = 0,
    this.lastActive,
  });

  final String root;
  final String? label;

  /// How many chats ran in it.
  final int sessions;

  /// Seconds since the epoch of the latest activity.
  final double? lastActive;
}

class WorkspaceCatalog {
  const WorkspaceCatalog({
    this.projects = const [],
    this.repos = const [],
    this.defaultCwd,
    this.home,
    this.scanEnabled = false,
  });

  final List<WorkspaceProject> projects;
  final List<WorkspaceRepo> repos;

  /// The folder a chat of the profile runs in when none is picked.
  final String? defaultCwd;
  final String? home;
  final bool scanEnabled;
}

class FolderEntry {
  const FolderEntry({required this.name, required this.path});

  final String name;
  final String path;
}

/// The folders of one server directory. Files are not kept.
class FolderListing {
  const FolderListing(this.folders);

  final List<FolderEntry> folders;
}

/// A typed path the server completed to a folder.
class PathSuggestion {
  const PathSuggestion({required this.text, required this.display});

  /// What the field holds once this is taken: the directory that was typed
  /// plus [display], never the server's own `text`.
  final String text;

  /// The folder's name with a trailing `/`.
  final String display;
}

class PathSuggestions {
  const PathSuggestions({required this.folders, required this.capped});

  /// Folders only, in the server's order.
  final List<PathSuggestion> folders;

  /// Whether the server's cap of 30 items was reached, so a folder may be
  /// missing from [folders]. Hermes counts files and folders together.
  final bool capped;
}

/// The answer to `session.workspace.move`.
class MovedWorkspace {
  const MovedWorkspace({required this.cwd, this.branch, this.gitRepoRoot});

  final String cwd;
  final String? branch;
  final String? gitRepoRoot;

  /// The folder the chat is listed under: the git root, else [cwd], written
  /// as the chat list groups it (a trailing separator does not count).
  String get folderPath =>
      sessionFolderPath({'git_repo_root': gitRepoRoot, 'cwd': cwd}) ?? cwd;
}

/// A stored chat's folder fields, from `GET /api/sessions/{id}`.
class SessionFolder {
  const SessionFolder({this.cwd, this.branch, this.gitRepoRoot});

  final String? cwd;
  final String? branch;
  final String? gitRepoRoot;
}

/// Where a picked folder came from. For display only; never sent.
enum WorkspaceChoiceSource { project, recent, browsed, typed }

/// The folder picked for a chat that does not exist yet. It lives on the new
/// thread in memory, goes out as `cwd` on `session.create` and is dropped
/// once the chat exists; it is never stored on the device.
class WorkspaceChoice {
  const WorkspaceChoice({
    required this.path,
    this.projectName,
    this.branch,
    this.source = WorkspaceChoiceSource.typed,
  });

  /// An absolute server path or a `~`-led one, as the server wrote it or the
  /// user typed it.
  final String path;

  /// The project's name and the branch, for the row above the composer.
  final String? projectName;
  final String? branch;
  final WorkspaceChoiceSource source;

  @override
  String toString() => 'WorkspaceChoice(${source.name})';
}

/// The project Hermes resolved for a new session (`info.project`).
class WorkspaceProjectRef {
  const WorkspaceProjectRef({required this.name, this.id, this.primaryPath});

  final String name;
  final String? id;
  final String? primaryPath;
}
