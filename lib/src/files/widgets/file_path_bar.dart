import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/named_icon_button.dart';
import '../server_path.dart';
import 'files_metrics.dart';
import 'middle_ellipsis.dart';

/// A segment longer than this many characters is cut in the middle.
const int kPathSegmentMaxChars = 24;

bool _sameFolder(ServerPath a, ServerPath b) => a.isWithin(b) && b.isWithin(a);

/// The folders of a path bar from [highest] down to [current], each as the
/// path that opens it. Without a [highest], or when [current] lies outside
/// it, the bar starts at the root.
List<ServerPath> pathBarFolders(ServerPath current, ServerPath? highest) {
  final chain = <ServerPath>[];
  for (ServerPath? path = current; path != null; path = path.parent) {
    chain.add(path);
    if (highest != null && _sameFolder(path, highest)) break;
  }
  return chain.reversed.toList();
}

String _segmentLabel(ServerPath path) => path.isRoot ? path.value : path.name;

/// The breadcrumb of the folder the page shows: each folder from the highest
/// one down to the current one, as a link-coloured text button, with the
/// current folder in semibold and not a button. A long name is cut in the
/// middle. A path too long for the strip shows its end, with a fade at the
/// start, and scrolls back; the strip scrolls at the largest text size.
///
/// Wide layouts start with an Up button, [showUp], disabled when [onUp] is
/// null (the highest folder). Every segment is a keyboard-focusable button
/// whose accessible name is its full path; on a Mac its tooltip is that path.
/// Targets are 44 pt (Apple touch), 48 dp (Material) and 28 pt (Mac).
///
/// It takes paths and callbacks only, so the working-folder picker reuses it.
class FilePathBar extends StatefulWidget {
  const FilePathBar({
    super.key,
    required this.current,
    this.highest,
    required this.onOpen,
    this.onUp,
    this.showUp = false,
  });

  final ServerPath current;

  /// The folder the page may not leave; the first segment.
  final ServerPath? highest;

  /// Opens an ancestor of [current].
  final ValueChanged<ServerPath> onOpen;

  /// Goes up one folder; null disables the Up button.
  final VoidCallback? onUp;

  /// Whether the strip starts with an Up button (wide layouts).
  final bool showUp;

  @override
  State<FilePathBar> createState() => _FilePathBarState();
}

class _FilePathBarState extends State<FilePathBar> {
  static const _fade = 28.0;

  final _scroll = ScrollController();
  bool _hiddenBefore = false;
  bool _hiddenAfter = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // The strip is reversed, so offset zero shows its end: content cut off at
  // the start sits at the larger offsets.
  bool _update(ScrollMetrics metrics) {
    final before = metrics.pixels < metrics.maxScrollExtent - 0.5;
    final after = metrics.pixels > 0.5;
    if (before == _hiddenBefore && after == _hiddenAfter) return false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _hiddenBefore = before;
        _hiddenAfter = after;
      });
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final files = FilesMetrics.of(context);
    final grouped = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final folders = pathBarFolders(widget.current, widget.highest);
    final fontSize = grouped.titleSize - (files.pointer ? 0 : 1);
    final segments = <Widget>[];
    for (final (i, folder) in folders.indexed) {
      final last = i == folders.length - 1;
      if (i > 0) {
        segments.add(
          ExcludeSemantics(
            child: AppIcon(
              AppIcons.chevronRight,
              size: 16,
              color: colors.subtleText,
            ),
          ),
        );
      }
      final label = elideMiddle(
        _segmentLabel(folder),
        maxChars: kPathSegmentMaxChars,
      );
      segments.add(
        last
            ? _CurrentSegment(
                label: label,
                path: folder.value,
                height: files.target,
                fontSize: fontSize,
              )
            : _LinkSegment(
                label: label,
                path: folder.value,
                files: files,
                fontSize: fontSize,
                onPressed: () => widget.onOpen(folder),
              ),
      );
    }
    final strip = LayoutBuilder(
      builder: (context, box) =>
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) => _update(n.metrics),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => _update(n.metrics),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    key: const Key('path-bar-scroll'),
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: box.maxWidth),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: segments,
                      ),
                    ),
                  ),
                  if (_hiddenBefore)
                    _Fade(
                      key: const Key('path-bar-fade-start'),
                      color: scheme.surface,
                      atStart: true,
                    ),
                  if (_hiddenAfter)
                    _Fade(
                      key: const Key('path-bar-fade-end'),
                      color: scheme.surface,
                      atStart: false,
                    ),
                ],
              ),
            ),
          ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.filesPathBarLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: files.target),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: files.pointer ? 8 : 4),
            child: Row(
              children: [
                if (widget.showUp)
                  NamedIconButton(
                    key: const Key('path-bar-up'),
                    label: l10n.filesActionUp,
                    tooltip: files.pointer ? l10n.filesActionUpTooltip : null,
                    icon: const AppIconSet(
                      Icons.arrow_upward,
                      CupertinoIcons.arrow_up,
                    ),
                    iconSize: files.pointer ? 16 : 22,
                    padding: EdgeInsets.zero,
                    style: files.iconButtonStyle(),
                    onPressed: widget.onUp,
                  ),
                Expanded(child: strip),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip's edge where more path is hidden, fading into its background.
class _Fade extends StatelessWidget {
  const _Fade({super.key, required this.color, required this.atStart});

  final Color color;
  final bool atStart;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: atStart
          ? [color, color.withValues(alpha: 0)]
          : [color.withValues(alpha: 0), color],
    );
    return PositionedDirectional(
      start: atStart ? 0 : null,
      end: atStart ? null : 0,
      top: 0,
      bottom: 0,
      width: _FilePathBarState._fade,
      child: IgnorePointer(
        child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
      ),
    );
  }
}

class _LinkSegment extends StatelessWidget {
  const _LinkSegment({
    required this.label,
    required this.path,
    required this.files,
    required this.fontSize,
    required this.onPressed,
  });

  final String label;
  final String path;
  final FilesMetrics files;
  final double fontSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final link = context.hermesColors.link;
    return Tooltip(
      message: path,
      excludeFromSemantics: true,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          label: l10n.filesPathSegmentLabel(path),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: link,
              minimumSize: Size(files.target, files.target),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontSize: fontSize),
            ),
            child: ExcludeSemantics(
              child: Text(label, maxLines: 1, softWrap: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentSegment extends StatelessWidget {
  const _CurrentSegment({
    required this.label,
    required this.path,
    required this.height,
    required this.fontSize,
  });

  final String label;
  final String path;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: path,
    excludeFromSemantics: true,
    child: Semantics(
      label: context.l10n.filesPathCurrentLabel(path),
      excludeSemantics: true,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    ),
  );
}
