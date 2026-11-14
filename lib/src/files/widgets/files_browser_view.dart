import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/state_message.dart';
import '../server_path.dart';
import 'file_row.dart';
import 'files_failures.dart';
import 'files_metrics.dart';
import 'files_notes.dart';
import 'files_spinner.dart';

/// What the list area of the Files page shows. The screen maps its
/// controller's state onto one of these.
sealed class FolderViewState {
  const FolderViewState();
}

/// The folder's list is on its way.
class FolderViewLoading extends FolderViewState {
  const FolderViewLoading();
}

/// A folder that was read. With no [rows] it is the empty state.
class FolderViewReady extends FolderViewState {
  const FolderViewReady({
    this.rows = const [],
    this.hasHiddenFiles = false,
    this.totalCount,
    this.stale = false,
    this.showServerFolderNote = false,
  });

  /// Folders first, then files, in the order the server sent them.
  final List<FileRowModel> rows;

  /// An empty list: the folder holds hidden files that are not shown.
  final bool hasHiddenFiles;

  /// The folder's real size, when the list was cut at its cap.
  final int? totalCount;

  /// A refresh failed after this list was read.
  final bool stale;

  /// The chat has not started, so this is the server's own folder.
  final bool showServerFolderNote;
}

/// A folder that cannot be shown.
class FolderViewProblem extends FolderViewState {
  const FolderViewProblem(this.problem, {this.atHighest = false});

  final FolderProblem problem;
  final bool atHighest;
}

/// The list area of the Files page: a folder's rows, its notes, and every
/// state it can be in. On [GroupedListView], [GroupedSection] and
/// [StateMessage]; it holds no controller. The path bar and the page's bar
/// are the screen's.
class FilesBrowserView extends StatelessWidget {
  const FilesBrowserView({
    super.key,
    required this.state,
    required this.onOpen,
    this.selected,
    this.onTryAgain,
    this.onRefresh,
    this.onShowHidden,
    this.onUp,
    this.onGoBack,
  });

  final FolderViewState state;

  /// Taps a row; a folder opens, a file is previewed.
  final ValueChanged<FileRowModel> onOpen;

  /// The file whose preview shows beside the list (wide layouts).
  final ServerPath? selected;
  final VoidCallback? onTryAgain;
  final VoidCallback? onRefresh;
  final VoidCallback? onShowHidden;
  final VoidCallback? onUp;
  final VoidCallback? onGoBack;

  @override
  Widget build(BuildContext context) => switch (state) {
    FolderViewLoading() => const _LoadingFolder(),
    FolderViewProblem(:final problem, :final atHighest) => FolderProblemView(
      problem: problem,
      atHighest: atHighest,
      onTryAgain: onTryAgain,
      onUp: onUp,
      onGoBack: onGoBack,
    ),
    final FolderViewReady ready when ready.rows.isEmpty => _EmptyFolder(
      hasHiddenFiles: ready.hasHiddenFiles,
      onRefresh: onRefresh,
      onShowHidden: onShowHidden,
    ),
    final FolderViewReady ready => _FolderList(
      ready: ready,
      selected: selected,
      onOpen: onOpen,
      onTryAgain: onTryAgain,
    ),
  };
}

class _FolderList extends StatelessWidget {
  const _FolderList({
    required this.ready,
    required this.selected,
    required this.onOpen,
    required this.onTryAgain,
  });

  final FolderViewReady ready;
  final ServerPath? selected;
  final ValueChanged<FileRowModel> onOpen;
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final total = ready.totalCount;
    return GroupedListView(
      children: [
        if (ready.stale && onTryAgain != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilesOfflineBanner(onRetry: onTryAgain!),
          ),
        if (ready.showServerFolderNote)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: FilesServerFolderNote(),
          ),
        GroupedSection(
          dividerIndent: metrics.indentAfterLeading,
          footer: total != null && total > ready.rows.length
              ? l10n.filesListCapFooter(ready.rows.length, total)
              : null,
          children: [
            for (final row in ready.rows)
              FileRow(
                key: row.path == null ? null : ValueKey(row.path),
                model: row,
                selected:
                    selected != null &&
                    row.path != null &&
                    row.path == selected,
                onTap: () => onOpen(row),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder({
    required this.hasHiddenFiles,
    required this.onRefresh,
    required this.onShowHidden,
  });

  final bool hasHiddenFiles;
  final VoidCallback? onRefresh;
  final VoidCallback? onShowHidden;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final files = FilesMetrics.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: scrollingMessage(
        StateMessage(
          icon: const AppIconSet(
            Icons.folder_open_outlined,
            CupertinoIcons.folder,
          ),
          title: l10n.filesFolderEmptyTitle,
          detail: hasHiddenFiles
              ? l10n.filesFolderEmptyHiddenDetail
              : l10n.filesFolderEmptyDetail,
          action: OutlinedButton(
            onPressed: hasHiddenFiles ? onShowHidden : onRefresh,
            style: files.buttonStyle(),
            child: Text(
              hasHiddenFiles
                  ? l10n.filesActionShowHidden
                  : l10n.filesActionRefresh,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Eight still skeleton rows under a spinner and "Loading folder…". Nothing
/// pulses, so reduced motion needs no variant.
class _LoadingFolder extends StatelessWidget {
  const _LoadingFolder();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final files = FilesMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final block = scheme.surfaceContainerHighest;
    const widths = [0.55, 0.4, 0.7, 0.5, 0.62, 0.35, 0.58, 0.46];
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.filesFolderLoading,
      child: ExcludeSemantics(
        child: GroupedListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FilesSpinner(),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.filesFolderLoading,
                      style: TextStyle(
                        fontSize: metrics.titleSize,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GroupedSection(
              dividerIndent: metrics.indentAfterLeading,
              children: [
                for (final width in widths)
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: files.rowMinHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.rowPadding,
                      ),
                      child: Row(
                        children: [
                          _Block(
                            color: block,
                            width: metrics.leadingSize,
                            height: metrics.leadingSize,
                          ),
                          SizedBox(width: metrics.leadingGap),
                          Expanded(
                            child: FractionallySizedBox(
                              alignment: AlignmentDirectional.centerStart,
                              widthFactor: width,
                              child: _Block(color: block, height: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.color, this.width, required this.height});

  final Color color;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
    child: SizedBox(width: width, height: height),
  );
}

/// The empty preview pane beside the list of a wide layout.
class FilesNoSelection extends StatelessWidget {
  const FilesNoSelection({super.key});

  @override
  Widget build(BuildContext context) => scrollingMessage(
    StateMessage(icon: AppIcons.file, title: context.l10n.filesNoSelection),
  );
}
