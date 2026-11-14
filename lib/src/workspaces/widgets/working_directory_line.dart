import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/files_metrics.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import 'workspace_widget_support.dart';

/// Whether the folder line leaves the bar and becomes a full-width row under
/// it: at a large text size, so the bar keeps one line of title.
bool workingDirectoryLineBelowBar(BuildContext context) => isLargeText(context);

/// The line under an open chat's title: the folder glyph, "api · main" (the
/// folder and the branch) and a small chevron. A tap opens the folder's
/// details.
///
/// In the bar it is a second line of the title, and with a [title] the whole
/// title area is the target (at least 44 pt, 48 dp on Android, 28 pt on a
/// Mac). At a large text size ([workingDirectoryLineBelowBar]) it draws as a
/// full-width row to put directly under the bar, and [title] is left to the
/// bar. With [offline] it adds "Offline".
///
/// A screen reader hears "Folder: api, branch main, button".
class WorkingDirectoryLine extends StatelessWidget {
  const WorkingDirectoryLine({
    super.key,
    required this.folderName,
    this.branch,
    this.offline = false,
    this.title,
    this.belowBar,
    this.onTap,
  });

  final String folderName;
  final String? branch;
  final bool offline;

  /// The chat's title, drawn above the line inside the same target. Ignored
  /// in the full-width form.
  final String? title;

  /// Draw the full-width form. Null: at a large text size only.
  final bool? belowBar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final below = belowBar ?? workingDirectoryLineBelowBar(context);
    final size = below ? 15.0 : (mac ? 11.0 : 13.0);
    final muted = colors.subtleText;
    final target = FilesMetrics.of(context).target;
    final parts = [
      workspaceShortName(folderName, max: 28),
      if (branch != null && branch!.isNotEmpty)
        workspaceShortName(branch!, max: 24),
      if (offline) l10n.workspacesRowOffline,
    ];
    final line = Row(
      crossAxisAlignment: below
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: below ? MainAxisSize.max : MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: AppIcon(
            AppIcons.folder,
            size: workspaceGlyphSize(context, size + 1),
            color: muted,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            parts.join(' · '),
            maxLines: below ? null : 1,
            overflow: below ? TextOverflow.clip : TextOverflow.ellipsis,
            style: TextStyle(fontSize: size, color: muted),
          ),
        ),
        const SizedBox(width: 2),
        ExcludeSemantics(
          child: AppIcon(
            AppIcons.chevronRight,
            size: workspaceGlyphSize(context, size),
            color: muted,
          ),
        ),
      ],
    );
    final title = below ? null : this.title;
    final content = Padding(
      padding: below
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
          : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: below
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: mac ? 13 : 17,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          line,
        ],
      ),
    );
    final minHeight = below ? (mac ? 36.0 : 48.0) : target;
    return Semantics(
      button: true,
      label: [
        ?title,
        workspaceFolderLabel(
          l10n,
          name: folderName,
          branch: branch,
          notes: [if (offline) l10n.workspacesRowOffline],
        ),
      ].join('. '),
      child: Material(
        color: below ? scheme.surface : Colors.transparent,
        shape: below
            ? Border(bottom: BorderSide(color: scheme.outlineVariant))
            : null,
        child: InkWell(
          onTap: onTap,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: below ? null : 1,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
