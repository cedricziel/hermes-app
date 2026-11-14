import 'widgets/workspace_widget_support.dart' show workspaceFolderName;
import '../files/widgets/safe_path_text.dart';

/// The label of [path] as a folder is named in the chat list's section
/// headers and in an open chat's header line: its last segment, or the whole
/// path when another folder of [among] ends in the same name, so two `app`
/// folders never read alike. One rule for both places, so the same folder is
/// never called two things.
///
/// [among] is every folder in view (the list's folders); [path] itself need
/// not be in it.
String folderLabelFor(String path, {Iterable<String> among = const []}) {
  final name = workspaceFolderName(path);
  for (final other in among) {
    if (other != path && workspaceFolderName(other) == name) {
      return safePathText(path);
    }
  }
  return safePathText(name);
}

/// [folderLabelFor] for each of [paths] at once, keyed by path.
Map<String, String> folderLabels(Iterable<String> paths) {
  final unique = paths.toSet();
  return {for (final path in unique) path: folderLabelFor(path, among: unique)};
}
