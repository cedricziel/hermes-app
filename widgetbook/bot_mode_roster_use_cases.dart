import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_screen.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookNode botModeRosterNode() => WidgetbookFolder(
  name: 'Bot Mode',
  children: [
    WidgetbookComponent(
      name: 'Roster',
      useCases: [
        _case('Loading', (_, _) => Completer<Map<String, Object?>>().future),
        _case(
          'Empty',
          (_, _) async => {'bot_mode_protocol': true, 'profiles': []},
        ),
        _case('Unavailable', (_, _) async => {'profiles': []}),
        _case('Error', (_, _) async => throw StateError('Gateway offline')),
        _case('Populated', (_, _) async => _roster),
        _case('Long titles', (_, _) async => _longRoster),
      ],
    ),
  ],
);

WidgetbookUseCase _case(String name, BotModeRequest request) =>
    WidgetbookUseCase(
      name: name,
      builder: (_) => MaterialApp(
        home: BotModeRosterScreen(
          repository: BotModeRosterRepository(request, serverId: 'Hermes demo'),
        ),
      ),
    );

final Map<String, Object?> _roster = {
  'bot_mode_protocol': true,
  'profiles': [
    {
      'name': 'writer',
      'display_name': 'Writer',
      'model': 'claude-sonnet-4',
      'ui_meta_revisions': {'hermes-bots': 3},
      'ui_meta': {
        'hermes-bots': {
          'title': 'Editor',
          'description': 'Clear copy and careful reviews',
        },
      },
      'canonical_session': {
        'id': 'chat-1',
        'preview': 'The draft is ready for review',
      },
    },
    {
      'name': 'research',
      'model': 'gpt-5',
      'ui_meta_revisions': {'hermes-bots': 1},
      'ui_meta': {
        'hermes-bots': {'title': 'Researcher'},
      },
    },
    {
      'name': 'plain',
      'ui_meta_revisions': {'hermes-bots': 0},
    },
  ],
};

final Map<String, Object?> _longRoster = {
  'bot_mode_protocol': true,
  'profiles': [
    {
      'name': 'long',
      'ui_meta_revisions': {'hermes-bots': 1},
      'ui_meta': {
        'hermes-bots': {
          'title': 'A specialist with a very long title that wraps on a phone screen',
          'description': 'Works across writing, research and review',
        },
      },
    },
  ],
};
