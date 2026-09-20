import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../chat_models.dart';

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

/// An image attachment as a thumbnail: from the file the user picked, or from
/// the data the history embedded. When the picture cannot be drawn it shows as
/// the card of a file.
class AttachmentThumbnail extends StatelessWidget {
  const AttachmentThumbnail({super.key, required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final card = AttachmentCard(attachment: attachment);
    final bytes = attachment.bytes;
    final path = attachment.path;
    final ImageProvider? provider = bytes != null
        ? MemoryImage(bytes)
        : path != null
        ? FileImage(File(path))
        : null;
    if (provider == null) return card;
    return ClipRRect(
      borderRadius: BorderRadius.circular(kHermesRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _thumbnailSize,
          maxHeight: _thumbnailSize,
        ),
        child: Image(
          // A photo can weigh 25 MB; decode it at the size it is shown.
          image: ResizeImage.resizeIfNeeded(
            (_thumbnailSize * MediaQuery.devicePixelRatioOf(context)).round(),
            null,
            provider,
          ),
          semanticLabel: attachment.name,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => card,
        ),
      ),
    );
  }
}

/// A file attachment as a card with its name and, when known, its size.
class AttachmentCard extends StatelessWidget {
  const AttachmentCard({super.key, required this.attachment});

  final ChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = attachment.size;
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(kHermesRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            attachment.kind == AttachmentKind.image
                ? Icons.image_outlined
                : Icons.insert_drive_file_outlined,
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
                if (size != null)
                  Text(
                    formatFileSize(size),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: context.hermesColors.subtleText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
