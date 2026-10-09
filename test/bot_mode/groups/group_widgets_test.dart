import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/group_protocol/hermes_groups_repository.dart';
import 'package:hermes_app/src/bot_mode/groups/widgets/group_widgets.dart';

import '../group_protocol/groups_repository_test.dart' as fixtures;

void main() {
  testWidgets('room row identifies fixed membership and real attention', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupRoomRow(
            room: GroupRoom.fromJson(fixtures.room()),
            needsAttention: true,
            onOpen: () {},
          ),
        ),
      ),
    );
    expect(find.text('Discussion'), findsOneWidget);
    expect(find.textContaining('2 members'), findsOneWidget);
    expect(find.textContaining('Needs your attention'), findsOneWidget);
  });
  testWidgets(
    'checklist is searchable and handles remain distinct from titles',
    (tester) async {
      final members = [
        'one',
        'two',
      ].map((id) => GroupMember.fromJson(fixtures.member(id))).toList();
      final selected = <String>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupMemberChecklist(
              members: members,
              selected: selected,
              onChanged: (value) => selected.addAll(value),
            ),
          ),
        ),
      );
      await tester.tap(find.text('one'));
      expect(selected, {'one'});
      await tester.enterText(find.byType(TextField), 'two');
      await tester.pump();
      expect(find.text('one'), findsNothing);
      expect(find.text('two'), findsNWidgets(2));
    },
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('on $platform a member row says whether it is checked', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final members = [
        for (final id in ['one', 'two'])
          GroupMember.fromJson(fixtures.member(id)),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: GroupMemberChecklist(
              members: members,
              selected: const {'one'},
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('one').last),
        isSemantics(
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('two').last),
        isSemantics(hasCheckedState: true, isChecked: false),
      );
      semantics.dispose();
    });
  }

  testWidgets('event prose has recorded author and discussion thread', (
    tester,
  ) async {
    final event = GroupEvent.fromJson({
      ...fixtures.event(1, kind: 'message.assistant'),
      'actor': {'kind': 'member', 'id': 'one'},
      'payload': {'text': 'A durable reply', 'thread_id': 'topic'},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupEventRow(
            event: event,
            threadLabel: 'Topic 1',
            members: [GroupMember.fromJson(fixtures.member('one'))],
            onReply: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('one'), findsOneWidget);
    expect(find.textContaining('Topic 1'), findsOneWidget);
    expect(find.text('A durable reply'), findsOneWidget);
    expect(find.text('Reply in thread'), findsOneWidget);
  });
  testWidgets(
    'exact approvals expose only once/deny and pending controls disable',
    (tester) async {
      final action = GroupPendingAction.fromJson({
        'kind': 'approval',
        'task_id': 'task',
        'member_id': 'one',
        'request_id': 'request',
        'execution_generation': 2,
        'approval': {
          'command': 'example command',
          'description': 'Review execution',
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupActivity(
              working: true,
              blocked: true,
              counts: const {},
              members: [GroupMember.fromJson(fixtures.member('one'))],
              actions: [action],
              pending: true,
              onStop: () {},
              onApprove: (_, _) async {},
              onRetry: (_) {},
            ),
          ),
        ),
      );
      expect(find.textContaining('one'), findsOneWidget);
      expect(find.text('example command'), findsOneWidget);
      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        expect(button.onPressed, isNull);
      }
    },
  );
  testWidgets(
    'waiting without a room action explains limitation and offers Stop',
    (tester) async {
      var stopped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupActivity(
              working: true,
              blocked: false,
              counts: const {'running': 1},
              members: const [],
              actions: const [],
              pending: false,
              onStop: () => stopped = true,
              onApprove: (_, _) async {},
              onRetry: (_) {},
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Interactive requests cannot be answered'),
        findsOneWidget,
      );
      await tester.tap(find.text('Stop'));
      expect(stopped, isTrue);
    },
  );
  testWidgets('unavailable rooms offer Deny and Stop without Allow once', (
    tester,
  ) async {
    final action = GroupPendingAction.fromJson({
      'kind': 'approval',
      'task_id': 'task',
      'member_id': 'one',
      'request_id': 'request',
      'execution_generation': 2,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupActivity(
            working: true,
            blocked: true,
            counts: const {},
            members: [GroupMember.fromJson(fixtures.member('one'))],
            actions: [action],
            pending: false,
            unavailableReason: 'Execution unavailable',
            onStop: () {},
            onApprove: (_, _) async {},
            onRetry: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Allow once'), findsNothing);
    expect(find.text('Deny'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
  });
}
