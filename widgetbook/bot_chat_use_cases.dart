import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:hermes_app/src/bot_mode/bot_chat_context.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/widgets/bot_chat_banner.dart';
import 'package:hermes_app/src/bot_mode/widgets/bot_handoff_body.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';

import 'frame.dart';
import 'host.dart';

const _owner = BotModeBot(
  serverId: 'fixture',
  name: 'research',
  revision: 0,
  displayName: 'Research Specialist',
);
const _peers = [
  _owner,
  BotModeBot(
    serverId: 'fixture',
    name: 'writer',
    revision: 0,
    displayName: 'Alex',
  ),
  BotModeBot(
    serverId: 'fixture',
    name: 'editor',
    revision: 0,
    displayName: 'Alex',
  ),
];

WidgetbookNode botChatNode() => WidgetbookFolder(
  name: 'Bot Chat',
  children: [
    WidgetbookComponent(
      name: 'Context and mentions',
      useCases: [
        for (final state in [
          'Empty conversation',
          'Long identity',
          'Ambiguous handles',
          'Disabled protocol',
          'Retry',
        ])
          WidgetbookUseCase(
            name: state,
            builder: (_) {
              final context = BotChatContext(
                bot: state == 'Long identity'
                    ? const BotModeBot(
                        serverId: 'fixture',
                        name: 'long-research-profile',
                        revision: 0,
                        displayName: 'Research specialist for infrastructure and developer experience',
                      )
                    : _owner,
                rootId: 'fixture-root',
                storedId: 'fixture-tip',
                peers: _peers,
                protocolEnabled: state != 'Disabled protocol',
              );
              return frame(
                Hosted<TextEditingController>(
                  create: () => TextEditingController(
                    text: state == 'Ambiguous handles' ? 'Ask @al' : '',
                  ),
                  dispose: (text) => text.dispose(),
                  builder: (_, text) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BotChatBanner(context: context),
                      if (state == 'Retry')
                        TextButton(
                          onPressed: () {},
                          child: const Text('Retry opening Bot Chat'),
                        ),
                      ChatComposer(
                        controller: text,
                        botContext: context,
                        onSend: (_) {},
                        onRemoveAttachment: (_) {},
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'Backend handoff',
      useCases: [
        for (final data in <String, Map<String, Object?>>{
          'Attributed handoff': {
            'status': 'settled',
            'to': '@writer',
            'reply': 'Writer (@writer): The release summary is ready.',
          },
          'Queued receipt': {
            'status': 'queued',
            'to': '@writer',
            'detail': 'The backend queued this message.',
          },
          'Busy failure': {
            'status': 'error',
            'to': '@writer',
            'error':
                'target_busy: Writer could not accept the queued delivery.',
          },
          'Ambiguous delivery': {'status': 'ambiguous', 'to': '@writer'},
        }.entries)
          WidgetbookUseCase(
            name: data.key,
            builder: (_) => frame(BotHandoffBody(data: data.value)),
          ),
      ],
    ),
  ],
);
