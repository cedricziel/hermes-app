import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/busy_bar.dart';
import 'file_size.dart';
import 'files_metrics.dart';
import 'files_spinner.dart';

/// What a screen reader is told of a download of [total] bytes of which
/// [received] arrived: the figure rounded down to a tenth of the whole, so the
/// live region speaks about ten times in a download, not on every chunk.
int announcedProgressBytes(int received, int total) {
  if (total <= 0) return 0;
  final tenths = (received.clamp(0, total) * 10 ~/ total);
  return total * tenths ~/ 10;
}

/// The same for a download of unknown length: whole megabytes up to 10 MB,
/// then steps of 10 MB.
int announcedReceivedBytes(int received) {
  const mb = 1024 * 1024;
  if (received < mb) return 0;
  final step = received < 10 * mb ? mb : 10 * mb;
  return received ~/ step * step;
}

/// A download under way. With a length it is a [BusyBar] with a value and
/// "Downloading… 14 of 30 MB"; without one a spinner and "Downloaded 12 MB".
/// Both end in a text Cancel. The status is a live region, so a screen reader
/// announces the progress, and under reduced motion nothing animates.
class FileDownloadProgress extends StatelessWidget {
  const FileDownloadProgress({
    super.key,
    required this.received,
    this.total,
    required this.onCancel,
  });

  final int received;

  /// The file's length; null when the server sent none.
  final int? total;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final files = FilesMetrics.of(context);
    final total = this.total;
    final known = total != null && total > 0;
    final label = known
        ? formatDownloadProgress(l10n, received, total)
        : l10n.filesDownloadDownloaded(formatByteSize(l10n, received));
    // The line changes with every chunk; a screen reader gets it only when
    // the figure moves a coarse step, so it is not read out all the time.
    final announced = known
        ? formatDownloadProgress(
            l10n,
            announcedProgressBytes(received, total),
            total,
          )
        : l10n.filesDownloadDownloaded(
            formatByteSize(l10n, announcedReceivedBytes(received)),
          );
    final cancel = TextButton(
      onPressed: onCancel,
      style: files.buttonStyle(),
      child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
    );
    final text = Semantics(
      container: true,
      liveRegion: true,
      label: announced,
      excludeSemantics: true,
      child: Text(label, textAlign: TextAlign.center),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (known)
                BusyBar(
                  value: (received / total).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                )
              else
                const FilesSpinner(size: 28),
              const SizedBox(height: 12),
              text,
              const SizedBox(height: 8),
              cancel,
            ],
          ),
        ),
      ),
    );
  }
}
