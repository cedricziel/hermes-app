import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../server_path.dart';
import 'file_row.dart';

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
  });

  final List<FileRowModel> rows;
  final ValueChanged<FileRowModel> onTap;
  final ServerPath? selected;

  @override
  Widget build(BuildContext context) {
    final folders = [
      for (final row in rows)
        if (row.isFolder) row,
    ];
    final metrics = GroupedMetrics.of(context);
    return GroupedListView(
      children: [
        if (folders.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.filesPickEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.hermesColors.subtleText),
            ),
          )
        else
          GroupedSection(
            dividerIndent: metrics.indentAfterLeading,
            children: [
              for (final row in folders)
                FileRow(
                  key: row.path == null ? null : ValueKey(row.path),
                  model: row,
                  mode: FileRowMode.pick,
                  selected:
                      selected != null &&
                      row.path != null &&
                      row.path == selected,
                  onTap: () => onTap(row),
                ),
            ],
          ),
      ],
    );
  }
}
