import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../settings/report_bug_link.dart' show LinkOpener;
import 'file_details_view.dart';
import 'file_download_progress.dart';
import 'files_browser_view.dart' show FilesNoSelection;
import 'files_failures.dart';
import 'files_metrics.dart';
import 'files_spinner.dart';
import 'file_previews.dart';

/// What a details view's button does. The screen decides which a file gets
/// and what each calls.
enum FilesDetailsActionKind { open, save, share, openWith }

/// What the preview area of the Files page shows. The screen maps its
/// controller's state onto one of these.
sealed class FilesPreviewModel {
  const FilesPreviewModel();
}

/// Nothing is selected.
class FilesPreviewEmpty extends FilesPreviewModel {
  const FilesPreviewEmpty();
}

/// A read or a download is running. [received] is null for a read, which has
/// no progress; with it the download's bytes so far, of [total] when known.
class FilesPreviewLoading extends FilesPreviewModel {
  const FilesPreviewLoading({this.received, this.total});

  final int? received;
  final int? total;
}

/// A file shown inline: text, code, Markdown or an image.
class FilesPreviewShown extends FilesPreviewModel {
  const FilesPreviewShown(this.content);

  final FilePreviewContent content;
}

/// A file with no inline preview (a PDF or any other file, a file too large
/// for text, a download the user cancelled). [primary] is filled, [secondary]
/// outlined.
class FilesPreviewDetails extends FilesPreviewModel {
  const FilesPreviewDetails({
    required this.name,
    this.size,
    this.tooLarge = false,
    required this.primary,
    this.secondary = const [],
  });

  final String name;
  final int? size;

  /// `read-text` answered 413: "This file is too large to open here."
  final bool tooLarge;
  final FilesDetailsActionKind primary;
  final List<FilesDetailsActionKind> secondary;
}

/// A file that cannot be shown.
class FilesPreviewFailed extends FilesPreviewModel {
  const FilesPreviewFailed(this.problem);

  final FileProblem problem;
}

/// What the preview area's buttons call.
class FilesPreviewCallbacks {
  const FilesPreviewCallbacks({
    this.onOpen,
    this.onSave,
    this.onShare,
    this.onOpenWith,
    this.onTryAgain,
    this.onCancelDownload,
    this.onDownloadFull,
  });

  final VoidCallback? onOpen;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onOpenWith;
  final VoidCallback? onTryAgain;
  final VoidCallback? onCancelDownload;
  final VoidCallback? onDownloadFull;

  VoidCallback? forKind(FilesDetailsActionKind kind) => switch (kind) {
    FilesDetailsActionKind.open => onOpen,
    FilesDetailsActionKind.save => onSave,
    FilesDetailsActionKind.share => onShare,
    FilesDetailsActionKind.openWith => onOpenWith,
  };
}

/// The preview area of the Files page, in every state: nothing selected, a
/// read or download under way, the file itself, its details, or why it
/// cannot be shown. A Markdown file gets its Rendered / Source switch above
/// it. It holds no controller; [FilesPreviewModel] and [callbacks] say all.
class FilesPreviewBody extends StatefulWidget {
  const FilesPreviewBody({
    super.key,
    required this.model,
    this.callbacks = const FilesPreviewCallbacks(),
    this.openLink,
    this.confirmLink,
  });

  final FilesPreviewModel model;
  final FilesPreviewCallbacks callbacks;
  final LinkOpener? openLink;
  final Future<bool> Function(BuildContext context, String host)? confirmLink;

  @override
  State<FilesPreviewBody> createState() => _FilesPreviewBodyState();
}

class _FilesPreviewBodyState extends State<FilesPreviewBody> {
  var _source = false;

  @override
  void didUpdateWidget(FilesPreviewBody old) {
    super.didUpdateWidget(old);
    // A different file starts on its rendered view.
    if (!identical(old.model, widget.model) &&
        old.model is FilesPreviewShown &&
        widget.model is! FilesPreviewShown) {
      _source = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final callbacks = widget.callbacks;
    return switch (widget.model) {
      FilesPreviewEmpty() => const FilesNoSelection(),
      FilesPreviewLoading(:final received, :final total) =>
        received == null
            ? const _Reading()
            : FileDownloadProgress(
                received: received,
                total: total,
                onCancel: callbacks.onCancelDownload ?? () {},
              ),
      FilesPreviewShown(:final content) => _shown(content),
      FilesPreviewDetails() => _details(
        context,
        widget.model as FilesPreviewDetails,
      ),
      FilesPreviewFailed(:final problem) => FilePreviewFailure(
        problem: problem,
        onTryAgain: callbacks.onTryAgain,
      ),
    };
  }

  Widget _shown(FilePreviewContent content) {
    final callbacks = widget.callbacks;
    if (content is MarkdownContent) {
      return Column(
        children: [
          MarkdownModeControl(
            showSource: _source,
            onChanged: (value) => setState(() => _source = value),
          ),
          Expanded(
            child: FilePreviewView(
              content: MarkdownContent(
                content.text,
                showSource: _source,
                truncation: content.truncation,
              ),
              onDownloadFull: callbacks.onDownloadFull,
              openLink: widget.openLink,
              confirmLink: widget.confirmLink,
            ),
          ),
        ],
      );
    }
    return FilePreviewView(
      content: content,
      onDownloadFull: callbacks.onDownloadFull,
      openLink: widget.openLink,
      confirmLink: widget.confirmLink,
    );
  }

  Widget _details(BuildContext context, FilesPreviewDetails details) {
    final l10n = context.l10n;
    String label(FilesDetailsActionKind kind) => switch (kind) {
      FilesDetailsActionKind.open => l10n.filesActionOpen,
      FilesDetailsActionKind.save => l10n.filesActionSave,
      FilesDetailsActionKind.share => l10n.filesActionShare,
      FilesDetailsActionKind.openWith => l10n.filesActionOpenWith,
    };
    FileDetailsAction action(FilesDetailsActionKind kind) => FileDetailsAction(
      label: label(kind),
      onPressed: widget.callbacks.forKind(kind),
    );
    return FileDetailsView(
      name: details.name,
      size: details.size,
      note: details.tooLarge ? l10n.filesDetailsTooLarge : null,
      primary: action(details.primary),
      secondary: [for (final kind in details.secondary) action(kind)],
    );
  }
}

/// A text file's read: a spinner under no words, as the read has no progress.
class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) {
    final metrics = FilesMetrics.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.filesPreviewLoading,
      child: Center(child: FilesSpinner(size: metrics.pointer ? 20 : 28)),
    );
  }
}
