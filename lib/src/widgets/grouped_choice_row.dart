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
    this.subtitle,
    this.meta,
    this.warning,
    this.enabled = true,
  });

  final T value;
  final String title;
  final String? subtitle;
  final String? meta;
  final String? warning;
  final bool enabled;

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
      useCupertinoCheckmarkStyle: true,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return GroupedRow(
      title: title,
      subtitle: subtitle,
      meta: meta,
      warning: warning,
      leading: apple ? null : radio,
      trailing: apple ? radio : null,
      chevron: false,
      checked: group?.groupValue == value,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      onTap: group == null ? null : () => group.onChanged(value),
    );
  }
}
