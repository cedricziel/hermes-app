import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../chat/widgets/quick_look_target.dart';
import '../drag_out/drag_out_item.dart';
import '../drag_out/drag_out_source.dart';
import '../drag_out/sanitize_drag_file_name.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/settings_scaffold.dart';
import 'files_controller.dart';
import 'files_models.dart';
import 'files_state.dart';
import 'files_view_models.dart';
import 'widgets/file_preview_header.dart';
import 'widgets/file_preview_cover.dart';
import 'widgets/file_glyph.dart';
import 'widgets/files_preview_body.dart';

/// What the preview's buttons do, as the screen wires them to the controller.
class FilesPreviewActions {
  const FilesPreviewActions({
    required this.save,
    required this.reload,
    required this.tryAgain,
    required this.cancelDownload,
    required this.downloadFull,
    required this.open,
    this.share,
    this.openWith,
    this.quickLook,
  });

  final VoidCallback save;
  final VoidCallback reload;
  final VoidCallback tryAgain;
  final VoidCallback cancelDownload;
  final VoidCallback downloadFull;

  /// A PDF's Open: Quick Look on a Mac, the system's app elsewhere.
  final VoidCallback open;

  /// Null where the platform has no share sheet (desktop).
  final VoidCallback? share;

  /// Null where Open with… is not offered: iOS (the share sheet does it) and
  /// a file Windows would run.
  final VoidCallback? openWith;

  /// Space, on a Mac.
  final VoidCallback? quickLook;

  FilesPreviewCallbacks get body => FilesPreviewCallbacks(
    onOpen: open,
    onSave: save,
    onShare: share,
    onOpenWith: openWith,
    onTryAgain: tryAgain,
    onCancelDownload: cancelDownload,
    onDownloadFull: downloadFull,
  );
}

/// What a drag of [entry] out of the window carries: its name now, its bytes
/// only when the receiver asks, one download at most. Null for a folder or a
/// secret-looking file the user has not said Continue for, so nothing is
/// offered to the receiver that cannot be delivered.
DragOutFile? filesDragItem(
  FilesController controller,
  FsEntry entry,
  String fallbackName,
) {
  final drag = controller.beginDrag(entry);
  if (drag == null) return null;
  return DragOutFile(
    name: sanitizeDragFileName(entry.name, fallback: fallbackName),
    read: () async {
      final file = await drag.file();
      if (file == null) throw StateError('no file');
      return file.readAsBytes();
    },
    localPath: () async => (await drag.file())?.path,
    cancel: drag.cancel,
  );
}

/// The preview beside the list on a wide layout: the header with its
/// actions, then the preview. On a Mac the tile drags the file out and Space
/// shows it in Quick Look.
class FilesPreviewPane extends StatelessWidget {
  const FilesPreviewPane({
    super.key,
    required this.controller,
    required this.actions,
    required this.platformActions,
    this.confirmLink,
  });

  final FilesController controller;
  final FilesPreviewActions actions;
  final FilesPlatformActions platformActions;
  final Future<bool> Function(BuildContext context, String host)? confirmLink;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final entry = controller.selected;
      final model = previewModelOf(controller, actions: platformActions);
      final body = FilesPreviewBody(
        model: model,
        callbacks: actions.body,
        confirmLink: confirmLink,
      );
      if (entry == null || controller.preview is PreviewIdle) return body;
      final mac = platformChromeOf(context) == PlatformChrome.macos;
      final l10n = context.l10n;
      return FilesCoverGate(
        controller: controller,
        child: Column(
          children: [
            FilePreviewHeader(
              name: entry.path.name,
              size: controller.knownSize,
              onShare: actions.share,
              onSave: actions.save,
              onQuickLook: actions.quickLook,
              onOpenWith: actions.openWith,
              onReload: actions.reload,
              wrapTile: mac
                  ? (context, tile) => DragOut(
                      kind: DragOutKind.file,
                      item: () => filesDragItem(
                        controller,
                        entry,
                        l10n.filesDragFallbackName,
                      ),
                      child: tile,
                    )
                  : null,
            ),
            Expanded(
              child: mac
                  ? QuickLookTarget(
                      onToggle: actions.quickLook,
                      onShow: actions.quickLook,
                      onSave: actions.save,
                      child: body,
                    )
                  : body,
            ),
          ],
        ),
      );
    },
  );
}

