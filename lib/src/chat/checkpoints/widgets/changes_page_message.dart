import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/grouped_list.dart';
import '../../../widgets/loading_skeleton.dart';

/// What the Changes page shows when it has no file list.
enum ChangesPageStatus {
  loading,
  unreadable,

  /// Nothing differs from the checkpoint.
  none,

  /// The chat runs in a container workspace.
  refused,
}

/// The body of the Changes page while it has no files to list: a skeleton
/// "Reading the changes…", "Couldn't read the changes." with Try again,
/// "No changes since this checkpoint." or the container refusal.
///
/// [sinceLabel] ("12 min ago") completes the no-changes line. Takes plain
/// values and callbacks only.
class ChangesPageMessage extends StatelessWidget {
  const ChangesPageMessage({
    super.key,
    required this.status,
    this.sinceLabel,
    this.onRetry,
  });

  final ChangesPageStatus status;
  final String? sinceLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = context.hermesColors.subtleText;
    if (status == ChangesPageStatus.loading) {
      return GroupedListView(
        children: [
          GroupedSection(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: LoadingSkeleton(
                  label: l10n.chatCheckpointsChangesLoading,
                  lines: 4,
                ),
              ),
            ],
          ),
        ],
      );
    }
    final since = sinceLabel;
    final (title, detail) = switch (status) {
      ChangesPageStatus.unreadable => (
        l10n.chatCheckpointsChangesUnreadable,
        null,
      ),
      ChangesPageStatus.none => (
        l10n.chatCheckpointsChangesNone,
        since == null ? null : l10n.chatCheckpointsChangesNoneDetail(since),
      ),
      _ => (l10n.chatCheckpointsChangesRefused, null),
    };
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ],
              if (status == ChangesPageStatus.unreadable &&
                  onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onRetry,
                  child: Text(l10n.chatCheckpointsChangesTryAgain),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
