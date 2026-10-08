import 'package:flutter/material.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/messaging_screen.dart';
import 'package:hermes_app/src/messaging/messaging_setup_screen.dart';
import 'package:hermes_app/src/messaging/telegram_pairing_screen.dart';
import 'package:hermes_app/src/messaging/widgets/messaging_platform_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'host.dart';
import 'skills_messaging_use_cases.dart' show skillsServer;

const _platforms = {
  'iPhone': TargetPlatform.iOS,
  'Mac': TargetPlatform.macOS,
  'Material': TargetPlatform.android,
};

Widget _on(BuildContext context, TargetPlatform platform, Widget child) =>
    Theme(
      data: Theme.of(context).copyWith(platform: platform),
      child: child,
    );

WidgetbookUseCase _messaging(
  String name,
  Widget Function(HermesMessagingRepository r) b,
) => WidgetbookUseCase(
  name: name,
  builder: (_) => Hosted<HermesMessagingRepository>(
    create: () => HermesMessagingRepository(skillsServer().client().raw),
    builder: (_, repository) => b(repository),
  ),
);

const _rows = [
  HermesMessagingPlatform(
    id: 'telegram',
    name: 'Telegram',
    description: 'Run Hermes from Telegram.',
    enabled: true,
    configured: true,
  ),
  HermesMessagingPlatform(
    id: 'discord',
    name: 'Discord',
    description: 'Chat with Hermes on a Discord server.',
    configured: true,
  ),
  HermesMessagingPlatform(id: 'whatsapp', name: 'WhatsApp'),
  HermesMessagingPlatform(
    id: 'signal',
    name: 'Signal',
    description: 'Talk to Hermes over Signal.',
    enabled: true,
  ),
  HermesMessagingPlatform(
    id: 'slack',
    name: 'Slack',
    enabled: true,
    configured: true,
    errorMessage: 'Invalid bot token',
  ),
];

class _RowGroup extends StatelessWidget {
  const _RowGroup();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GroupedListView(
      children: [
        GroupedSection(
          dividerIndent: GroupedMetrics.of(context).indentAfterTile,
          children: [
            for (final platform in _rows)
              MessagingPlatformRow(
                platform: platform,
                onSetUp: () {},
                onToggle: (_) {},
              ),
          ],
        ),
      ],
    ),
  );
}

/// The screen pushed over a chat, so its bar has a back button.
Widget _pushed(Widget page) => Navigator(
  onGenerateInitialRoutes: (_, _) => [
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('Chat'))),
    ),
    MaterialPageRoute<void>(builder: (_) => page),
  ],
);

WidgetbookNode messagingNode() => WidgetbookFolder(
  name: 'Messaging',
  children: [
    WidgetbookComponent(
      name: 'MessagingPlatformRow',
      useCases: [
        for (final MapEntry(key: name, value: platform) in _platforms.entries)
          WidgetbookUseCase(
            name: 'Every state ($name)',
            builder: (context) => _on(context, platform, const _RowGroup()),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'MessagingScreen',
      useCases: [
        for (final MapEntry(key: name, value: platform) in _platforms.entries)
          _messaging(
            'Platforms ($name)',
            (repository) => Builder(
              builder: (context) => _on(
                context,
                platform,
                _pushed(MessagingScreen(repository: repository)),
              ),
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'MessagingSetupScreen',
      useCases: [
        _messaging(
          'Discord',
          (repository) => FutureBuilder<List<HermesMessagingPlatform>>(
            future: repository.load(),
            builder: (_, snapshot) {
              final platforms = snapshot.data;
              if (platforms == null) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              return MessagingSetupScreen(
                platform: platforms.firstWhere((b) => b.id == 'discord'),
                repository: repository,
              );
            },
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'TelegramPairingScreen',
      useCases: [
        _messaging(
          'Waiting for Telegram',
          (repository) => TelegramPairingScreen(
            repository: repository,
            pollInterval: const Duration(days: 1),
            launchLink: (_) async => true,
          ),
        ),
      ],
    ),
  ],
);
