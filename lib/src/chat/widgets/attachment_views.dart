import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/named_icon_button.dart';
import '../attachments/attachment_file_actions.dart';
import '../chat_models.dart';
import '../media/media_source.dart';
import '../media/media_store.dart';
import '../media/quick_look_telemetry.dart';
import 'image_viewer.dart';
import 'quick_look_target.dart';

/// A size for people: bytes below 1 KB, whole kilobytes below 1 MB, then
/// megabytes with one decimal.
String formatFileSize(int bytes) {
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${(bytes / kb).round()} KB';
  final value = (bytes / mb).toStringAsFixed(1);
  return '${value.endsWith('.0') ? value.substring(0, value.length - 2) : value} MB';
}

const double _thumbnailSize = 240;

/// What the card of a file that could not be fetched says.
String mediaFailureMessage(MediaFailure failure) => switch (failure) {
  MediaFailure.missing => 'This file is no longer available.',
  MediaFailure.refused => "This file can't be opened from here.",
  MediaFailure.tooLarge => 'This file is too large to download.',
  MediaFailure.failed => 'Could not download the file. Tap to try again.',
};

/// An image attachment as a thumbnail: from the file the user picked, the
/// data the history embedded, or the server, which it is fetched from with
/// the user's session. Tapping it opens it full screen. When the picture
/// cannot be drawn it shows as the card of a file.
class AttachmentThumbnail extends StatefulWidget {
  const AttachmentThumbnail({super.key, required this.attachment});

  final ChatAttachment attachment;

  @override
  State<AttachmentThumbnail> createState() => _AttachmentThumbnailState();
}

