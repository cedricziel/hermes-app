import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import '../server_path.dart';
import 'file_glyph.dart';
import 'files_metrics.dart';
import 'middle_ellipsis.dart';

/// One entry of a folder as a row shows it. The screen builds these from a
/// listing; [looksSecret] comes from `SecretNames`.
class FileRowModel {
  const FileRowModel({
    required this.name,
    required this.isFolder,
    this.looksSecret = false,
    this.path,
  });

  final String name;
  final bool isFolder;

  /// The name looks like it holds passwords or keys. Only a file is marked.
  final bool looksSecret;

  /// The path the server gave; the widget never reads it, so a screen can
  /// tell which row was tapped.
  final ServerPath? path;

  bool get marksSecret => looksSecret && !isFolder;

  FileGlyph get glyph => isFolder ? FileGlyph.folder : fileGlyphForName(name);
}

/// How a row reads: in a browsing list a folder ends in a chevron; in a list
/// that picks a folder the chosen row also shows a check mark and is announced
/// as a selected choice.
enum FileRowMode { browse, pick }

/// A row of the file list, on the metrics of a [GroupedSection] row.
///
/// It is not a `GroupedRow`: that cuts its title to one line and has no glyph
/// after it. The name takes up to two lines and is cut in the middle,
/// keeping its extension; at a large text size it wraps in full. A secret-
/// looking file gets a lock after its name and the line "May contain
/// secrets", so the warning is never colour or an icon alone; at a large text
/// size the lock moves under the name, in front of that line.
///
/// A touch row is 44 pt high (56 dp on Android); a Mac row is a 32 pt
/// pointer row. Put it in a [GroupedSection] with
/// `dividerIndent: GroupedMetrics.indentAfterLeading`.
class FileRow extends StatefulWidget {
  const FileRow({
    super.key,
    required this.model,
    required this.onTap,
    this.selected = false,
    this.mode = FileRowMode.browse,
    this.autofocus = false,
    this.focusNode,
  });

  final FileRowModel model;
  final VoidCallback? onTap;

  /// The row whose preview shows beside the list, or the folder chosen in a
  /// picker.
  final bool selected;
  final FileRowMode mode;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<FileRow> {
  bool _focused = false;

  String _label(AppLocalizations l10n) {
    final model = widget.model;
    if (model.isFolder) return l10n.filesRowLabelFolder(model.name);
    return model.marksSecret
        ? l10n.filesRowLabelFileSecret(model.name)
        : l10n.filesRowLabelFile(model.name);
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final l10n = context.l10n;
    final grouped = GroupedMetrics.of(context);
    final files = FilesMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final muted = colors.subtleText;
    final large = isLargeText(context);
    final secret = model.marksSecret;
    final nameStyle = TextStyle(
      fontSize: grouped.titleSize,
      color: scheme.onSurface,
    );
    final hintStyle = TextStyle(fontSize: grouped.subtitleSize, color: muted);
    // Glyphs grow with the text, but not as far as the text does.
    final glyphScale = textScaleOf(context).clamp(1.0, 1.5);
    final lockSize = grouped.subtitleSize * glyphScale;
    final name = MiddleEllipsisText(
      model.name,
      style: nameStyle,
      maxLines: large ? null : 2,
    );
    final text = Padding(
      padding: EdgeInsets.symmetric(vertical: grouped.rowVerticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (secret && !large)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: name),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: 6,
                    top: (grouped.titleSize * 1.25 - lockSize) / 2,
                  ),
                  child: AppIcon(AppIcons.lock, size: lockSize, color: muted),
                ),
              ],
            )
          else
            name,
          if (secret)
            large
                // The lock is part of the text line, level with it.
                ? Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 4),
                            child: AppIcon(
                              AppIcons.lock,
                              size: lockSize,
                              color: muted,
                            ),
                          ),
                        ),
                        TextSpan(text: l10n.filesRowSecretHint),
                      ],
                    ),
                    style: hintStyle,
                  )
                : Text(l10n.filesRowSecretHint, style: hintStyle),
        ],
      ),
    );
    final picked = widget.mode == FileRowMode.pick;
    final hasTrailing = model.isFolder || (picked && widget.selected);
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (picked && widget.selected)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: AppIcon(AppIcons.check, size: 20, color: scheme.primary),
          ),
        if (model.isFolder)
          AppIcon(
            AppIcons.chevronRight,
            size:
                (platformChromeOf(context).isApple
                    ? grouped.titleSize - 1
                    : 20) *
                glyphScale,
            color: muted,
          ),
      ],
    );
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: files.rowMinHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: grouped.rowPadding),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(end: grouped.leadingGap),
              child: ExcludeSemantics(
                child: AppIcon(
                  model.glyph.icon,
                  size: grouped.leadingSize * glyphScale,
                  color: model.isFolder ? colors.link : muted,
                ),
              ),
            ),
            Expanded(child: text),
            if (hasTrailing)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: ExcludeSemantics(child: trailing),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: widget.selected,
      inMutuallyExclusiveGroup: picked,
      label: _label(l10n),
      child: Material(
        color: widget.selected ? scheme.outline : Colors.transparent,
        child: Container(
          foregroundDecoration: _focused
              ? BoxDecoration(
                  border: Border.all(color: scheme.primary, width: 2),
                )
              : null,
          child: InkWell(
            onTap: widget.onTap,
            autofocus: widget.autofocus,
            focusNode: widget.focusNode,
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: ExcludeSemantics(child: content),
          ),
        ),
      ),
    );
  }
}
