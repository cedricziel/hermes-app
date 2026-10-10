import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';

/// The sizes of a grouped settings list on one platform: iOS inset grouped
/// lists, the Mac's 600 point column, and Material cards.
class GroupedMetrics {
  const GroupedMetrics._({
    required this.gutter,
    required this.maxWidth,
    required this.radius,
    required this.rowMinHeight,
    required this.rowPadding,
    required this.rowVerticalPadding,
    required this.titleSize,
    required this.subtitleSize,
    required this.headerSize,
    required this.headerWeight,
    required this.headerUppercase,
    required this.footerSize,
    required this.sectionGap,
    required this.leadingGap,
    required this.tileSize,
    required this.tileRadius,
    required this.tileIconSize,
  });

  static const ios = GroupedMetrics._(
    gutter: 16,
    maxWidth: 640,
    radius: 12,
    rowMinHeight: 44,
    rowPadding: 16,
    rowVerticalPadding: 6,
    titleSize: 17,
    subtitleSize: 15,
    headerSize: 13,
    headerWeight: FontWeight.w400,
    headerUppercase: true,
    footerSize: 13,
    sectionGap: 24,
    leadingGap: 12,
    tileSize: 29,
    tileRadius: 7,
    tileIconSize: 18,
  );

  static const macos = GroupedMetrics._(
    gutter: 20,
    maxWidth: 600,
    radius: 10,
    rowMinHeight: 40,
    rowPadding: 12,
    rowVerticalPadding: 6,
    titleSize: 13,
    subtitleSize: 11,
    headerSize: 11,
    headerWeight: FontWeight.w600,
    headerUppercase: false,
    footerSize: 11,
    sectionGap: 20,
    leadingGap: 10,
    tileSize: 24,
    tileRadius: 6,
    tileIconSize: 14,
  );

  static const material = GroupedMetrics._(
    gutter: 16,
    maxWidth: 640,
    radius: 14,
    rowMinHeight: 56,
    rowPadding: 16,
    rowVerticalPadding: 10,
    titleSize: 16,
    subtitleSize: 14,
    headerSize: 13,
    headerWeight: FontWeight.w600,
    headerUppercase: false,
    footerSize: 13,
    sectionGap: 20,
    leadingGap: 16,
    tileSize: 32,
    tileRadius: 10,
    tileIconSize: 20,
  );

  static GroupedMetrics of(BuildContext context) =>
      switch (platformChromeOf(context)) {
        PlatformChrome.ios => ios,
        PlatformChrome.macos => macos,
        PlatformChrome.material => material,
      };

  /// The space between a group and the page's edge.
  final double gutter;

  /// The widest a group gets; a wider page centers it.
  final double maxWidth;
  final double radius;
  final double rowMinHeight;

  /// The space between a row's content and the group's edge, which is also
  /// where a separator starts.
  final double rowPadding;

  /// The space above and below a row's text.
  final double rowVerticalPadding;
  final double titleSize;
  final double subtitleSize;
  final double headerSize;
  final FontWeight headerWeight;
  final bool headerUppercase;
  final double footerSize;

  /// The space above a section with a header.
  final double sectionGap;

  /// The size of a row's leading icon.
  double get leadingSize => titleSize + 5;

  /// The space between a row's leading icon or tile and its text.
  final double leadingGap;

  /// The side of a [GroupedTile].
  final double tileSize;
  final double tileRadius;
  final double tileIconSize;

  /// A [GroupedSection.dividerIndent] that starts the separators at the text
  /// of rows with a leading icon.
  double get indentAfterLeading => rowPadding + leadingSize + leadingGap;

  /// A [GroupedSection.dividerIndent] for rows that lead with a
  /// [GroupedTile].
  double get indentAfterTile => rowPadding + tileSize + leadingGap;
}

/// A scrolling page of [GroupedSection]s: the groups keep the platform's
/// gutter and stay at [GroupedMetrics.maxWidth], centered on a wide page,
/// while the whole page width scrolls.
class GroupedListView extends StatelessWidget {
  const GroupedListView({
    super.key,
    required this.children,
    this.controller,
    this.physics,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(
          metrics.gutter,
          (box.maxWidth - metrics.maxWidth) / 2,
        );
        return ListView(
          controller: controller,
          physics: physics,
          padding: EdgeInsets.fromLTRB(side, 0, side, 32),
          children: children,
        );
      },
    );
  }
}

