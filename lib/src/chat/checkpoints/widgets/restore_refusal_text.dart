import '../../../../l10n/l10n.dart';
import '../checkpoints_state.dart';

/// The words for why a restore cannot start now, shown beside the disabled
/// control so the reason never depends on colour or a tooltip.
String restoreRefusalText(
  AppLocalizations l10n,
  RestoreRefusal refusal,
) => switch (refusal) {
  RestoreRefusal.unavailable => l10n.chatCheckpointsChangesReasonUnavailable,
  RestoreRefusal.disconnected => l10n.chatCheckpointsChangesReasonDisconnected,
  RestoreRefusal.locked => l10n.chatCheckpointsChangesReasonLocked,
  RestoreRefusal.replying => l10n.chatCheckpointsChangesReasonReplying,
  RestoreRefusal.restoring => l10n.chatCheckpointsChangesReasonRestoring,
  RestoreRefusal.fileNotOffered =>
    l10n.chatCheckpointsChangesReasonFileNotOffered,
};
