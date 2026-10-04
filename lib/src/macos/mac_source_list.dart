import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';

/// The height of a row in a Mac sidebar.
const double kMacSourceListRowHeight = 28;

/// The fill of a selected source-list row, as if it were held down.
Color macSourceListSelectedFill(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);

/// The fill of a source-list row under the pointer.
Color macSourceListHoverFill(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05);

/// The rounded 28pt shell of a Mac sidebar row: the selected fill, a hover
/// fill, and what [builder] puts in it, told whether the pointer is over it.
class MacSourceListTile extends StatefulWidget {
  const MacSourceListTile({
    super.key,
    required this.builder,
    required this.onTap,
    this.selected = false,
    this.onSecondaryTapUp,
    this.height = kMacSourceListRowHeight,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final double height;
  final VoidCallback onTap;
  final bool selected;
  final GestureTapUpCallback? onSecondaryTapUp;

  @override
  State<MacSourceListTile> createState() => _MacSourceListTileState();
}

class _MacSourceListTileState extends State<MacSourceListTile> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(6);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        child: Material(
          color: widget.selected
              ? macSourceListSelectedFill(context)
              : _hovered
              ? macSourceListHoverFill(context)
              : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: SizedBox(
              height: widget.height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: widget.builder(context, _hovered),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A destination in a Mac sidebar: a 16pt muted icon and a 13pt label, with
/// an optional muted [caption] at the trailing edge.
class MacSourceListRow extends StatelessWidget {
  const MacSourceListRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.caption,
  });

  final AppIconSet icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final caption = this.caption;
    return Semantics(
      button: true,
      selected: selected,
      child: MacSourceListTile(
        selected: selected,
        onTap: onTap,
        builder: (context, _) => Row(
          children: [
            AppIcon(icon, size: 16, color: subtle),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (caption != null)
              Text(caption, style: TextStyle(fontSize: 11, color: subtle)),
          ],
        ),
      ),
    );
  }
}

/// The 11pt bold muted text of a Mac sidebar's section headers.
TextStyle macSectionHeaderStyle(BuildContext context) => TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: context.hermesColors.subtleText,
);

/// The header of a section of a Mac sidebar. A click folds the section away
/// or opens it again; the chevron shows on hover, turned while folded.
class MacSidebarSectionHeader extends StatefulWidget {
  const MacSidebarSectionHeader({
    super.key,
    required this.label,
    required this.collapsed,
    required this.onToggle,
    this.count,
  });

  final String label;
  final int? count;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  State<MacSidebarSectionHeader> createState() =>
      _MacSidebarSectionHeaderState();
}

class _MacSidebarSectionHeaderState extends State<MacSidebarSectionHeader> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    return Semantics(
      button: true,
      expanded: !widget.collapsed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: macSectionHeaderStyle(context),
                  ),
                ),
                if (widget.count != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${widget.count}',
                    style: macSectionHeaderStyle(context),
                  ),
                  const SizedBox(width: 4),
                ],
                Opacity(
                  opacity: _hovered ? 1 : 0,
                  child: AnimatedRotation(
                    turns: widget.collapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: AppIcon(
                      AppIcons.expandMore,
                      size: 14,
                      color: subtle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
