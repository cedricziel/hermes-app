import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/app_banner.dart';
import '../bot_chat_context.dart';

/// Compact identity and capability context for a durable specialist chat.
class BotChatBanner extends StatelessWidget {
  const BotChatBanner({super.key, required this.context});
  final BotChatContext context;
  @override
  Widget build(BuildContext buildContext) {
    final unavailable = !context.protocolEnabled;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: AppBanner(
            tone: AppBannerTone.neutral,
            icon: AppIcons.bot,
            title: context.title,
            detail: unavailable
                ? '@${context.handle} · Bot Chat\n'
                      'Teammate messaging is unavailable on this backend.'
                : '@${context.handle} · Bot Chat',
            // Part of the page from the start, not news.
            liveRegion: false,
          ),
        ),
      ),
    );
  }
}
