import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';

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
    final target = switch (platformChromeOf(context)) {
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.material => 48.0,
      PlatformChrome.macos => 28.0,
    };
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
          Semantics(
            link: true,
            child: InkWell(
              onTap: onWhatsTheDifference,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: target),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.toolsFooterLink,
                    style: TextStyle(
                      fontSize: metrics.footerSize,
                      color: colors.link,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
