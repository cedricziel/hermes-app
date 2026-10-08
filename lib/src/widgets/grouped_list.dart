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

  /// The space between a row's leading icon and its text.
  double get leadingGap => rowPadding * 0.75;

  /// A [GroupedSection.dividerIndent] that starts the separators at the text
  /// of rows with a leading icon.
  double get indentAfterLeading => rowPadding + leadingSize + leadingGap;
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
/// version), a one-line [subtitle] and a [warning] line under it, and at the
/// trailing edge a muted [value] with a disclosure chevron, or [trailing]
/// (a switch) in their place.
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.title,
    this.meta,
    this.subtitle,
    this.warning,
    this.leading,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron,
    this.selected = false,
    this.destructive = false,
  });

  final String title;

  /// Muted text right after the title, such as "v1.2.0".
  final String? meta;
  final String? subtitle;

  /// A line in the warning colour, such as why a plugin cannot load.
  final String? warning;
  final Widget? leading;

  /// A status in muted text before the chevron, such as "Off" or "3 tools".
  final String? value;

  /// Takes the place of the chevron, such as a switch.
  final Widget? trailing;
  final VoidCallback? onTap;

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
    final warning = this.warning;
    final leading = this.leading;
    final value = this.value;
    final trailing = this.trailing;
    final showChevron = chevron ?? (onTap != null && trailing == null);
    final titleStyle = TextStyle(
      fontSize: metrics.titleSize,
      color: destructive ? scheme.error : scheme.onSurface,
    );
    // Only the text is padded, so a switch beside it keeps the row's height.
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
        child: Row(
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
                padding: EdgeInsets.symmetric(
                  vertical: metrics.rowVerticalPadding,
                ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: metrics.subtitleSize,
                          color: muted,
                        ),
                      ),
                    if (warning != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          spacing: 4,
                          children: [
                            AppIcon(
                              AppIcons.warning,
                              size: metrics.subtitleSize,
                              color: colors.warning,
                            ),
                            Expanded(
                              child: Text(
                                warning,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: metrics.subtitleSize,
                                  color: colors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: metrics.subtitleSize,
                    color: muted,
                  ),
                ),
              ),
            if (trailing != null)
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
        ),
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        selected: selected,
        child: Material(
          color: selected ? scheme.outline : Colors.transparent,
          child: InkWell(onTap: onTap, child: content),
        ),
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
    this.meta,
    this.warning,
    this.leading,
    this.onTap,
  });

  final String title;
  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  final String? meta;
  final String? warning;
  final Widget? leading;

  /// Opens the row's details; the switch alone changes [value].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final control = Switch.adaptive(
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return GroupedRow(
      title: title,
      subtitle: subtitle,
      meta: meta,
      warning: warning,
      leading: leading,
      onTap: onTap,
      chevron: false,
      // A Mac settings row holds the small switch.
      trailing: platformChromeOf(context) == PlatformChrome.macos
          ? SizedBox(height: 22, child: FittedBox(child: control))
          : control,
    );
  }
}
