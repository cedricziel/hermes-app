import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/app_banner.dart';
import 'file_size.dart';
import 'files_metrics.dart';

/// A text button of a note, at the platform's smallest target. Its label may
/// wrap, so a long translation leaves the note's text its room.
Widget _noteAction(BuildContext context, String label, VoidCallback onPressed) {
  final button = TextButton(
    onPressed: onPressed,
    style: FilesMetrics.of(context).buttonStyle(),
    child: Text(label, textAlign: TextAlign.center),
  );
  // The banner stacks its action under the text from 1.5x; there it needs
  // the full width, not the cap that leaves a translation's text its room.
  return textScaleOf(context) > 1.5
      ? button
      : ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: button,
        );
}

/// "Working folder of the server": above the list of a chat that has not
/// started, so Hermes shows the server's own folder. The shared banner in its
/// neutral tone; Files has no banner of its own.
class FilesServerFolderNote extends StatelessWidget {
  const FilesServerFolderNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBanner(
      tone: AppBannerTone.neutral,
      icon: AppIcons.info,
      title: l10n.filesNoteServerFolderTitle,
      detail: l10n.filesNoteServerFolderDetail,
    );
  }
}

/// "Showing the first 512 KB of 3.2 MB." with Download full file, above a
/// text file the server cut short.
class FilesTruncatedNote extends StatelessWidget {
  const FilesTruncatedNote({
    super.key,
    required this.shownBytes,
    required this.totalBytes,
    required this.onDownloadFull,
  });

  final int shownBytes;
  final int totalBytes;
  final VoidCallback onDownloadFull;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBanner(
      tone: AppBannerTone.neutral,
      title: l10n.filesNoteTruncated(
        formatByteSize(l10n, shownBytes),
        formatByteSize(l10n, totalBytes),
      ),
      action: _noteAction(
        context,
        l10n.filesActionDownloadFull,
        onDownloadFull,
      ),
    );
  }
}

/// A refresh that failed after a listing: the list stays under this warning,
/// so files already downloaded still open.
class FilesOfflineBanner extends StatelessWidget {
  const FilesOfflineBanner({super.key, this.onRetry});

  /// Without it the banner still says the list may be out of date.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBanner(
      tone: AppBannerTone.warning,
      title: l10n.filesProblemUnreachable,
      detail: l10n.filesOfflineDetail,
      action: onRetry == null
          ? null
          : _noteAction(context, l10n.filesActionTryAgain, onRetry!),
    );
  }
}
