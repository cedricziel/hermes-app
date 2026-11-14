import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/grouped_list.dart';
import '../checkpoint_models.dart';

/// The folder and the name of [path], split at its last slash. The folder is
/// empty for a file at the top of the chat's folder.
(String folder, String name) splitChangedPath(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0
      ? ('', path)
      : (path.substring(0, slash), path.substring(slash + 1));
}

/// [name] with invisible break opportunities after `_` and `-` and before
/// each `.`, so a long name wraps at word boundaries and its extension stays
/// whole on one line. Use it for drawing only: copy, search and the screen
/// reader get the real name.
String breakableFileName(String name) => name.replaceAllMapped(
  RegExp(r'[_-]|\.'),
  (m) => m[0] == '.' ? '\u200B.' : '${m[0]}\u200B',
);

/// The counts of [file] in words, or null when nothing is known: "+48 −112"
/// from its diff section, the `stat` total when there is none, and a note
/// for a file that is not text.
String? changedFileDetails(AppLocalizations l10n, ChangedFile file) {
  if (file.binary) return l10n.chatCheckpointsChangesNotText;
  final added = file.added, removed = file.removed;
  if (added != null && removed != null) {
    return l10n.chatCheckpointsChangesCountsAddedRemoved(added, removed);
  }
  final changes = file.changes;
  return changes == null
      ? null
      : l10n.chatCheckpointsChangesCountsLinesChanged(changes);
}

/// The files that differ from a checkpoint, as rows: the file name as the
/// title, wrapping instead of being cut so the extension stays; under it the
/// folder and the counts. A tap opens the file's changes.
///
/// When [truncated] the server cut its diff short: a file without a diff
/// says so, and a note under the list says the list itself is complete.
/// Takes plain values and callbacks only.
class ChangedFilesList extends StatelessWidget {
  const ChangedFilesList({
    super.key,
    required this.files,
    this.truncated = false,
    this.onOpen,
  });

  final List<ChangedFile> files;
  final bool truncated;
  final ValueChanged<ChangedFile>? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    final open = onOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(metrics.rowPadding, 16, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.chatCheckpointsChangesHeader,
                  style: TextStyle(
                    fontSize: metrics.titleSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                l10n.chatCheckpointsChangesHeaderNote,
                style: TextStyle(fontSize: metrics.subtitleSize, color: muted),
              ),
            ],
          ),
        ),
        GroupedSection(
          footer: truncated ? l10n.chatCheckpointsChangesCutFooter : null,
          children: [
            for (final file in files)
              _FileRow(
                key: ValueKey(file.path),
                file: file,
                truncated: truncated,
                onTap: open == null ? null : () => open(file),
              ),
          ],
        ),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    super.key,
    required this.file,
    required this.truncated,
    required this.onTap,
  });

  final ChangedFile file;
  final bool truncated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (folder, name) = splitChangedPath(file.path);
    final details = changedFileDetails(l10n, file);
    final where = folder.isEmpty
        ? l10n.chatCheckpointsChangesTopOfFolder
        : folder;
    final cut = truncated && file.diff == null && !file.binary;
    final subtitle = [
      details == null
          ? where
          : l10n.chatCheckpointsChangesFileSubtitle(where, details),
      if (cut) l10n.chatCheckpointsChangesCutCaption,
    ].join('\n');
    final spoken = file.binary
        ? details
        : file.added != null && file.removed != null
        ? l10n.chatCheckpointsChangesCountsSemantics(file.added!, file.removed!)
        : details;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: spoken == null
          ? name
          : l10n.chatCheckpointsChangesFileLabel(name, spoken),
      hint: folder.isEmpty ? null : folder,
      value: cut ? l10n.chatCheckpointsChangesCutCaption : null,
      onTap: onTap,
      child: GroupedRow(
        title: breakableFileName(name),
        titleMaxLines: null,
        subtitle: subtitle,
        subtitleMaxLines: null,
        onTap: onTap,
      ),
    );
  }
}
