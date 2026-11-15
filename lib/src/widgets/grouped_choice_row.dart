import 'package:flutter/material.dart';

import '../theme/platform_chrome.dart';
import 'grouped_list.dart';

/// The width of a shrink-wrapped Material radio button.
const _radioSize = 40.0;

/// One option of a choice in a [GroupedSection]: a check mark at the trailing
/// edge on Apple platforms, a radio button at the leading edge on Material.
///
/// The rows of one choice sit under a [RadioGroup] of [T], which holds the
/// picked value and is told when a row is tapped. The section passes
/// [GroupedChoiceRow.dividerIndent] so separators start past the radio.
class GroupedChoiceRow<T> extends StatelessWidget {
  const GroupedChoiceRow({
    super.key,
    required this.value,
    required this.title,
    this.titleMaxLines = 1,
    this.subtitle,
    this.subtitleMaxLines = 1,
    this.titleMiddleEllipsis = false,
    this.subtitleMiddleEllipsis = false,
    this.meta,
    this.warning,
    this.details = const [],
    this.enabled = true,
    this.autofocus = false,
    this.rowFocusable = true,
    this.focusNode,
  });

  final T value;
  final String title;
  final int? titleMaxLines;
  final String? subtitle;

  /// How many lines the [subtitle] may take; null lets it wrap in full.
  final int? subtitleMaxLines;

  /// Cut the title or the subtitle in the middle, for an identifier. See
  /// [GroupedRow.titleMiddleEllipsis].
  final bool titleMiddleEllipsis;
  final bool subtitleMiddleEllipsis;
  final String? meta;
  final String? warning;

  /// Widgets under the subtitle, such as a path cut in the middle.
  final List<Widget> details;
  final bool enabled;

  /// Takes the keyboard focus when it is built, for the checked row of a
  /// popover.
  final bool autofocus;

  /// Whether the row's own tap target is a second keyboard stop beside the
  /// radio. Off in a popover, where the arrows walk the rows and, with a
  /// [focusNode], the focus is drawn across the row.
  final bool rowFocusable;

  /// The radio's focus node, for a caller that moves focus between rows.
  final FocusNode? focusNode;

  /// Where the separators of a group of choice rows start: past the radio
  /// button on Material, at the text on Apple platforms.
  static double? dividerIndent(BuildContext context) {
    if (platformChromeOf(context).isApple) return null;
    final metrics = GroupedMetrics.of(context);
    return metrics.rowPadding + _radioSize + metrics.leadingGap;
  }

  @override
  Widget build(BuildContext context) {
    final apple = platformChromeOf(context).isApple;
    final group = RadioGroup.maybeOf<T>(context);
    final radio = Radio<T>.adaptive(
      value: value,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      useCupertinoCheckmarkStyle: true,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final row = GroupedRow(
      title: title,
      titleMaxLines: titleMaxLines,
      subtitle: subtitle,
      subtitleMaxLines: subtitleMaxLines,
      titleMiddleEllipsis: titleMiddleEllipsis,
      subtitleMiddleEllipsis: subtitleMiddleEllipsis,
      meta: meta,
      warning: warning,
      details: details,
      leading: apple ? null : radio,
      trailing: apple ? radio : null,
      chevron: false,
      focusable: rowFocusable,
      checked: group?.groupValue == value,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      onTap: group == null ? null : () => group.onChanged(value),
    );
    // With the radio as the row's only focus stop, the focus is drawn across
    // the whole row, not only on the radio circle.
    final node = focusNode;
    if (rowFocusable || node == null) return row;
    final tint = Theme.of(context).colorScheme.primary.withValues(alpha: .14);
    return ListenableBuilder(
      listenable: node,
      child: row,
      builder: (context, child) => DecoratedBox(
        key: const Key('row-focus-highlight'),
        decoration: BoxDecoration(
          color: node.hasFocus ? tint : Colors.transparent,
        ),
        child: child,
      ),
    );
  }
}
