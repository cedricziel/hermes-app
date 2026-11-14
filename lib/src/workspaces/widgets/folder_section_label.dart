import 'package:flutter/material.dart';

import '../../files/widgets/server_path_text.dart';
import '../workspace_paths.dart';

/// The label of a chat list section: one line, cut at the end like any other
/// heading, except when the label is a path (two folders with one name are
/// told apart by their paths), which is cut in the middle so the last folder
/// stays, with the full path on a long press.
class FolderSectionLabel extends StatelessWidget {
  const FolderSectionLabel(this.label, {super.key, this.style});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (isServerPath(label)) {
      return PathCutText(label, style: style);
    }
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
