import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/bot_mode/widgets/bot_creation_fields.dart';
import 'package:hermes_app/src/bot_mode/widgets/bot_edit_fields.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';

import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_screen.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode botModeRosterNode() => WidgetbookFolder(
  name: 'Bot Mode',
  children: [
    WidgetbookComponent(
      name: 'Creation fields',
      useCases: [
        for (final state in [
          'Basic',
          'Advanced',
          'Model error',
          'Loading models',
          'Saving',
          'Retry',
        ])
          ...onEachPlatform(
            state,
            (_) => frame(_CreationPreview(state: state)),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'Edit fields',
      useCases: onEachPlatform(
        'Edit',
        (_) => frame(const _CreationPreview(state: 'Edit')),
      ),
    ),
    WidgetbookComponent(
      name: 'Roster',
      useCases: [
        ..._case('Loading', (_, _) => Completer<Map<String, Object?>>().future),
        ..._case(
          'Empty',
          (_, _) async => {'bot_mode_protocol': true, 'profiles': []},
        ),
        ..._case('Unavailable', (_, _) async => {'profiles': []}),
        ..._case('Error', (_, _) async => throw StateError('Gateway offline')),
        ..._case('Populated', (_, _) async => _roster, groups: true),
        ..._case('Long titles', (_, _) async => _longRoster),
      ],
    ),
  ],
);

List<WidgetbookUseCase> _case(
  String name,
  BotModeRequest request, {
  bool groups = false,
}) => onEachPlatform(
  name,
  (_) => BotModeRosterScreen(
    repository: BotModeRosterRepository(request, serverId: 'Hermes demo'),
    groups: groups ? _groups() : null,
    onOpenGroup: groups ? (_) {} : null,
  ),
);

Map<String, Object?> _room(String id, String name, int members) => {
  'room_id': id,
  'name': name,
  'members': [
    for (final profile in ['writer', 'research', 'plain'].take(members))
      {'member_id': profile, 'profile': profile, 'handle': profile},
  ],
  'authority_gateway_id': 'gateway',
  'authority_epoch': 1,
  'revision': 1,
  'created_at': 1.0,
  'updated_at': 1.0,
  'latest_seq': 0,
};

HermesGroupsRepository _groups() =>
    HermesGroupsRepository((method, params) async {
      final rooms = [
        _room('launch', 'Launch plan', 3),
        _room('weekly', 'Weekly review', 2),
      ];
      return switch (method) {
        'groups.capabilities' => {
          'protocol_version': 2,
          'driver': true,
          'persistent_process': true,
          'authority_gateway_id': 'gateway',
          'features': ['idempotent_send', 'monotonic_log'],
          'methods': HermesGroupsRepository.requiredMethods.toList(),
        },
        'groups.list' => {'rooms': rooms, 'next_offset': null},
        'groups.state' => {
          'room': rooms.firstWhere((r) => r['room_id'] == params['room_id']),
          'driver_status': {
            'running': true,
            'working': params['room_id'] == 'launch',
            'blocked': params['room_id'] == 'weekly',
            'counts': <String, Object?>{},
            'pending_actions': [
              if (params['room_id'] == 'weekly')
                {
                  'kind': 'approval',
                  'member_id': 'writer',
                  'task_id': 'task',
                  'request_id': 'approval',
                  'execution_generation': 1,
                },
            ],
            'peer_routes': <Object?>[],
          },
        },
        _ => throw StateError(method),
      };
    });

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

class _CreationPreview extends StatefulWidget {
  const _CreationPreview({required this.state});
  final String state;

  @override
  State<_CreationPreview> createState() => _CreationPreviewState();
}

class _CreationPreviewState extends State<_CreationPreview> {
  final name = TextEditingController(text: 'writer');
  final title = TextEditingController(text: 'Editor');
  final description = TextEditingController(
    text: 'Careful writing and reviews',
  );
  final soul = TextEditingController(text: 'Check every claim.');
  bool copyKeys = true;

  @override
  void dispose() {
    for (final controller in [name, title, description, soul]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.state == 'Edit'
      ? BotEditFields(
          profile: 'writer',
          title: title,
          summary: description,
          description: description,
          soul: soul,
          model: 'demo-model',
          provider: 'demo',
          onChooseModel: () {},
        )
      : BotCreationFields(
          name: name,
          title: title,
          description: description,
          soul: soul,
          copyKeys: copyKeys,
          onCopyKeysChanged: (value) => setState(() => copyKeys = value),
          onChooseModel: () {},
          chosen: widget.state == 'Advanced'
              ? const ModelChoice('demo', 'demo-model')
              : null,
          initiallyExpanded: widget.state != 'Basic',
          modelError: widget.state == 'Model error'
              ? 'Could not load models. Try again.'
              : null,
          saving: widget.state == 'Saving',
          modelLoading: widget.state == 'Loading models',
          createdName: widget.state == 'Retry' ? 'writer' : null,
        );
}
