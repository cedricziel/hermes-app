import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pump(
  WidgetTester tester,
  List<ToolCall> calls, {
  Map<int, ApprovalRequest> approvals = const {},
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: ToolCallGroup(calls: calls, approvals: approvals),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a single call renders as a bare ToolCallCard', (tester) async {
    await _pump(tester, const [ToolCall(name: 'terminal', summary: 'ls')]);

    expect(find.byType(ToolCallCard), findsOneWidget);
    expect(find.textContaining('Ran'), findsNothing);
  });

  testWidgets('several finished calls collapse behind a count, closed', (
    tester,
  ) async {
    await _pump(tester, const [
      ToolCall(name: 'terminal', summary: 'ls'),
      ToolCall(name: 'read_file', summary: 'a.dart'),
      ToolCall(name: 'write_file', summary: 'b.dart'),
    ]);

    expect(find.text('Used 3 tools'), findsOneWidget);
    expect(find.byType(ToolCallCard), findsNothing);

    await tester.tap(find.text('Used 3 tools'));
    await tester.pump();

    expect(find.byType(ToolCallCard), findsNWidgets(3));

    await tester.tap(find.text('Used 3 tools'));
    await tester.pump();

    expect(find.byType(ToolCallCard), findsNothing);
  });

  testWidgets('a call still running names it, while others show a count', (
    tester,
  ) async {
    await _pump(tester, const [
      ToolCall(name: 'terminal', summary: 'ls'),
      ToolCall(name: 'git_show', summary: '', status: ToolCallStatus.running),
    ]);

    expect(find.text('Running git_show…'), findsOneWidget);
    expect(find.text('Used 2 tools'), findsNothing);
  });

  testWidgets('names the call that runs, not one still being written', (
    tester,
  ) async {
    await _pump(tester, const [
      ToolCall(name: 'terminal', summary: 'ls', status: ToolCallStatus.running),
      ToolCall(
        name: 'patch',
        summary: '',
        status: ToolCallStatus.running,
        preparing: true,
      ),
    ]);

    expect(find.text('Running terminal…'), findsOneWidget);
  });

  testWidgets('a group whose calls are all being written says so', (
    tester,
  ) async {
    await _pump(tester, const [
      ToolCall(
        name: 'terminal',
        summary: '',
        status: ToolCallStatus.running,
        preparing: true,
      ),
      ToolCall(
        name: 'patch',
        summary: '',
        status: ToolCallStatus.running,
        preparing: true,
      ),
    ]);

    expect(find.text('Preparing terminal…'), findsOneWidget);
  });

  testWidgets('a failed call in a finished group is not mistaken for '
      'success', (tester) async {
    await _pump(tester, const [
      ToolCall(name: 'terminal', summary: 'ls'),
      ToolCall(name: 'web_search', summary: '', status: ToolCallStatus.error),
    ]);

    await tester.tap(find.text('Used 2 tools'));
    await tester.pump();

    final failed = tester.widget<ToolCallCard>(
      find.byWidgetPredicate(
        (w) => w is ToolCallCard && w.call.name == 'web_search',
      ),
    );
    expect(failed.call.status, ToolCallStatus.error);
  });

  testWidgets('a call waiting on an approval keeps the group open', (
    tester,
  ) async {
    await _pump(
      tester,
      const [
        ToolCall(name: 'read_file', summary: 'a'),
        ToolCall(
          name: 'terminal',
          summary: 'rm -rf build',
          status: ToolCallStatus.running,
        ),
      ],
      approvals: const {
        1: ApprovalRequest(
          requestId: 'r1',
          command: 'rm -rf build',
          description: '',
          choices: ['once', 'deny'],
        ),
      },
    );

    expect(find.text('Waiting on terminal'), findsOneWidget);
    expect(find.byType(ToolCallCard), findsNWidgets(2));
    expect(find.byType(ApprovalCard), findsOneWidget);
  });

  testWidgets('a run that was all cancelled shows a stop mark', (tester) async {
    await _pump(tester, const [
      ToolCall(name: 'a', summary: '', status: ToolCallStatus.cancelled),
      ToolCall(name: 'b', summary: '', status: ToolCallStatus.cancelled),
    ]);

    expect(find.byIcon(Icons.block), findsOneWidget);
  });
}