/// A group of rows with a hairline border, separators inset to the rows'
/// text, an optional [header] above and a [footer] explaining it below.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.dividerIndent,
  });

  final String? header;

  /// A note under the group, such as what its rows do.
  final String? footer;
  final List<Widget> children;

  /// Where the separators start, measured from the group's edge; the row
  /// padding when null. Rows with a leading icon pass
  /// [GroupedMetrics.indentAfterLeading].
  final double? dividerIndent;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final header = this.header;
    final footer = this.footer;
    final radius = BorderRadius.circular(metrics.radius);
    final divider = Divider(
      height: 1,
      indent: dividerIndent ?? metrics.rowPadding,
      color: scheme.outlineVariant,
    );
    return Padding(
      padding: EdgeInsets.only(top: header == null ? 8 : metrics.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.rowPadding,
                0,
                metrics.rowPadding,
                6,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  metrics.headerUppercase ? header.toUpperCase() : header,
                  style: TextStyle(
                    fontSize: metrics.headerSize,
                    fontWeight: metrics.headerWeight,
                    color: muted,
                  ),
                ),
              ),
            ),
          Material(
            color: scheme.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: scheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) divider,
                  child,
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.rowPadding,
                6,
                metrics.rowPadding,
                0,
              ),
              child: Text(
                footer,
                style: TextStyle(fontSize: metrics.footerSize, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// A row of a [GroupedSection]: a [title] with optional inline [meta] (a
/// version), a [subtitle] (one line unless [subtitleMaxLines] says more) and
/// [warning] and [error] lines under it, which wrap, and at the
/// trailing edge a muted [value] with a disclosure chevron, or [trailing]
/// (a switch) in their place.
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.title,
    this.meta,
    this.subtitle,
    this.subtitleMaxLines = 1,
    this.monospaceSubtitle = false,
    this.caption,
    this.warning,
    this.error,
    this.leading,
    this.value,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.checked,
    this.inMutuallyExclusiveGroup = false,
    this.chevron,
    this.selected = false,
    this.destructive = false,
  });

  final String title;

  /// Muted text right after the title, such as "v1.2.0".
  final String? meta;
  final String? subtitle;

  /// How many lines the [subtitle] may take before it ends in an ellipsis;
  /// null lets it wrap, for text with nowhere else to be read.
  final int? subtitleMaxLines;

  /// Sets [subtitle] in a monospaced font, for a command line.
  final bool monospaceSubtitle;

  /// A smaller muted line under the subtitle, such as "Remote · OAuth".
  final String? caption;

  /// A line in the warning colour, such as why a plugin cannot load.
  final String? warning;

  /// A line in the error colour, such as a rejected bot token.
  final String? error;

  /// An icon, or a [GroupedTile].
  final Widget? leading;

  /// A status in muted text before the chevron, such as "Off" or "3 tools".
  final String? value;

  /// Takes the place of the chevron, such as a switch.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// False ignores [onTap] while the row still reads as a button, a
  /// disabled one. Dimming the row is up to the caller.
  final bool enabled;

  /// Makes the row a checkbox, or with [inMutuallyExclusiveGroup] a radio
  /// button, in this state. Its [leading] or [trailing] mark is then only
  /// a picture of that state, so the row stays one node.
  final bool? checked;
  final bool inMutuallyExclusiveGroup;

  /// Whether to draw the disclosure chevron; by default when the row opens
  /// something ([onTap]) and has no [trailing].
  final bool? chevron;

  /// Highlights the row whose details show beside the list.
  final bool selected;

  /// Draws the title in the error colour, for a row such as "Remove".
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.hermesColors;
    final muted = colors.subtleText;
    final apple = platformChromeOf(context).isApple;
    final meta = this.meta;
    final subtitle = this.subtitle;
    final caption = this.caption;
    final warning = this.warning;
    final error = this.error;
    // A checked row's mark only pictures the state the row announces.
    Widget? mark(Widget? child) => child == null || checked == null
        ? child
        : ExcludeSemantics(child: child);
    final leading = mark(this.leading);
    final value = this.value;
    final trailing = mark(this.trailing);
    final showChevron = chevron ?? (onTap != null && trailing == null);
    // A control beside a row that opens something stays its own node, so a
    // screen reader can both open the row and flip the switch.
    final trailingApart = trailing != null && onTap != null && checked == null;
    final titleStyle = TextStyle(
      fontSize: metrics.titleSize,
      color: destructive ? scheme.error : scheme.onSurface,
    );
    Widget row({double? valueWidth}) => Row(
      children: [
        if (leading != null) ...[
          IconTheme.merge(
            data: IconThemeData(color: muted, size: metrics.leadingSize),
            child: leading,
          ),
          SizedBox(width: metrics.leadingGap),
        ],
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: metrics.rowVerticalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      if (meta != null)
                        TextSpan(
                          text: '  $meta',
                          style: TextStyle(
                            fontSize: metrics.subtitleSize,
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: subtitleMaxLines,
                    overflow: subtitleMaxLines == null
                        ? null
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: monospaceSubtitle
                          ? metrics.footerSize
                          : metrics.subtitleSize,
                      fontFamily: monospaceSubtitle ? 'monospace' : null,
                      color: muted,
                    ),
                  ),
                if (caption != null)
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: metrics.footerSize,
                      color: muted,
                    ),
                  ),
                if (warning != null)
                  _StatusLine(
                    icon: AppIcons.warning,
                    text: warning,
                    color: colors.warning,
                    size: metrics.subtitleSize,
                  ),
                if (error != null)
                  _StatusLine(
                    icon: AppIcons.error,
                    text: error,
                    color: scheme.error,
                    size: metrics.subtitleSize,
                  ),
              ],
            ),
          ),
        ),
        if (value != null)
          // At most half the row, so a long value cannot push the
          // title out.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: valueWidth!),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: metrics.subtitleSize, color: muted),
              ),
            ),
          ),
        if (trailing != null && !trailingApart)
          Padding(padding: const EdgeInsets.only(left: 8), child: trailing),
        if (showChevron)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: AppIcon(
              AppIcons.chevronRight,
              key: const Key('grouped-row-chevron'),
              size: apple ? metrics.titleSize - 1 : 20,
              color: muted,
            ),
          ),
      ],
    );
    // Only the text is padded, so a switch beside it keeps the row's height.
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: metrics.rowPadding,
          end: trailingApart ? 0 : metrics.rowPadding,
        ),
        child: value == null
            ? row()
            : LayoutBuilder(
                builder: (context, box) => row(valueWidth: box.maxWidth / 2),
              ),
      ),
    );
    final ink = InkWell(onTap: enabled ? onTap : null, child: content);
    final color = selected ? scheme.outline : Colors.transparent;
    Widget merged(Widget child) => MergeSemantics(
      child: Semantics(
        button: onTap != null && checked == null,
        enabled: onTap != null ? enabled : null,
        checked: checked,
        inMutuallyExclusiveGroup: inMutuallyExclusiveGroup,
        selected: selected,
        child: child,
      ),
    );
    if (!trailingApart) {
      return merged(Material(color: color, child: ink));
    }
    return Material(
      color: color,
      child: Row(
        children: [
          Expanded(child: merged(ink)),
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: 8,
              end: metrics.rowPadding,
            ),
            child: trailing,
          ),
        ],
      ),
    );
  }
}

