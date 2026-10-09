import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/bot_mode/groups/widgets/group_widgets.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

import 'frame.dart';

GroupMember _member(int n) => GroupMember.fromJson({
  'member_id': 'member-$n',
  'profile': 'specialist-$n',
  'handle': 'specialist$n',
  'display_name': n == 1
      ? 'A specialist with a very long display name'
      : 'Specialist $n',
});
GroupRoom _room(int count) => GroupRoom.fromJson({
  'room_id': 'room',
  'name': 'Research and planning with a long conversation title',
  'members': List.generate(count, (n) => _member(n + 1).toJson()),
  'authority_gateway_id': 'gateway',
  'authority_epoch': 1,
  'revision': 1,
  'created_at': 1,
  'updated_at': 2,
});

Widget _frame(Widget widget) =>
    SingleChildScrollView(padding: const EdgeInsets.all(16), child: widget);

/// Plain fixtures and callbacks, usable before the screen is integrated.
WidgetbookNode groupUiNode() => WidgetbookComponent(
  name: 'Hosted groups',
  useCases: [
    WidgetbookUseCase(
      name: 'Text composer with mention',
      builder: (_) => _frame(
        GroupTextComposer(
          controller: TextEditingController(text: '@special'),
          members: [_member(1), _member(2)],
          discussionLabel: 'Topic 1',
          pending: false,
          enabled: true,
          onChanged: (_) {},
          onSend: () {},
          onNewTopic: () {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Disband confirmation',
      builder: (_) => GroupConfirmation(
        title: 'Disband group?',
        detail: 'This stops the group and removes it from the roster.',
        action: 'Disband group',
        onCancel: () {},
        onConfirm: () {},
      ),
    ),
    for (final state in [
      'Loading rooms',
      'No hosted rooms yet',
      'Could not load rooms',
      'Driver offline; history remains readable',
      'Disbanding removes this room and stops its work',
    ])
      WidgetbookUseCase(
        name: state,
        builder: (_) => _frame(
          GroupNotice(
            message: state,
            loading: state.startsWith('Loading'),
            onRetry: state.startsWith('Could') ? () {} : null,
          ),
        ),
      ),
    for (final count in [2, 6]) ...[
      ...onEachPlatform(
        '$count members',
        (_) => _frame(
          GroupedSection(
            header: 'Groups',
            children: [
              GroupRoomRow(
                room: _room(count),
                needsAttention: count == 6,
                activity: count == 2 ? 'Working' : null,
                onOpen: () {},
              ),
            ],
          ),
        ),
      ),
      ...onEachPlatform(
        '$count member checklist',
        (_) => _frame(
          GroupMemberChecklist(
            members: _room(count).members,
            selected: {
              for (final m in _room(count).members.take(2)) m.memberId,
            },
            note: groupInteractionLimitation,
            onChanged: (_) {},
          ),
        ),
      ),
    ],
    WidgetbookUseCase(
      name: 'Attributed transcript',
      builder: (_) => _frame(
        GroupEventRow(
          event: GroupEvent.fromJson({
            'room_id': 'room',
            'seq': 1,
            'event_id': 'event',
            'kind': 'message.assistant',
            'actor': {'kind': 'member', 'id': 'member-1'},
            'payload': {
              'text': '**Research complete.** Here is the shared plan.',
              'thread_id': 'discussion-1',
            },
            'created_at': 2,
          }),
          members: [_member(1)],
          onReply: () {},
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Waiting without room action',
      builder: (_) => _frame(
        GroupActivity(
          working: true,
          blocked: false,
          counts: const {'running': 1},
          members: [_member(1)],
          actions: const [],
          pending: false,
          onStop: () {},
          onApprove: (_, _) async {},
          onRetry: (_) {},
        ),
      ),
    ),
    for (final status in ['queued', 'working', 'blocked', 'failed'])
      WidgetbookUseCase(
        name: status,
        builder: (_) => _frame(
          GroupActivity(
            working: status == 'working',
            blocked: status == 'blocked',
            counts: {status: 1},
            members: [_member(1)],
            actions: [
              if (status == 'blocked')
                GroupPendingAction.fromJson({
                  'kind': 'approval',
                  'task_id': 'task',
                  'member_id': 'member-1',
                  'request_id': 'request',
                  'execution_generation': 1,
                  'command': 'Review the proposed command before allowing it',
                }),
              if (status == 'failed')
                GroupPendingAction.fromJson({
                  'kind': 'retry',
                  'task_id': 'task',
                  'reason': 'The task result is indeterminate. Retry only after review.',
                }),
            ],
            pending: false,
            onStop: () {},
            onApprove: (_, _) async {},
            onRetry: (_) {},
          ),
        ),
      ),
  ],
);
