import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../theme/platform_chrome.dart';
import '../../../widgets/adaptive_popup_menu_button.dart';
import '../../../widgets/grouped_list.dart';
import '../../../widgets/named_popup_menu_button.dart';
import '../checkpoint_models.dart';
import '../checkpoints_state.dart';
import 'restore_refusal_text.dart';

/// The sentence for why a checkpoint was taken. Never the server's own text,
/// which can hold a command or a file name.
String checkpointReasonTitle(AppLocalizations l10n, CheckpointReason reason) =>
    switch (reason) {
      CheckpointReason.beforeEdit => l10n.chatCheckpointsRowBeforeEdit,
      CheckpointReason.beforeTerminal => l10n.chatCheckpointsRowBeforeTerminal,
      CheckpointReason.beforeRestore => l10n.chatCheckpointsRowBeforeRestore,
      CheckpointReason.other => l10n.chatCheckpointsRowOther,
    };

enum _RowAction { seeChanges, restoreAll }

/// One checkpoint: the reason as the title, the time under it, a "…" menu
/// with "See changes" and "Restore all files…". A tap opens the changes; a
/// right-click opens the menu where there is a pointer.
///
/// [timeLabel] is the relative time ("12 min ago") and [timeSemanticsLabel]
/// the exact one for a screen reader; both null read "Unknown time". A
/// [restoreRefusal] disables the restore item and says why in the menu.
/// Takes plain values only.
class CheckpointRow extends StatefulWidget {
  const CheckpointRow({
    super.key,
    required this.reason,
    this.timeLabel,
    this.timeSemanticsLabel,
    this.restoreRefusal,
    this.onSeeChanges,
    this.onRestoreAll,
    this.menuController,
  });

  final CheckpointReason reason;
  final String? timeLabel;
  final String? timeSemanticsLabel;

  /// Why "Restore all files…" is disabled; null when it may start.
  final RestoreRefusal? restoreRefusal;
  final VoidCallback? onSeeChanges;
  final VoidCallback? onRestoreAll;

  /// Opens the menu from outside, as a catalog entry does.
  final AdaptiveMenuController? menuController;

  @override
  State<CheckpointRow> createState() => _CheckpointRowState();
}

class _CheckpointRowState extends State<CheckpointRow> {
  final _own = AdaptiveMenuController();

  AdaptiveMenuController get _menu => widget.menuController ?? _own;

  void _select(_RowAction action) => switch (action) {
    _RowAction.seeChanges => widget.onSeeChanges?.call(),
    _RowAction.restoreAll => widget.onRestoreAll?.call(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final target = switch (platformChromeOf(context)) {
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28.0,
      PlatformChrome.material => 48.0,
    };
    final time = widget.timeLabel ?? l10n.chatCheckpointsRowUnknownTime;
    final exact = widget.timeSemanticsLabel ?? time;
    final refusal = widget.restoreRefusal;
    final restoreEnabled = refusal == null && widget.onRestoreAll != null;
    final menu = SizedBox.square(
      dimension: target,
      child: NamedPopupMenuButton<_RowAction>(
        controller: _menu,
        label: l10n.chatCheckpointsRowMenuLabel(time),
        tooltip: l10n.chatCheckpointsRowMenuLabel(time),
        icon: AppIcons.more,
        color: subtle,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: Size.square(target),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onSelected: _select,
        itemBuilder: (context) => [
          PopupMenuItem<_RowAction>(
            value: _RowAction.seeChanges,
            child: Text(l10n.chatCheckpointsRowSeeChanges),
          ),
          AdaptiveMenuItem<_RowAction>(
            value: _RowAction.restoreAll,
            enabled: restoreEnabled,
            destructive: true,
            macHeight: refusal == null ? null : 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.chatCheckpointsRowRestoreAll),
                if (refusal != null)
                  Text(
                    restoreRefusalText(l10n, refusal),
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) => _menu.open(at: details.globalPosition),
      child: Semantics(
        hint: exact,
        child: GroupedRow(
          title: checkpointReasonTitle(l10n, widget.reason),
          titleMaxLines: null,
          subtitle: time,
          subtitleMaxLines: null,
          onTap: widget.onSeeChanges,
          separateTrailing: true,
          trailing: menu,
        ),
      ),
    );
  }
}
