import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/grouped_list.dart';
import '../../../widgets/loading_skeleton.dart';
import '../checkpoint_models.dart';
import '../checkpoints_state.dart';
import 'checkpoint_row.dart';

/// What the checkpoint page body shows.
enum CheckpointListStatus {
  /// The rows, newest first (also while disconnected, list kept).
  loaded,
  empty,

  /// Off on the server.
  off,
  loading,
  failed,

  /// The chat runs in a container workspace.
  notCovered,

  /// App Lock is on: only the count, no rows.
  locked,
}

/// A checkpoint with its time already worded, so the widget never formats a
/// date.
class CheckpointListItem {
  const CheckpointListItem({
    required this.checkpoint,
    this.timeLabel,
    this.timeSemanticsLabel,
  });

  final Checkpoint checkpoint;

  /// "12 min ago"; null reads "Unknown time".
  final String? timeLabel;

  /// The exact time for a screen reader.
  final String? timeSemanticsLabel;
}

/// The body of the "File checkpoints" page: a note about the folder, the
/// checkpoints newest first, or one of the messages for a list that is
/// empty, off, loading, unreadable or not covered. It scrolls on its own
/// and pulls to refresh when [onRefresh] is set.
///
/// While [disconnected] the list stays, marked as not up to date, and every
/// restore is disabled with its reason. Takes plain values and callbacks
/// only.
class CheckpointListBody extends StatelessWidget {
  const CheckpointListBody({
    super.key,
    required this.status,
    this.items = const [],
    this.disconnected = false,
    this.restoreRefusal,
    this.onSeeChanges,
    this.onRestoreAll,
    this.onRetry,
    this.onRefresh,
    this.lockedCount,
  });

  final CheckpointListStatus status;
  final List<CheckpointListItem> items;
  final bool disconnected;

  /// Why a full restore cannot start (a reply is running, another restore
  /// is); a lost connection is [disconnected] instead.
  final RestoreRefusal? restoreRefusal;
  final ValueChanged<String>? onSeeChanges;
  final ValueChanged<String>? onRestoreAll;
  final VoidCallback? onRetry;

  /// Under App Lock only this count shows; the list itself is not passed.
  final int? lockedCount;
  final Future<void> Function()? onRefresh;

  /// The config key shown as a code span in the "off" message.
  static const configKey = 'checkpoints.enabled';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (status) {
      CheckpointListStatus.loaded => _loaded(context),
      CheckpointListStatus.empty => _Block(
        child: Text(l10n.chatCheckpointsListEmpty, textAlign: TextAlign.center),
      ),
      CheckpointListStatus.off => _Block(child: _OffText(l10n: l10n)),
      CheckpointListStatus.loading => GroupedListView(
        children: [
          GroupedSection(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: LoadingSkeleton(
                  label: l10n.chatCheckpointsListLoading,
                  lines: 4,
                ),
              ),
            ],
          ),
        ],
      ),
      CheckpointListStatus.failed => _Block(
        action: onRetry == null
            ? null
            : OutlinedButton(
                onPressed: onRetry,
                child: Text(l10n.chatCheckpointsListRetry),
              ),
        child: Text(
          l10n.chatCheckpointsListFailed,
          textAlign: TextAlign.center,
        ),
      ),
      CheckpointListStatus.notCovered => _Block(
        child: Text(
          l10n.chatCheckpointsListNotCovered,
          textAlign: TextAlign.center,
        ),
      ),
      CheckpointListStatus.locked => _Block(
        child: Text(
          l10n.chatCheckpointsListLocked(lockedCount ?? items.length),
          textAlign: TextAlign.center,
        ),
      ),
    };
  }

  Widget _loaded(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final refusal = disconnected ? RestoreRefusal.disconnected : restoreRefusal;
    final list = GroupedListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (disconnected)
          Padding(
            padding: EdgeInsets.fromLTRB(metrics.rowPadding, 12, 0, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AppIcon(
                    AppIcons.warning,
                    size: metrics.subtitleSize,
                    color: colors.warning,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.chatCheckpointsListStale,
                    style: TextStyle(
                      fontSize: metrics.subtitleSize,
                      color: colors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(metrics.rowPadding, 12, 0, 0),
          child: Text(
            l10n.chatCheckpointsListNote,
            style: TextStyle(
              fontSize: metrics.subtitleSize,
              color: colors.subtleText,
            ),
          ),
        ),
        GroupedSection(
          header: l10n.chatCheckpointsListNewestFirst,
          children: [
            for (final item in items)
              CheckpointRow(
                key: ValueKey(item.checkpoint.hash),
                reason: item.checkpoint.reason,
                timeLabel: item.timeLabel,
                timeSemanticsLabel: item.timeSemanticsLabel,
                restoreRefusal: refusal,
                onSeeChanges: onSeeChanges == null
                    ? null
                    : () => onSeeChanges!(item.checkpoint.hash),
                onRestoreAll: onRestoreAll == null
                    ? null
                    : () => onRestoreAll!(item.checkpoint.hash),
              ),
          ],
        ),
      ],
    );
    final refresh = onRefresh;
    return refresh == null
        ? list
        : RefreshIndicator(onRefresh: refresh, child: list);
  }
}

/// The "off" message with the config key as a selectable code span, no link.
class _OffText extends StatelessWidget {
  const _OffText({required this.l10n});

  final AppLocalizations l10n;

  // A private-use character stands where the code goes, so the sentence
  // stays whole for translators and the code is set apart afterwards.
  static const _marker = '';

  @override
  Widget build(BuildContext context) {
    final sentence = l10n.chatCheckpointsListOff(_marker);
    final at = sentence.indexOf(_marker);
    final base = DefaultTextStyle.of(context).style;
    final code = base.copyWith(
      fontFamily: 'monospace',
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    return SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(text: sentence.substring(0, at)),
          TextSpan(text: CheckpointListBody.configKey, style: code),
          TextSpan(text: sentence.substring(at + _marker.length)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// A centered message with room around it, with an optional action below.
class _Block extends StatelessWidget {
  const _Block({required this.child, this.action});

  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyLarge,
              child: child,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    ),
  );
}
