import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/bot_mode/groups/group_chat_screen.dart';

import '../group_protocol/groups_repository_test.dart' as fixtures;
import '../../support/screenshot_recorder.dart';
import '../../../widgetbook/environment.dart';

void main() {
  for (final theme in themes.entries) {
    for (final size in [phoneSize, desktopSize]) {
      testWidgets('hosted group workflow ${theme.key} ${size.width}', (
        tester,
      ) async {
        final shots = ScreenshotRecorder(
          'groups-${theme.key.toLowerCase()}-${size.width == phoneSize.width ? 'phone' : 'desktop'}',
        );
        await shots.start(tester, size);
        final calls = <(String, Map<String, Object?>)>[];
        final events = <Map<String, Object?>>[
          {
            ...fixtures.event(1, kind: 'message.assistant'),
            'actor': {'kind': 'member', 'id': 'one'},
            'payload': {
              'text': 'Hello from one',
              'thread_id': 'existing-topic',
            },
          },
        ];
        var name = 'Discussion';
        var actions = <Map<String, Object?>>[
          {
            'kind': 'approval',
            'member_id': 'one',
            'task_id': 'task',
            'request_id': 'approval',
            'execution_generation': 1,
            'approval': {
              'command': 'safe command',
              'description': 'Allow this member to run the command?',
            },
          },
        ];
        final repo = HermesGroupsRepository((method, params) async {
          calls.add((method, params));
          switch (method) {
            case 'groups.capabilities':
              return fixtures.capabilities();
            case 'groups.state':
              return {
                'room': {...fixtures.room(), 'name': name},
                'driver_status': {
                  'running': true,
                  'working': true,
                  'blocked': actions.any((a) => a['kind'] == 'approval'),
                  'counts': {},
                  'pending_actions': actions,
                  'peer_routes': [],
                },
              };
            case 'groups.log':
              return {
                ...fixtures.page(
                  events
                      .where(
                        (event) =>
                            (event['seq'] as int) >
                            (params['since_seq'] as int),
                      )
                      .toList(),
                  events.length,
                ),
                'latest_seq': events.length,
              };
            case 'groups.send':
              final payload = params['payload'] as Map;
              final event = {
                ...fixtures.event(
                  events.length + 1,
                  id: serverUserEventId(params['event_id'] as String),
                ),
                'payload': payload,
              };
              events.add(event);
              return {'event': event, 'accepted': true, 'driver_started': true};
            case 'groups.approve':
              actions = [
                {
                  'kind': 'retry',
                  'task_id': 'retry-task',
                  'reason': 'Indeterminate result',
                },
              ];
              return {'approved': true};
            case 'groups.stop':
              return {'cancelled': 1};
            case 'groups.retry':
              actions = [];
              return {
                'retried': true,
                'task': {
                  'room_id': 'room',
                  'task_id': 'retry-task',
                  'thread_id': 'existing-topic',
                  'turn_id': 'turn',
                  'status': 'queued',
                  'execution_generation': 2,
                  'cancel_generation': 0,
                },
              };
            case 'groups.rename':
              name = params['name'] as String;
              return {
                'room': {...fixtures.room(), 'name': name},
              };
            case 'groups.disband':
              return {
                'tombstone': {
                  'room_id': 'room',
                  'disbanded_at': 2,
                  'idempotent': false,
                },
              };
            default:
              throw StateError(method);
          }
        });
        var removed = false;
        await tester.pumpWidget(
          shots.frame(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: withScreenshotFont(theme.value),
              home: GroupChatScreen(
                repository: repo,
                room: GroupRoom.fromJson(fixtures.room()),
                onDisbanded: () => removed = true,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('Interactive requests cannot be answered'),
          findsNothing,
        );
        await shots.capture(tester, 'approval');
        await tester.tap(find.text('Allow once'));
        await tester.pumpAndSettle();
        expect(calls.lastWhere((call) => call.$1 == 'groups.approve').$2, {
          'room_id': 'room',
          'member_id': 'one',
          'task_id': 'task',
          'execution_generation': 1,
          'request_id': 'approval',
          'choice': 'once',
        });
        await tester.tap(find.text('Review retry'));
        await tester.pumpAndSettle();
        expect(calls.where((call) => call.$1 == 'groups.retry'), isEmpty);
        await shots.capture(tester, 'retry-confirmation');
        await tester.tap(find.text('Retry task'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stop'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reply in thread'));
        await tester.enterText(
          find.widgetWithText(TextField, 'Message group'),
          '@unknown shared prompt',
        );
        await tester.pump();
        await tester.tap(find.text('Send'));
        await tester.pumpAndSettle();
        expect(
          calls.lastWhere((call) => call.$1 == 'groups.send').$2['payload'],
          {'text': '@unknown shared prompt', 'thread_id': 'existing-topic'},
        );
        expect(calls.where((call) => call.$1 == 'message_agent'), isEmpty);
        expect(tester.takeException(), isNull);
        await shots.capture(tester, 'discussion');
        await tester.tap(find.byTooltip('Room actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rename'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Room name'),
          'New name',
        );
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('New name'), findsOneWidget);
        await tester.tap(find.byTooltip('Room actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Disband'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Disband group'));
        await tester.pumpAndSettle();
        expect(removed, isTrue);
        expect(find.textContaining('disbanded'), findsOneWidget);
        await shots.capture(tester, 'disbanded');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
