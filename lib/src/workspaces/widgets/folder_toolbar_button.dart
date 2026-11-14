import 'package:flutter/material.dart';

import '../../files/widgets/safe_path_text.dart';

import '../../../l10n/l10n.dart';
import '../../macos/mac_toolbar.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import 'workspace_widget_support.dart';

/// The Mac toolbar's folder button: the folder glyph, the folder's name and a
/// small chevron, 28 pt high, with the path in its tooltip. On a new chat it
/// opens the picker as a dialog, on an open chat the details. It sits before
/// New Chat; [MacToolbarButton] is icon-only, so this is its titled sibling in
/// the same style.
///
/// A long name is cut in the middle. With a null [onPressed] it is disabled,
/// and still says which folder. A screen reader hears "Folder: demo,
/// /home/me/code/demo on your server, branch main, button".
class FolderToolbarButton extends StatelessWidget {
  const FolderToolbarButton({
    super.key,
    required this.folderName,
    required this.path,
    this.branch,
    this.onPressed,
  });

  final String folderName;

  /// The folder's full path on the server, for the tooltip and the label.
  final String path;
  final String? branch;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final enabled = onPressed != null;
    final color = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.4);
    return Tooltip(
      message: l10n.workspacesPathLabel(safePathText(path)),
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: workspaceFolderLabel(
          l10n,
          name: folderName,
          path: path,
          branch: branch,
        ),
        excludeSemantics: true,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 28, maxWidth: 220),
          child: TextButton(
            key: const Key('folder-toolbar-button'),
            onPressed: onPressed,
            style:
                TextButton.styleFrom(
                  foregroundColor: color,
                  disabledForegroundColor: color,
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.standard,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
                ).copyWith(
                  overlayColor: WidgetStatePropertyAll(
                    scheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppIcons.folder, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    workspaceShortName(folderName, max: 24),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                AppIcon(AppIcons.expandMore, size: 14, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
