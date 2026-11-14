import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';

/// A row that opens and closes the [children] below it: "Change setup" with
/// the active provider as its [value], or Web's "Use different providers for
/// search and extract". [expanded] and [onExpandedChanged] are the caller's,
/// so what the user opened stays open while the screen rebuilds.
class ToolsDisclosure extends StatelessWidget {
  const ToolsDisclosure({
    super.key,
    required this.title,
    required this.expanded,
    required this.onExpandedChanged,
    required this.children,
    this.value,
  });

  final String title;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  /// Muted text before the chevron.
  final String? value;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.hermesColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSection(
          children: [
            Semantics(
              expanded: expanded,
              child: GroupedRow(
                title: title,
                titleMaxLines: null,
                value: value,
                trailing: AppIcon(
                  expanded ? AppIcons.expandLess : AppIcons.expandMore,
                  size: 20,
                  color: colors.subtleText,
                ),
                onTap: () => onExpandedChanged(!expanded),
              ),
            ),
          ],
        ),
        if (expanded) ...children,
      ],
    );
  }
}
