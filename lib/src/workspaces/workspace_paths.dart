import '../files/server_path.dart';
import 'workspace_models.dart';

/// Whether [text] can name a folder for a chat: an absolute POSIX, Windows
/// drive or UNC path, or one that starts with `~`. A relative path is never
/// accepted, since Hermes would resolve it against its own directory and the
/// result could not be compared with what was asked for.
bool isServerPath(String text) =>
    ServerPath.tryParse(text) != null || text.startsWith('~');

/// [path] with a leading `~` replaced by [home] when there is one, and with
/// trailing separators and doubled ones removed. A path that is still
/// `~`-led afterwards is returned as `~` or `~/rest`.
String _tidy(String path, String? home) {
  var text = path.trim();
  if (home != null && home.isNotEmpty) {
    if (text == '~') {
      text = home;
    } else if (text.startsWith('~/')) {
      text = '${home.replaceFirst(RegExp(r'/+$'), '')}/${text.substring(2)}';
    }
  }
  text = text.replaceAll(RegExp(r'/{2,}'), '/');
  if (text.length > 1) text = text.replaceFirst(RegExp(r'/+$'), '');
  return text;
}

/// Whether [a] and [b] are the same server folder, for the notice that says
/// Hermes started somewhere other than where it was asked. Trailing and
/// doubled separators do not count, and a leading `~` is read as [home]. A
/// `~`-led path with no [home] to expand it is equal only to the same text.
bool sameServerFolder(String a, String b, {String? home}) {
  final left = _tidy(a, home);
  final right = _tidy(b, home);
  if (left == right) return true;
  final parsedLeft = ServerPath.tryParse(left);
  final parsedRight = ServerPath.tryParse(right);
  if (parsedLeft == null || parsedRight == null) return false;
  return parsedLeft.isWithin(parsedRight) && parsedRight.isWithin(parsedLeft);
}

/// Whether Hermes started in a folder other than the [picked] one. False when
/// either path still starts with `~` after [home] is applied, since a remote
/// profile's `~` is not the dashboard host's and the two cannot be compared.
bool folderMismatch(String picked, String reported, {String? home}) {
  if (_tidy(picked, home).startsWith('~') ||
      _tidy(reported, home).startsWith('~')) {
    return false;
  }
  return !sameServerFolder(picked, reported, home: home);
}

/// Which project a folder belongs to, by the server's own rule.
abstract final class WorkspaceProjects {
  /// The non-archived project with a folder that equals [path] or is an
  /// ancestor of it, whole segments compared, the longest folder winning
  /// (`project_for_path`). Null when none does, or when [path] is not an
  /// absolute path.
  static WorkspaceProject? projectFor(
    String path,
    Iterable<WorkspaceProject> projects,
  ) {
    final target = ServerPath.tryParse(_tidy(path, null));
    if (target == null) return null;
    WorkspaceProject? best;
    var bestDepth = -1;
    for (final project in projects) {
      if (project.archived) continue;
      for (final folder in project.folders) {
        final root = ServerPath.tryParse(_tidy(folder.path, null));
        if (root == null || !target.isWithin(root)) continue;
        if (root.segments.length > bestDepth) {
          best = project;
          bestDepth = root.segments.length;
        }
      }
    }
    return best;
  }
}

/// Whether [path] is the server's home folder or `/`: a folder that holds
/// many projects, which the row and the details say a word about.
bool isRiskyWorkspaceFolder(String path, {String? home}) {
  final text = _tidy(path, home);
  if (text == '/') return true;
  return home != null &&
      home.isNotEmpty &&
      sameServerFolder(path, home, home: home);
}