class _AttachmentThumbnailState extends State<AttachmentThumbnail>
    with AttachmentFileActions<AttachmentThumbnail> {
  Uint8List? _fetched;
  MediaFailure? _failure;
  var _loading = false;

  ChatAttachment get _attachment => widget.attachment;

  @override
  ChatAttachment get attachment => _attachment;

  @override
  void failedToFetch(MediaFailure reason) =>
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(mediaFailureMessage(reason))));

  /// The path to fetch from the server, when nothing on this device shows it.
  String? get _remotePath =>
      _attachment.bytes == null && _attachment.path == null
      ? _attachment.fetchPath
      : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AttachmentThumbnail old) {
    super.didUpdateWidget(old);
    if (old.attachment.fetchPath != _attachment.fetchPath) {
      _fetched = null;
      _failure = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = _remotePath;
    final store = context.read<MediaStore?>();
    if (path == null || store == null) return;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final bytes = await store.image(path);
      if (!mounted || path != _remotePath) return;
      setState(() {
        _fetched = bytes;
        _loading = false;
      });
    } on MediaFetchException catch (e) {
      if (!mounted || path != _remotePath) return;
      setState(() {
        _failure = e.reason;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = AttachmentCard(attachment: _attachment);
    if (_loading) return const _ThumbnailPlaceholder();
    final failure = _failure;
    if (failure != null) {
      return _CardFrame(
        attachment: _attachment,
        notice: mediaFailureMessage(failure),
        noticeIsError: true,
        onTap: failure == MediaFailure.failed ? _load : null,
      );
    }
    final bytes = _attachment.bytes ?? _fetched;
    final path = _attachment.path;
    final ImageProvider? provider = bytes != null
        ? MemoryImage(bytes)
        : path != null
        ? FileImage(File(path))
        : null;
    if (provider == null) return card;
    final macTarget = quickLookTargetsAt(context);
    final available = attachmentHasFile(
      _attachment,
      context.read<MediaStore?>(),
    );
    return QuickLookTarget(
      borderRadius: BorderRadius.circular(kHermesRadius),
      onOpen: () => _open(provider, bytes),
      onToggle: available
          ? () => useFile(
              (store, file) => showInQuickLook(
                store,
                file,
                trigger: QuickLookTrigger.key,
                toggle: true,
              ),
              preview: QuickLookTrigger.key,
            )
          : null,
      onShow: available
          ? () => useFile(
              (store, file) => showInQuickLook(
                store,
                file,
                trigger: QuickLookTrigger.menu,
                toggle: false,
              ),
              preview: QuickLookTrigger.menu,
            )
          : null,
      onSave: available ? () => useFile(saveToDevice) : null,
      child: GestureDetector(
        // On a Mac a click selects; opening is the double-click.
        onTap: macTarget ? null : () => _open(provider, bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kHermesRadius),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _thumbnailSize,
                  maxHeight: _thumbnailSize,
                ),
                child: Image(
                  // A photo can weigh 25 MB; decode it at the size it is shown.
                  image: ResizeImage.resizeIfNeeded(
                    (_thumbnailSize * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    null,
                    provider,
                  ),
                  semanticLabel: _attachment.name,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => card,
                ),
              ),
              if (busy)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(ImageProvider image, Uint8List? bytes) {
    final store = context.read<MediaStore?>();
    final path = _attachment.path;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ImageViewerPage(
          image: image,
          name: _attachment.name,
          onSave: store == null
              ? null
              : () async => store.save(
                  _attachment.name,
                  bytes ?? await File(path!).readAsBytes(),
                ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    width: _thumbnailSize,
    height: _thumbnailSize * 2 / 3,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(kHermesRadius),
    ),
    child: const SizedBox.square(
      dimension: 24,
      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
    ),
  );
}

/// A file attachment as a card with its name and, when known, its size. When
/// the file is on the server at an absolute path, tapping the card downloads
/// it and opens it in the system's app for its type, and the card offers to
/// save it. On macOS the card is selected by a click, opened by a
/// double-click and previewed with Space (see [QuickLookTarget]).
class AttachmentCard extends StatefulWidget {
  const AttachmentCard({super.key, required this.attachment});

  final ChatAttachment attachment;

  @override
  State<AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<AttachmentCard>
    with AttachmentFileActions<AttachmentCard> {
  MediaFailure? _failure;

  @override
  ChatAttachment get attachment => widget.attachment;

  @override
  void failedToFetch(MediaFailure reason) => setState(() => _failure = reason);

  @override
  void clearFetchFailure() => _failure = null;

  @override
  Widget build(BuildContext context) {
    final store = context.read<MediaStore?>();
    final downloadable = attachment.fetchPath != null && store != null;
    // On a Mac any file the chat can make is Finder-like: it can be
    // previewed, opened and saved; elsewhere only a server file can.
    final macTarget = quickLookTargetsAt(context);
    final available = attachmentHasFile(attachment, store);
    final failure = _failure;
    return QuickLookTarget(
      borderRadius: BorderRadius.circular(kHermesRadius),
      onOpen: available ? () => useFile(openWithSystem) : null,
      onToggle: available
          ? () => useFile(
              (store, file) => showInQuickLook(
                store,
                file,
                trigger: QuickLookTrigger.key,
                toggle: true,
              ),
              preview: QuickLookTrigger.key,
            )
          : null,
      onShow: available
          ? () => useFile(
              (store, file) => showInQuickLook(
                store,
                file,
                trigger: QuickLookTrigger.menu,
                toggle: false,
              ),
              preview: QuickLookTrigger.menu,
            )
          : null,
      onSave: available ? () => useFile(saveToDevice) : null,
      child: _CardFrame(
        attachment: attachment,
        notice: busy
            ? 'Downloading…'
            : failure == null
            ? null
            : mediaFailureMessage(failure),
        noticeIsError: !busy && failure != null,
        // On a Mac a click selects; opening is the double-click.
        onTap: !macTarget && downloadable && !busy
            ? () => useFile(openWithSystem)
            : null,
        trailing: !downloadable
            ? null
            : busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : NamedIconButton(
                label: 'Save ${attachment.name}',
                tooltip: 'Save',
                icon: AppIcons.download,
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: () => useFile(saveToDevice),
              ),
      ),
    );
  }
}

/// The look of a file card: an icon, the name, and under it a [notice] or the
/// size.
class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.attachment,
    this.notice,
    this.noticeIsError = false,
    this.onTap,
    this.trailing,
  });

  final ChatAttachment attachment;
  final String? notice;
  final bool noticeIsError;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = attachment.size;
    final subtitle = notice ?? (size == null ? null : formatFileSize(size));
    final radius = BorderRadius.circular(kHermesRadius);
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: radius,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  attachment.kind == AttachmentKind.image
                      ? AppIcons.image
                      : AppIcons.file,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.3),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: noticeIsError
                                ? scheme.error
                                : context.hermesColors.subtleText,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 6), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
