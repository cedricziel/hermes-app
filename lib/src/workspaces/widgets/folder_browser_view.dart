import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/server_path.dart';
import '../../files/widgets/file_path_bar.dart';
import '../../files/widgets/file_row.dart';
import '../../files/widgets/files_metrics.dart';
import '../../files/widgets/files_spinner.dart';
import '../../files/widgets/folder_pick_list.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/state_message.dart';
import 'workspace_use_bar.dart';
import 'workspace_widget_support.dart';

/// What the folder being browsed looks like.
enum FolderBrowserLevel {
  /// The level is being read: skeleton rows and "Opening code…".
  opening,

  /// The level was read; with no folders in it, it says so.
  ready,

  /// Hermes is not allowed to read it (EACCES, an SSH profile's 403). "Use"
  /// stays enabled, with a note above it, because the server accepts any
  /// existing folder.
  notAllowed,

  /// A level above what the server lets the app browse. "Use" is disabled.
  outside,

  /// The folder does not exist (ENOENT, or an SSH profile's 404 or 400).
  /// "Use" is disabled.
  missing,

  /// The connection dropped, or the level had no answer for 10 s: "Couldn't
  /// open this folder." with Try again.
  unreachable,
}

/// Browse folders on your server: a page on [SettingsScaffold] around the
/// shared path bar ([FilePathBar], the breadcrumb) and the shared folder list
/// ([FolderPickList], folders only), with a pinned filled "Use “code”" that
/// names the folder being shown.
///
/// The bar's back button says "Choose". Up is a "Back up one folder" row with
/// the parent's name (absent at the root); it is unrestricted within what the
/// server lets the app browse, and never stops at a git root. "Use" is
/// disabled only for a missing level or one outside the boundary. It takes
/// paths, rows and callbacks.
class FolderBrowserView extends StatelessWidget {
  const FolderBrowserView({
    super.key,
    required this.current,
    this.level = FolderBrowserLevel.ready,
    this.rows = const [],
    this.onOpen,
    this.onOpenPath,
    this.onUp,
    this.onUse,
    this.onTryAgain,
  });

  /// The folder shown.
  final ServerPath current;
  final FolderBrowserLevel level;

  /// The level's entries; files and other rows are left out.
  final List<FileRowModel> rows;

  /// A folder row was tapped: open it.
  final ValueChanged<FileRowModel>? onOpen;

  /// A breadcrumb segment was tapped.
  final ValueChanged<ServerPath>? onOpenPath;
  final VoidCallback? onUp;

  /// Choose the folder being shown.
  final VoidCallback? onUse;
  final VoidCallback? onTryAgain;

  /// Whether "Use" is available for this level.
  bool get canUse =>
      level == FolderBrowserLevel.ready ||
      level == FolderBrowserLevel.notAllowed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = workspaceShortName(
      current.isRoot ? current.value : current.name,
      max: 24,
    );
    return SettingsScaffold(
      title: l10n.workspacesBrowseTitle,
      subtitle: l10n.workspacesPickerSubtitle,
      previousTitle: l10n.workspacesBrowseBack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilePathBar(current: current, onOpen: onOpenPath ?? (_) {}),
          Expanded(child: _content(context, name)),
          WorkspaceUseBar(
            label: l10n.workspacesBrowseUse(name),
            // A disabled "Use" says why, next to the button.
            note: switch (level) {
              FolderBrowserLevel.notAllowed => l10n.workspacesMayNotWork,
              FolderBrowserLevel.missing => l10n.workspacesBrowseMissing,
              FolderBrowserLevel.outside => l10n.workspacesBrowseOutside,
              _ => null,
            },
            onPressed: canUse ? onUse : null,
          ),
        ],
      ),
    );
  }

  Widget _upRow(BuildContext context) {
    final parent = current.parent;
    if (parent == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return GroupedSection(
      children: [
        GroupedRow(
          key: const Key('folder-browser-up'),
          title: l10n.workspacesBrowseUp,
          titleMaxLines: isLargeText(context) ? null : 1,
          subtitle: workspaceShortName(
            parent.isRoot ? parent.value : parent.name,
            max: 32,
          ),
          leading: const AppIcon(kWorkspaceUpIcon),
          chevron: false,
          onTap: onUp ?? () {},
        ),
      ],
    );
  }

  Widget _content(BuildContext context, String name) {
    final l10n = context.l10n;
    final up = current.isRoot ? const <Widget>[] : [_upRow(context)];
    switch (level) {
      case FolderBrowserLevel.ready:
        final folders = [
          for (final row in rows)
            if (row.isFolder) row,
        ];
        if (folders.isEmpty) {
          return GroupedListView(
            children: [
              ...up,
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.workspacesBrowseEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.hermesColors.subtleText),
                  ),
                ),
              ),
            ],
          );
        }
        return FolderPickList(
          rows: folders,
          leading: up,
          onTap: (row) => onOpen?.call(row),
        );
      case FolderBrowserLevel.opening:
        return GroupedListView(
          children: [
            ...up,
            Semantics(
              container: true,
              liveRegion: true,
              label: l10n.workspacesBrowseOpening(name),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      const FilesSpinner(size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l10n.workspacesBrowseOpening(name))),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // The row above already announces "Opening …".
              child: ExcludeSemantics(
                child: LoadingSkeleton(
                  label: l10n.workspacesBrowseOpening(name),
                  lines: 5,
                ),
              ),
            ),
          ],
        );
      case FolderBrowserLevel.notAllowed:
        return _problem(
          up,
          icon: AppIcons.lock,
          title: l10n.workspacesBrowseCouldntOpen,
          detail: l10n.workspacesBrowseNotAllowedDetail,
        );
      case FolderBrowserLevel.outside:
        return _problem(
          up,
          icon: AppIcons.blocked,
          title: l10n.workspacesBrowseOutside,
          detail: l10n.workspacesBrowseOutsideDetail,
        );
      case FolderBrowserLevel.missing:
        return _problem(
          up,
          icon: const AppIconSet(
            Icons.folder_off_outlined,
            CupertinoIcons.folder_badge_minus,
          ),
          title: l10n.workspacesBrowseMissing,
          detail: l10n.workspacesBrowseMissingDetail,
        );
      case FolderBrowserLevel.unreachable:
        return _problem(
          up,
          icon: kWorkspaceOfflineIcon,
          title: l10n.workspacesBrowseUnreachable,
          detail: l10n.workspacesBrowseUnreachableDetail,
          action: Builder(
            builder: (context) => OutlinedButton(
              onPressed: onTryAgain,
              style: FilesMetrics.of(context).buttonStyle(),
              child: Text(l10n.workspacesTryAgain),
            ),
          ),
        );
    }
  }

  /// The level's failure, announced when it appears, under the way up.
  Widget _problem(
    List<Widget> up, {
    required AppIconSet icon,
    required String title,
    required String detail,
    Widget? action,
  }) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...up.map(
          (row) => Builder(
            builder: (context) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: GroupedMetrics.of(context).gutter,
              ),
              child: row,
            ),
          ),
        ),
        Semantics(
          container: true,
          liveRegion: true,
          child: StateMessage(
            icon: icon,
            title: title,
            detail: detail,
            action: action,
          ),
        ),
      ],
    ),
  );
}
