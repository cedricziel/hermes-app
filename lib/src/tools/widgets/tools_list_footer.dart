import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/whats_the_difference_link.dart';

/// The note under the tools list: when a change applies, and a link to what
/// tools, skills, plugins and MCP servers are.
class ToolsListFooter extends StatelessWidget {
  const ToolsListFooter({super.key, required this.onWhatsTheDifference});

  final VoidCallback onWhatsTheDifference;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        8,
        metrics.rowPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.toolsFooterBody,
            style: TextStyle(
              fontSize: metrics.footerSize,
              color: colors.subtleText,
            ),
          ),
          WhatsTheDifferenceLink(onTap: onWhatsTheDifference),
        ],
      ),
    );
  }
}
