import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../server_path.dart';
import 'file_row.dart';
import 'files_lazy_list.dart';

/// The folders of a folder, for choosing one (the working-folder picker): only
/// folders, no files and no menu, in the same rows as the file list. The row
/// of [selected] shows a check mark; a tap on any row calls [onTap], which
/// opens that folder or chooses it. Put it under a `FilePathBar`.
///
/// Rows that are not folders are left out, so a caller can pass a whole
/// listing.
class FolderPickList extends StatelessWidget {
  const FolderPickList({
    super.key,
    required this.rows,
    required this.onTap,
    this.selected,
    this.leading = const [],
  });

  final List<FileRowModel> rows;
  final ValueChanged<FileRowModel> onTap;
  final ServerPath? selected;

  /// Widgets above the first row, outside the card (an "up one folder" row).
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final folders = [
      for (final row in rows)
        if (row.isFolder) row,
    ];
    final metrics = GroupedMetrics.of(context);
    if (folders.isEmpty) {
      return GroupedListView(
        children: [
          ...leading,
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.filesPickEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.hermesColors.subtleText),
            ),
          ),
        ],
      );
    }
    return FilesLazyList(
      leading: leading,
      dividerIndent: metrics.indentAfterLeading,
      itemCount: folders.length,
      itemBuilder: (context, i) {
        final row = folders[i];
        return FileRow(
          key: row.path == null ? null : ValueKey(row.path),
          model: row,
          mode: FileRowMode.pick,
          selected:
              selected != null && row.path != null && row.path == selected,
          onTap: () => onTap(row),
        );
      },
    );
  }
}
