import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../widgets/grouped_list.dart';
import 'file_glyph.dart';

/// The "Files" row under "This session" in the Activity panel: the folder's
/// name as its value, opening the Files page of the chat.
class FilesActivityRow extends StatelessWidget {
  const FilesActivityRow({super.key, this.folderName, required this.onTap});

  /// The chat's working folder; the row says only "Files" without it.
  final String? folderName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: GroupedSection(
        dividerIndent: metrics.indentAfterLeading,
        children: [
          GroupedRow(
            key: const Key('activity-files-row'),
            leading: GroupedTile(child: AppIcon(FileGlyph.folder.icon)),
            title: context.l10n.filesEntryLabel,
            value: folderName,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}
