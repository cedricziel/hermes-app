import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/named_icon_button.dart';
import '../../widgets/named_popup_menu_button.dart';
import 'file_glyph.dart';
import 'file_size.dart';
import 'files_metrics.dart';
import 'middle_ellipsis.dart';

/// "Python · 1.8 KB": the file's type word and, once known, its size. The
/// subtitle of a phone's preview bar and the second line of the pane header.
String filePreviewSubtitle(AppLocalizations l10n, String name, int? size) {
  final type = fileTypeLabel(l10n, name);
  return size == null
      ? type
      : l10n.filesPreviewTypeSize(type, formatByteSize(l10n, size));
}

/// What a preview header's … menu can do.
enum FilePreviewMenuChoice { openWith, reload }

/// The header of the preview pane beside the list (iPad and desktop): a tile
/// with the type's icon, the name on up to two lines (cut in the middle,
/// keeping the extension), "type · size", and the actions: Share, Save and …
/// on iPad (44 pt), Quick Look, Save and … on the Mac (32 pt tile, 28 pt
/// buttons). The … menu holds Open with… and Reload.
///
/// On the Mac the tile is the drag-out handle: pass [wrapTile] to put the
/// screen's `DragOut` around it. At a large text size the header stacks: the
/// tile, then the name and its type, then the actions.
class FilePreviewHeader extends StatelessWidget {
  const FilePreviewHeader({
    super.key,
    required this.name,
    this.size,
    this.onShare,
    this.onSave,
    this.onQuickLook,
    this.onOpenWith,
    this.onReload,
    this.wrapTile,
  });

  final String name;

  /// Null until the size is known; the subtitle is then the type alone.
  final int? size;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onQuickLook;
  final VoidCallback? onOpenWith;
  final VoidCallback? onReload;

  /// Wraps the tile, for the Mac's drag-out handle.
  final Widget Function(BuildContext context, Widget tile)? wrapTile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final files = FilesMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final large = isLargeText(context);
    final mac = files.pointer;
    final tileSize = files.previewTile;
    Widget tile = ExcludeSemantics(
      child: Container(
        key: const Key('file-preview-tile'),
        width: tileSize,
        height: tileSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(mac ? 6 : 8),
        ),
        child: AppIcon(
          fileGlyphForName(name).icon,
          size: mac ? 18 : 24,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
    final wrap = wrapTile;
    if (wrap != null) {
      tile = Tooltip(
        message: l10n.filesDragTooltip,
        excludeFromSemantics: true,
        child: wrap(context, tile),
      );
    }
    final titleSize = mac ? 13.0 : 17.0;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: name,
          excludeSemantics: true,
          header: true,
          child: MiddleEllipsisText(
            name,
            maxLines: large ? null : 2,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        Text(
          filePreviewSubtitle(l10n, name, size),
          style: TextStyle(fontSize: mac ? 11 : 14, color: muted),
        ),
      ],
    );
    final iconSize = mac ? 16.0 : 22.0;
    final actions = <Widget>[
      if (mac)
        NamedIconButton(
          label: l10n.filesActionQuickLook,
          tooltip: l10n.filesActionQuickLookTooltip,
          icon: AppIcons.eye,
          iconSize: iconSize,
          style: files.iconButtonStyle(),
          onPressed: onQuickLook,
        )
      else
        NamedIconButton(
          label: l10n.filesActionShare,
          icon: AppIcons.share,
          iconSize: iconSize,
          style: files.iconButtonStyle(),
          onPressed: onShare,
        ),
      NamedIconButton(
        label: l10n.filesActionSave,
        icon: AppIcons.download,
        iconSize: iconSize,
        style: files.iconButtonStyle(),
        onPressed: onSave,
      ),
      NamedPopupMenuButton<FilePreviewMenuChoice>(
        label: l10n.filesMenuMore,
        icon: AppIcons.more,
        iconSize: iconSize,
        padding: EdgeInsets.zero,
        style: files.iconButtonStyle(),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: FilePreviewMenuChoice.openWith,
            child: Text(l10n.filesActionOpenWith),
          ),
          PopupMenuItem(
            value: FilePreviewMenuChoice.reload,
            child: Text(l10n.filesActionReload),
          ),
        ],
        onSelected: (choice) => switch (choice) {
          FilePreviewMenuChoice.openWith => onOpenWith?.call(),
          FilePreviewMenuChoice.reload => onReload?.call(),
        },
      ),
    ];
    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tile,
        SizedBox(width: mac ? 10 : 12),
        Expanded(child: text),
        ...actions,
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: mac ? 12 : 16,
          vertical: mac ? 8 : 10,
        ),
        child: large
            // Stacked: the tile, then the name with its type and size, then
            // the actions, each with the whole width.
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tile,
                  const SizedBox(height: 8),
                  text,
                  const SizedBox(height: 4),
                  Row(children: actions),
                ],
              )
            : head,
      ),
    );
  }
}
