import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/files_metrics.dart';
import '../../files/widgets/middle_ellipsis.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';

/// The glyph of "no connection".
const AppIconSet kWorkspaceOfflineIcon = AppIconSet(
  Icons.cloud_off_outlined,
  CupertinoIcons.wifi_slash,
);

/// The glyph that goes up one folder.
const AppIconSet kWorkspaceUpIcon = AppIconSet(
  Icons.arrow_upward,
  CupertinoIcons.arrow_up,
);

/// The name of the folder at the end of [path], written as the chat list
/// writes it: no trailing separator, and the whole path for a root.
String workspaceFolderName(String path) {
  final trimmed = path.length > 1
      ? path.replaceFirst(RegExp(r'[/\\]+$'), '')
      : path;
  if (trimmed.isEmpty) return path;
  final segments = trimmed
      .split(RegExp(r'[/\\]'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return path;
  final last = segments.last;
  // `C:` is the root of a drive, so keep its separator.
  return RegExp(r'^[A-Za-z]:$').hasMatch(last) ? '$last\\' : last;
}

/// A folder or branch name cut in the middle when it is longer than [max].
String workspaceShortName(String name, {int max = 32}) =>
    elideMiddle(name, maxChars: max);

/// `Name` in bold inside [sentence], which holds it once (the sentence is a
/// translation, so the name can sit anywhere in it). A sentence without it
/// comes back plain.
TextSpan workspaceBoldName(
  String sentence,
  String name, {
  TextStyle? style,
  TextStyle? bold,
}) {
  final at = name.isEmpty ? -1 : sentence.indexOf(name);
  if (at < 0) return TextSpan(text: sentence, style: style);
  return TextSpan(
    style: style,
    children: [
      TextSpan(text: sentence.substring(0, at)),
      TextSpan(
        text: name,
        style: bold ?? const TextStyle(fontWeight: FontWeight.w600),
      ),
      TextSpan(text: sentence.substring(at + name.length)),
    ],
  );
}

/// What a screen reader says for the folder row, the folder line and the
/// toolbar button: "Folder: demo, /home/me/code/demo on your server, branch
/// main, Server default".
String workspaceFolderLabel(
  AppLocalizations l10n, {
  required String name,
  String? path,
  String? branch,
  List<String> notes = const [],
}) => [
  l10n.workspacesLabelFolder(name),
  if (path != null) l10n.workspacesPathLabel(path),
  if (branch != null) l10n.workspacesLabelBranch(branch),
  ...notes,
].join(', ');

/// A small pill: the branch of a folder (with the branch glyph and a
/// monospace name, a hairline outline) or a tag such as "Server default" (an
/// outline) or a project name (tinted). It always carries words.
class WorkspaceChip extends StatelessWidget {
  const WorkspaceChip.branch(this.label, {super.key})
    : _kind = _ChipKind.branch;

  const WorkspaceChip.outlined(this.label, {super.key})
    : _kind = _ChipKind.outlined;

  const WorkspaceChip.tinted(this.label, {super.key})
    : _kind = _ChipKind.tinted;

  final String label;
  final _ChipKind _kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final pointer = platformChromeOf(context) == PlatformChrome.macos;
    final size = pointer ? 11.0 : 12.0;
    final tinted = _kind == _ChipKind.tinted;
    final textColor = tinted ? colors.link : scheme.onSurfaceVariant;
    final text = Text(
      workspaceShortName(label, max: 28),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: size,
        height: 1.25,
        fontWeight: FontWeight.w500,
        color: textColor,
        fontFamily: _kind == _ChipKind.branch ? 'monospace' : null,
      ),
    );
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tinted ? colors.link.withValues(alpha: 0.12) : null,
          border: Border.all(
            color: tinted
                ? colors.link.withValues(alpha: 0.35)
                : scheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_kind == _ChipKind.branch) ...[
                AppIcon(
                  AppIcons.branch,
                  size: workspaceGlyphSize(context, size + 1),
                  color: textColor,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(child: text),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ChipKind { branch, outlined, tinted }

/// The size a workspace control must be at least, on this platform: 44 pt on
/// iOS, 48 dp on Android and 28 pt for a pointer on a Mac.
double workspaceTarget(BuildContext context) => FilesMetrics.of(context).target;

/// A glyph's size: it grows with the text, but not as far as the text does
/// (at most 1.5 times), as the glyphs of the Files rows do.
double workspaceGlyphSize(BuildContext context, double size) =>
    size * textScaleOf(context).clamp(1.0, 1.5);