/// A [GroupedRow] whose trailing control is a switch named by its title.
class GroupedSwitchRow extends StatelessWidget {
  const GroupedSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.subtitleMaxLines = 1,
    this.monospaceSubtitle = false,
    this.meta,
    this.caption,
    this.warning,
    this.error,
    this.leading,
    this.onTap,
    this.selected = false,
  });

  final String title;
  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  final int? subtitleMaxLines;
  final bool monospaceSubtitle;
  final String? meta;
  final String? caption;
  final String? warning;
  final String? error;
  final Widget? leading;

  /// Opens the row's details; the switch alone changes [value].
  final VoidCallback? onTap;

  /// Highlights the row whose details show beside the list.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    Widget control = Switch.adaptive(
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    // Beside a row that opens details the switch is its own node, so it
    // carries the title itself.
    if (onTap != null) {
      control = MergeSemantics(
        child: Semantics(label: title, child: control),
      );
    }
    return GroupedRow(
      title: title,
      subtitle: subtitle,
      subtitleMaxLines: subtitleMaxLines,
      monospaceSubtitle: monospaceSubtitle,
      meta: meta,
      caption: caption,
      warning: warning,
      error: error,
      leading: leading,
      onTap: onTap,
      selected: selected,
      chevron: false,
      // A Mac settings row holds the small switch.
      trailing: platformChromeOf(context) == PlatformChrome.macos
          ? SizedBox(height: 22, child: FittedBox(child: control))
          : control,
    );
  }
}

/// A warning or error line. It wraps, since it often says what to fix and
/// the row has nowhere else to show it.
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      spacing: 4,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level with the first line of text.
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: AppIcon(icon, size: size, color: color),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: size, color: color),
          ),
        ),
      ],
    ),
  );
}

/// A row's leading picture in a rounded square, such as a platform's icon
/// or a server's initial; the section passes
/// [GroupedMetrics.indentAfterTile] so separators start past it. A screen
/// reader skips it, since the row's title already names what it shows.
class GroupedTile extends StatelessWidget {
  const GroupedTile({super.key, required this.child});

  /// An icon or a letter; both are sized to the tile.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: metrics.tileSize,
        height: metrics.tileSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(metrics.tileRadius),
        ),
        child: IconTheme.merge(
          data: IconThemeData(
            size: metrics.tileIconSize,
            color: scheme.onSurface,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: metrics.tileIconSize * 0.75,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
