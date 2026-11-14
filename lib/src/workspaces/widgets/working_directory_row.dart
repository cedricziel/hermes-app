import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/files_metrics.dart';
import '../../files/widgets/files_spinner.dart';
import '../../files/widgets/server_path_text.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import 'workspace_widget_support.dart';

/// What the row above a new chat's composer is doing.
enum WorkingDirectoryRowState {
  /// The profile's default folder is being looked up: a spinner and a
  /// skeleton path, and the row is not a button.
  lookingUp,

  /// The folder is known: "Runs in demo", its path, branch and tag.
  ready,

  /// The lookup had no answer for 10 s: "Runs in the server's default
  /// folder", with no path, and the row opens the picker.
  stalled,
}

/// The row directly above a new chat's composer: where the first message will
/// run. A full-width row (surface fill, 12 pt corners, 48 pt high, 36 pt on a
/// Mac) with the folder glyph, "Runs in **demo**", a branch chip, one tag
/// ("Server default" outlined while nothing is picked, else the project name,
/// tinted), "path · on your server" with the path cut in the middle, and a
/// chevron. The whole row is one button.
///
/// At a large text size the name wraps, the chips stack and the path wraps in
/// full with "on your server" on its own line. A screen reader hears "Folder:
/// demo, /home/me/code/demo on your server, branch main, Server default,
/// button". It takes plain values and a callback, so any screen can use it.
class WorkingDirectoryRow extends StatelessWidget {
  const WorkingDirectoryRow({
    super.key,
    this.state = WorkingDirectoryRowState.ready,
    this.folderName,
    this.path,
    this.branch,
    this.projectName,
    this.serverDefault = false,
    this.homeFolder = false,
    this.offline = false,
    this.onTap,
  });

  final WorkingDirectoryRowState state;

  /// The folder's name, as the chat list writes it.
  final String? folderName;

  /// The folder's full path on the server.
  final String? path;
  final String? branch;

  /// The Hermes project the folder belongs to, shown as the tag unless
  /// [serverDefault] is set.
  final String? projectName;

  /// No folder was picked: the tag says "Server default".
  final bool serverDefault;

  /// The folder is the server's home folder or `/`: a warning line says why
  /// that is a risk.
  final bool homeFolder;

  /// The device is offline: the row keeps the last known folder and says so.
  final bool offline;

  /// Opens the picker. Ignored while [state] is
  /// [WorkingDirectoryRowState.lookingUp].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final large = isLargeText(context);
    final fontSize = mac ? 13.0 : 15.0;
    final smallSize = mac ? 11.0 : 13.0;
    final muted = colors.subtleText;
    final lookingUp = state == WorkingDirectoryRowState.lookingUp;
    final isReady = state == WorkingDirectoryRowState.ready;
    final stalled = state == WorkingDirectoryRowState.stalled;
    final name = workspaceShortName(folderName ?? '', max: 40);
    final path = stalled || lookingUp ? null : this.path;
    final showName = !lookingUp && !stalled && name.isNotEmpty;

    final title = lookingUp
        ? l10n.workspacesRowLookingUp
        : stalled
        ? l10n.workspacesRowServerDefaultFolder
        : l10n.workspacesRowRunsIn(name);
    final titleStyle = TextStyle(fontSize: fontSize, color: scheme.onSurface);
    final titleText = Text.rich(
      showName
          ? workspaceBoldName(title, name, style: titleStyle)
          : TextSpan(text: title, style: titleStyle),
      maxLines: large ? null : 2,
      // An ellipsis with no line limit would cut the text to one line.
      overflow: large ? TextOverflow.clip : TextOverflow.ellipsis,
    );

    final tag = isReady && name.isNotEmpty
        ? serverDefault
              ? WorkspaceChip.outlined(l10n.workspacesTagServerDefault)
              : (projectName != null
                    ? WorkspaceChip.tinted(projectName!)
                    : null)
        : null;
    final hasBranch = isReady && branch != null && branch!.isNotEmpty;

    final lines = <Widget>[
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth),
              child: titleText,
            ),
            if (hasBranch)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth),
                child: WorkspaceChip.branch(branch!),
              ),
            if (tag != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth),
                child: tag,
              ),
          ],
        ),
      ),
      if (lookingUp)
        const _SkeletonPath()
      else if (path != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ServerPathText.text(
            path,
            style: TextStyle(fontSize: smallSize, color: muted),
          ),
        ),
      if (offline && !lookingUp)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _StatusLine(
            icon: kWorkspaceOfflineIcon,
            text: l10n.workspacesRowOffline,
            color: muted,
            size: smallSize,
          ),
        ),
      if (homeFolder && isReady)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _StatusLine(
            icon: AppIcons.warning,
            text: l10n.workspacesHomeFolderNote,
            color: colors.warning,
            size: smallSize,
          ),
        ),
    ];

    final leading = lookingUp
        ? const FilesSpinner(size: 18)
        : AppIcon(
            AppIcons.folder,
            size: workspaceGlyphSize(context, mac ? 18 : 22),
            color: colors.link,
          );
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: mac ? 36 : 48),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: mac ? 10 : 12, vertical: 8),
        child: Row(
          crossAxisAlignment: large
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            ExcludeSemantics(child: leading),
            SizedBox(width: mac ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: lines,
              ),
            ),
            if (!lookingUp) ...[
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: AppIcon(
                  AppIcons.chevronRight,
                  size: workspaceGlyphSize(context, mac ? 16 : 20),
                  color: muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final label = lookingUp
        ? l10n.workspacesRowLookingUp
        : stalled
        ? l10n.workspacesRowServerDefaultFolder
        : workspaceFolderLabel(
            l10n,
            name: folderName ?? '',
            path: path,
            branch: hasBranch ? branch : null,
            notes: [
              if (serverDefault) l10n.workspacesTagServerDefault,
              if (!serverDefault && projectName != null)
                l10n.workspacesLabelProject(projectName!),
              if (offline) l10n.workspacesRowOffline,
              if (homeFolder) l10n.workspacesHomeFolderNote,
            ],
          );
    final radius = BorderRadius.circular(12);
    final decoration = BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: radius,
    );
    if (lookingUp) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: label,
        child: DecoratedBox(
          decoration: decoration,
          child: ExcludeSemantics(child: content),
        ),
      );
    }
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ExcludeSemantics(child: content),
        ),
      ),
    );
  }
}

/// A grey bar where the path will be. Drawn on the on-surface colour, not
/// with `LoadingSkeleton`, whose fill is the row's own in the dark theme.
class _SkeletonPath extends StatelessWidget {
  const _SkeletonPath();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 2),
    child: ExcludeSemantics(
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.65,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const SizedBox(height: 12),
        ),
      ),
    ),
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.text,
    required this.color,
    required this.size,
  });

  final AppIconSet icon;
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: AppIcon(
            icon,
            size: workspaceGlyphSize(context, size + 1),
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: size, color: color),
          ),
        ),
      ],
    );
  }
}