/// The preview pushed over the list on a phone, on the settings page bar:
/// the file's name over its type, and Save, Share and … in that order, the
/// same as the pane's header.
class FilesPreviewPage extends StatelessWidget {
  const FilesPreviewPage({
    super.key,
    required this.controller,
    required this.actions,
    required this.platformActions,
    this.confirmLink,
    this.previousTitle,
  });

  final FilesController controller;
  final FilesPreviewActions actions;
  final FilesPlatformActions platformActions;
  final Future<bool> Function(BuildContext context, String host)? confirmLink;
  final String? previousTitle;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l10n = context.l10n;
      final ios = platformChromeOf(context) == PlatformChrome.ios;
      final entry = controller.selected;
      final name = entry?.path.name ?? '';
      final subtitle = entry == null
          ? null
          : filePreviewSubtitle(l10n, name, controller.knownSize);
      final share = actions.share;
      final openWith = actions.openWith;
      final more = SettingsBarAction.menu(
        label: l10n.filesMenuMore,
        icon: AppIcons.more,
        menu: (context) => [
          if (ios)
            PopupMenuItem<void>(
              enabled: false,
              child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
            )
          else ...[
            PopupMenuItem<void>(
              onTap: actions.save,
              child: Text(l10n.filesActionSave),
            ),
            if (share != null)
              PopupMenuItem<void>(
                onTap: share,
                child: Text(l10n.filesActionShare),
              ),
            if (openWith != null)
              PopupMenuItem<void>(
                onTap: openWith,
                child: Text(l10n.filesActionOpenWith),
              ),
          ],
          PopupMenuItem<void>(
            onTap: actions.reload,
            child: Text(l10n.filesActionReload),
          ),
        ],
      );
      final shareAction = share == null
          ? null
          : SettingsBarAction(
              label: l10n.filesActionShare,
              icon: AppIcons.share,
              onPressed: share,
            );
      final saveAction = SettingsBarAction(
        label: l10n.filesActionSave,
        icon: AppIcons.download,
        onPressed: actions.save,
      );
      return FilesCoverGate(
        controller: controller,
        child: SettingsScaffold(
          title: name,
          subtitle: subtitle,
          previousTitle: previousTitle,
          actions: [
            if (ios) ?shareAction,
            saveAction,
            if (!ios) ?shareAction,
            more,
          ],
          body: FilesPreviewBody(
            model: previewModelOf(controller, actions: platformActions),
            callbacks: actions.body,
            confirmLink: confirmLink,
          ),
        ),
      );
    },
  );
}

/// Draws a blank surface with only the file type's icon over [child] while
/// the app is inactive and a file is selected, whether or not App Lock is on,
/// so the app switcher's snapshot shows no name and no content.
class FilesCoverGate extends StatefulWidget {
  const FilesCoverGate({
    super.key,
    required this.controller,
    required this.child,
  });

  final FilesController controller;
  final Widget child;

  @override
  State<FilesCoverGate> createState() => _FilesCoverGateState();
}

class _FilesCoverGateState extends State<FilesCoverGate> {
  late final AppLifecycleListener _lifecycle;
  var _covered = false;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _covered = state != null && state != AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) =>
          setState(() => _covered = state != AppLifecycleState.resumed),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.controller.selected;
    // Only where the system snapshots an inactive app for a switcher; a
    // desktop window that lost focus is not blanked.
    final platform = Theme.of(context).platform;
    final covers =
        platform == TargetPlatform.iOS || platform == TargetPlatform.android;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (covers && _covered && entry != null)
          Positioned.fill(
            key: const Key('files-preview-cover'),
            child: FilePreviewCover(glyph: fileGlyphForName(entry.path.name)),
          ),
      ],
    );
  }
}
