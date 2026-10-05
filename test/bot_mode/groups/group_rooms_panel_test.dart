import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/bot_mode/groups/group_rooms_panel.dart';

import '../group_protocol/groups_repository_test.dart' as fixtures;

void main() {
  testWidgets('creation validates and retries the same room identity', (
    tester,
  ) async {
    final calls = <Map<String, Object?>>[];
    GroupRoom? opened;
    final repo = HermesGroupsRepository((method, params) async {
      switch (method) {
        case 'groups.capabilities':
          return fixtures.capabilities();
        case 'groups.list':
          return {'rooms': [], 'next_offset': null};
        case 'groups.create':
          calls.add(params);
          if (calls.length == 1) throw TimeoutException('lost receipt');
          return {
            'room': {
              ...fixtures.room(id: params['room_id'] as String),
              'name': params['name'],
              'members': params['members'],
            },
          };
        default:
          throw StateError(method);
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              GroupRoomsPanel(
                repository: repo,
                bots: const [
                  BotModeBot(serverId: 'server', name: 'one', revision: 1),
                  BotModeBot(serverId: 'server', name: 'two', revision: 1),
                ],
                onOpen: (room) => opened = room,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create group'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Interactive requests cannot be answered'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Room name'),
      'A group',
    );
    await tester.tap(find.text('one'));
    await tester.pump();
    await tester.tap(find.text('two'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls.length, 2);
    expect(calls[0], calls[1]);
    expect(opened!.roomId, calls[0]['room_id']);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('tombstone fences delayed listing results', (tester) async {
    final late = Completer<Map<String, Object?>>();
    var lists = 0;
    final key = GlobalKey<GroupRoomsPanelState>();
    final repo = HermesGroupsRepository((method, params) async {
      if (method == 'groups.capabilities') return fixtures.capabilities();
      if (method == 'groups.state') return {'room': fixtures.room()};
      if (++lists == 2) return late.future;
      return {
        'rooms': [fixtures.room()],
        'next_offset': null,
      };
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              GroupRoomsPanel(
                key: key,
                repository: repo,
                bots: const [],
                onOpen: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Discussion'), findsOneWidget);
    final refresh = key.currentState!.refresh();
    await tester.pump();
    key.currentState!.removeRoom('room');
    late.complete({
      'rooms': [fixtures.room()],
      'next_offset': null,
    });
    await refresh;
    await tester.pumpAndSettle();
    expect(find.text('Discussion'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
