import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/file_download_progress.dart'
    show announcedReceivedBytes;
import '../../files/widgets/file_size.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../widgets/busy_bar.dart';
import 'session_export_failure.dart';

/// What the export alert shows.
sealed class SessionExportPhase {
  const SessionExportPhase();
}

/// Asks before anything is requested.
final class SessionExportConfirm extends SessionExportPhase {
  const SessionExportConfirm();
}

/// The file is being fetched. [stalled] adds the "Still waiting" line;
/// [receivedBytes] adds the "Downloaded" line once it is above zero.
final class SessionExportProgress extends SessionExportPhase {
  const SessionExportProgress({this.stalled = false, this.receivedBytes = 0});

  final bool stalled;
  final int receivedBytes;
}

/// Nothing was saved, for [kind].
final class SessionExportFailed extends SessionExportPhase {
  const SessionExportFailed(this.kind);

  final SessionExportFailure kind;
}

/// The alert of "Export chat as JSON": one alert that changes in place from
/// the confirmation through the progress to a failure. It holds no title, id
/// or content of the chat, so App Lock has nothing to blank.
///
/// Cancel and Close are the default button but never filled; Try again goes
/// back to the confirmation, so it is [onRetry]'s job to show that, never to
/// request again. While the file is fetched the alert cannot be popped
/// (Escape, back gesture); Cancel is the way out.
class SessionExportAlert extends StatelessWidget {
  const SessionExportAlert({
    super.key,
    required this.phase,
    this.onConfirm,
    this.onCancel,
    this.onRetry,
    this.onClose,
  });

  final SessionExportPhase phase;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final cancel = AppDialogAction(
      isDefault: true,
      filledOnMaterial: false,
      onPressed: onCancel,
      child: Text(material.cancelButtonLabel),
    );
    final (title, content, actions) = switch (phase) {
      SessionExportConfirm() => (
        l10n.chatSessionExportConfirmTitle,
        Text(l10n.chatSessionExportConfirmMessage),
        [
          cancel,
          AppDialogAction(
            onPressed: onConfirm,
            child: Text(l10n.chatSessionExportConfirmButton),
          ),
        ],
      ),
      SessionExportProgress(:final stalled, :final receivedBytes) => (
        l10n.chatSessionExportProgressTitle,
        _Progress(stalled: stalled, receivedBytes: receivedBytes),
        [cancel],
      ),
      SessionExportFailed(:final kind) => (
        _failureTitle(l10n, kind),
        Text(_failureMessage(l10n, kind)),
        [
          AppDialogAction(
            isDefault: true,
            filledOnMaterial: false,
            onPressed: onClose,
            child: Text(material.closeButtonLabel),
          ),
          if (kind.canRetry)
            AppDialogAction(
              onPressed: onRetry,
              child: Text(l10n.chatSessionExportTryAgain),
            ),
        ],
      ),
    };
    return PopScope(
      canPop: phase is! SessionExportProgress,
      child: AppAlertDialog(
        scrollable: true,
        title: Text(title),
        content: content,
        actions: actions,
      ),
    );
  }
}

String _failureTitle(AppLocalizations l10n, SessionExportFailure kind) =>
    switch (kind) {
      SessionExportFailure.gone => l10n.chatSessionExportFailureGoneTitle,
      SessionExportFailure.unsupported =>
        l10n.chatSessionExportFailureUnsupportedTitle,
      SessionExportFailure.profileMissing =>
        l10n.chatSessionExportFailureProfileMissingTitle,
      SessionExportFailure.profileInvalid =>
        l10n.chatSessionExportFailureProfileInvalidTitle,
      SessionExportFailure.unreadable =>
        l10n.chatSessionExportFailureUnreadableTitle,
      SessionExportFailure.lost => l10n.chatSessionExportFailureLostTitle,
      SessionExportFailure.incomplete =>
        l10n.chatSessionExportFailureIncompleteTitle,
      SessionExportFailure.offline => l10n.chatSessionExportFailureOfflineTitle,
      SessionExportFailure.failed => l10n.chatSessionExportFailureFailedTitle,
    };

String _failureMessage(AppLocalizations l10n, SessionExportFailure kind) =>
    switch (kind) {
      SessionExportFailure.gone => l10n.chatSessionExportFailureGoneMessage,
      SessionExportFailure.unsupported =>
        l10n.chatSessionExportFailureUnsupportedMessage,
      SessionExportFailure.profileMissing =>
        l10n.chatSessionExportFailureProfileMissingMessage,
      SessionExportFailure.profileInvalid =>
        l10n.chatSessionExportFailureProfileInvalidMessage,
      SessionExportFailure.unreadable =>
        l10n.chatSessionExportFailureUnreadableMessage,
      SessionExportFailure.lost => l10n.chatSessionExportFailureLostMessage,
      SessionExportFailure.incomplete =>
        l10n.chatSessionExportFailureIncompleteMessage,
      SessionExportFailure.offline =>
        l10n.chatSessionExportFailureOfflineMessage,
      SessionExportFailure.failed => l10n.chatSessionExportFailureFailedMessage,
    };

/// The progress phase's body: the message, the bar (size unknown, so never a
/// percentage), the bytes so far and, after a silence, the stalled line.
class _Progress extends StatelessWidget {
  const _Progress({required this.stalled, required this.receivedBytes});

  final bool stalled;
  final int receivedBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.chatSessionExportProgressMessage),
        const SizedBox(height: 12),
        const BusyBar(minHeight: 6),
        if (receivedBytes > 0) ...[
          const SizedBox(height: 12),
          // Announced in coarse steps, not on every chunk.
          Semantics(
            container: true,
            liveRegion: true,
            label: l10n.filesDownloadDownloaded(
              formatByteSize(l10n, announcedReceivedBytes(receivedBytes)),
            ),
            excludeSemantics: true,
            child: Text(
              l10n.filesDownloadDownloaded(formatByteSize(l10n, receivedBytes)),
            ),
          ),
        ],
        if (stalled) ...[
          const SizedBox(height: 12),
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(l10n.chatSessionExportStalled),
          ),
        ],
      ],
    );
  }
}
