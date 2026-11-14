import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/destructive_tint_button.dart';
import '../../widgets/tool_call_bodies.dart';
import '../checkpoint_models.dart';
import '../checkpoints_state.dart';
import 'changed_files_list.dart';
import 'restore_refusal_text.dart';

/// Whether git shortened [file]'s name in `stat` ("...ts/token_refresh.dart"),
/// so it cannot be told apart from another file and is never restored alone.
bool isShortenedChangedPath(ChangedFile file) => file.path.startsWith('...');

/// The one-file page: "Changes in token_refresh.dart", how many lines were added and
/// removed, the diff (selectable, each line whole, scrolling sideways), a
/// note when the diff is cut short or the file is not text, and the action
/// to restore just this file.
///
/// The action is [FileRestoreAction], drawn under the diff unless
/// [showAction] is false, for a screen that pins it in a bottom bar.
/// Takes plain values and callbacks only.
class FileDiffView extends StatelessWidget {
  const FileDiffView({
    super.key,
    required this.file,
    this.truncated = false,
    this.restoreRefusal,
    this.restoring = false,
    this.onRestore,
    this.showAction = true,
  });

  final ChangedFile file;

  /// The server cut the diff, so this file's section may end early or be
  /// missing.
  final bool truncated;
  final RestoreRefusal? restoreRefusal;
  final bool restoring;
  final VoidCallback? onRestore;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.hermesColors.subtleText;
    final (_, name) = splitChangedPath(file.path);
    final diff = file.diff;
    final added = file.added, removed = file.removed;
    final String? note;
    if (file.binary) {
      note = l10n.chatCheckpointsFileBinary;
    } else if (diff == null || diff.trim().isEmpty) {
      note = truncated
          ? l10n.chatCheckpointsFileCut
          : l10n.chatCheckpointsFileNoPreview;
    } else {
      note = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.chatCheckpointsFileHeading(name),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!file.binary && added != null && removed != null)
                Text(
                  l10n.chatCheckpointsFileCounts(added, removed),
                  style: TextStyle(fontSize: 14, color: muted),
                ),
            ],
          ),
        ),
        if (diff != null && diff.trim().isNotEmpty && !file.binary)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ToolDiffBody(diff: diff, framed: false),
          ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(note, style: TextStyle(color: muted)),
          ),
        if (showAction)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FileRestoreAction(
              file: file,
              refusal: restoreRefusal,
              restoring: restoring,
              onRestore: onRestore,
            ),
          ),
      ],
    );
  }
}

/// "Restore this file…" as a red outlined button, or the line that says why
/// this file cannot be restored on its own: a name that cannot be sent
/// safely, or one git shortened. Pin it in a bottom bar or draw it under the
/// diff.
class FileRestoreAction extends StatelessWidget {
  const FileRestoreAction({
    super.key,
    required this.file,
    this.refusal,
    this.restoring = false,
    this.onRestore,
  });

  final ChangedFile file;
  final RestoreRefusal? refusal;
  final bool restoring;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.hermesColors.subtleText;
    if (!file.restorable) {
      return Text(
        isShortenedChangedPath(file)
            ? l10n.chatCheckpointsFileNameShortened
            : l10n.chatCheckpointsFileNameNotAlone,
        style: TextStyle(color: muted),
      );
    }
    final refusal = this.refusal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DestructiveTintButton(
          label: restoring
              ? l10n.chatCheckpointsFileRestoring
              : l10n.chatCheckpointsFileRestore,
          busy: restoring,
          onPressed: refusal == null ? onRestore : null,
        ),
        if (refusal != null && !restoring)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              restoreRefusalText(l10n, refusal),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ),
      ],
    );
  }
}
