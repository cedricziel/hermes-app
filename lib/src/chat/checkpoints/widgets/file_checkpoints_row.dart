import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../checkpoints_state.dart';

/// The File checkpoints row of the Activity panel's This session section:
/// "File checkpoints · 3" with "Restore files Hermes changed" under it, and a
/// chevron that opens the checkpoint page. It is laid out like the Context
/// row above it, so the two read as one list.
///
/// The other states: a stored chat whose list was not read ("Not checked
/// yet"), loading (a spinner in the chevron's place), off on the server with
/// edits in the chat ("See how to turn them on"), and a failed read (an error
/// line with its icon). While [locked] (App Lock) only the count is drawn and
/// the row does not open. [CheckpointsRowState.hidden] draws nothing. Takes
/// plain values and callbacks only.
class FileCheckpointsRow extends StatelessWidget {
  const FileCheckpointsRow({
    super.key,
    required this.state,
    this.count,
    this.locked = false,
    this.onOpen,
  });

  final CheckpointsRowState state;

  /// How many checkpoints the list holds, for [CheckpointsRowState.count] and
  /// App Lock.
  final int? count;
  final bool locked;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state == CheckpointsRowState.hidden) return const SizedBox.shrink();
    final count = this.count;
    final (String title, String? subtitle) = locked
        ? (
            count == null
                ? l10n.chatCheckpointsPageTitle
                : l10n.chatCheckpointsListLocked(count),
            null,
          )
        : switch (state) {
            CheckpointsRowState.count => (
              count == null
                  ? l10n.chatCheckpointsPageTitle
                  : l10n.chatCheckpointsPageRowCount(count),
              l10n.chatCheckpointsPageRowSubtitle,
            ),
            CheckpointsRowState.notChecked => (
              l10n.chatCheckpointsPageTitle,
              l10n.chatCheckpointsPageRowNotChecked,
            ),
            CheckpointsRowState.loading => (
              l10n.chatCheckpointsPageTitle,
              l10n.chatCheckpointsListLoading,
            ),
            CheckpointsRowState.off => (
              l10n.chatCheckpointsPageRowOff,
              l10n.chatCheckpointsPageRowOffHint,
            ),
            CheckpointsRowState.failed ||
            CheckpointsRowState.hidden => (l10n.chatCheckpointsPageTitle, null),
          };
    final error = !locked && state == CheckpointsRowState.failed
        ? l10n.chatCheckpointsPageRowFailed
        : null;
    final loading = !locked && state == CheckpointsRowState.loading;
    final openable = onOpen != null && !locked;
    final subtle = context.hermesColors.subtleText;
    final errorColor = Theme.of(context).colorScheme.error;
    final trailing = loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : openable
        ? AppIcon(AppIcons.chevronRight, size: 20, color: subtle)
        : null;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: subtle),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: AppIcon(
                            AppIcons.error,
                            size: MediaQuery.textScalerOf(context).scale(14),
                            color: errorColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            error,
                            style: TextStyle(fontSize: 13, color: errorColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ],
        ),
      ),
    );
    return Semantics(
      key: const Key('file-checkpoints-row'),
      container: true,
      button: openable,
      label: [title, ?subtitle, ?error].join('. '),
      onTap: openable ? onOpen : null,
      child: ExcludeSemantics(
        child: openable ? InkWell(onTap: onOpen, child: body) : body,
      ),
    );
  }
}
