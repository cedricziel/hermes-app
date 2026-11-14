import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/hermes_theme.dart';
import '../theme/platform_chrome.dart';
import 'grouped_list.dart';

/// The one-line "What's the difference?" link that ends the footer of the
/// Tools, Skills, Plugins, MCP servers and Helper models screens. The caller
/// opens the explanation; the link has no state of its own.
class WhatsTheDifferenceLink extends StatelessWidget {
  const WhatsTheDifferenceLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final target = switch (platformChromeOf(context)) {
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.material => 48.0,
      PlatformChrome.macos => 28.0,
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        link: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: target),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: Text(
                context.l10n.toolsFooterLink,
                style: TextStyle(
                  fontSize: metrics.footerSize,
                  color: context.hermesColors.link,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [WhatsTheDifferenceLink] as the last line under a list, in line with the
/// text of the group footers above it.
class WhatsTheDifferenceFooter extends StatelessWidget {
  const WhatsTheDifferenceFooter({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inset = GroupedMetrics.of(context).rowPadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 6, inset, 0),
      child: WhatsTheDifferenceLink(onTap: onTap),
    );
  }
}
