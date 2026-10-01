import 'package:flutter/material.dart';
import 'package:flutter_json_view/flutter_json_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_bodies.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pump(
  WidgetTester tester,
  ToolCall call, {
  ApprovalRequest? approval,
  Future<void> Function(String choice)? onAnswerApproval,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: ToolCallCard(
            call: call,
            approval: approval,
            onAnswerApproval: onAnswerApproval,
          ),
        ),
      ),
    ),
  ),
);

const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'Delete the build folder',
  choices: ['once', 'deny'],
);

void main() {
  testWidgets('tapping opens the input and result, and again closes them', (
    tester,
  ) async {
    await _pump(
      tester,
      const ToolCall(
        name: 'terminal',
        summary: '{"command":"ls -la"}',
        result: 'total 0',
      ),
    );

    expect(find.text('Result'), findsNothing);

    await tester.tap(find.text('terminal'));
    await tester.pumpAndSettle();

    expect(find.text('Input'), findsOneWidget);
    expect(find.byType(JsonView), findsOneWidget);
    final viewer = find.byType(JsonView);
    expect(
      find.descendant(of: viewer, matching: find.textContaining('command')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: viewer, matching: find.textContaining('ls -la')),
      findsOneWidget,
    );
    expect(find.text('Result'), findsOneWidget);
    expect(find.text('total 0'), findsOneWidget);

    await tester.tap(find.text('terminal'));
    await tester.pumpAndSettle();

    expect(find.text('Result'), findsNothing);
  });

  testWidgets('the input and result sections line up', (tester) async {
    await _pump(
      tester,
      const ToolCall(
        name: 'terminal',
        summary: '{"command":"ls -la"}',
        result: 'total 0',
      ),
    );

    await tester.tap(find.text('terminal'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Result')).dx,
      tester.getTopLeft(find.text('Input')).dx,
    );
  });

  testWidgets('input that is not JSON is shown as it is', (tester) async {
    await _pump(tester, const ToolCall(name: 'terminal', summary: 'ls -la'));

    await tester.tap(find.text('terminal'));
    await tester.pumpAndSettle();

    expect(find.text('Input'), findsOneWidget);
    expect(find.text('ls -la'), findsWidgets);
    expect(find.byType(JsonView), findsNothing);
    expect(find.text('Result'), findsNothing);
  });

  testWidgets('a call with nothing to show does not expand', (tester) async {
    await _pump(tester, const ToolCall(name: 'kanban_show', summary: ''));

    await tester.tap(find.text('kanban_show'));
    await tester.pumpAndSettle();

    expect(find.text('Input'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('a running call counts up the seconds it has run', (
    tester,
  ) async {
    await _pump(
      tester,
      ToolCall(
        name: 'terminal',
        summary: 'sleep 5',
        status: ToolCallStatus.running,
        startedAt: DateTime.now().subtract(const Duration(seconds: 3)),
      ),
    );

    expect(find.text('3s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining(RegExp(r'^\d+s$')), findsOneWidget);
  });

  testWidgets('a finished call shows how long it took', (tester) async {
    await _pump(
      tester,
      const ToolCall(
        name: 'terminal',
        summary: 'ls',
        duration: Duration(milliseconds: 1240),
      ),
    );

    expect(find.text('1.2s'), findsOneWidget);
  });

  testWidgets('a cancelled call shows a stop mark', (tester) async {
    await _pump(
      tester,
      const ToolCall(
        name: 'terminal',
        summary: 'ls',
        status: ToolCallStatus.cancelled,
      ),
    );

    expect(find.byIcon(Icons.block), findsOneWidget);
  });

  testWidgets('a call being written says it is preparing', (tester) async {
    await _pump(
      tester,
      const ToolCall(
        name: 'terminal',
        summary: '',
        status: ToolCallStatus.running,
        preparing: true,
      ),
    );

    expect(find.text('Preparing…'), findsOneWidget);
  });

  testWidgets('arguments show as the input', (tester) async {
    await _pump(
      tester,
      const ToolCall(
        name: 'read_file',
        summary: 'a.dart',
        args: {'path': 'a.dart', 'limit': 20},
      ),
    );

    await tester.tap(find.text('read_file'));
    await tester.pumpAndSettle();

    final viewer = find.byType(JsonView);
    expect(
      find.descendant(of: viewer, matching: find.textContaining('limit')),
      findsOneWidget,
    );
  });

  testWidgets('a failed call labels its result as the error', (tester) async {
    await _pump(
      tester,
      const ToolCall(
        name: 'fetch',
        summary: 'x',
        status: ToolCallStatus.error,
        result: 'timed out',
      ),
    );

    await tester.tap(find.text('fetch'));
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(find.text('timed out'), findsOneWidget);
  });

  group('an approval', () {
    const running = ToolCall(
      name: 'terminal',
      summary: 'rm -rf build',
      status: ToolCallStatus.running,
    );

    testWidgets('waiting shows inside the card without opening it', (
      tester,
    ) async {
      String? chosen;
      await _pump(
        tester,
        running,
        approval: _approval,
        onAnswerApproval: (choice) async => chosen = choice,
      );

      expect(find.byType(ApprovalCard), findsOneWidget);
      expect(find.byIcon(Icons.front_hand_outlined), findsOneWidget);

      await tester.tap(find.text('Allow once'));
      await tester.pump();

      expect(chosen, 'once');
    });

    testWidgets('once answered moves into the details', (tester) async {
      await _pump(tester, running, approval: _approval.answered('once'));

      expect(find.byType(ApprovalCard), findsNothing);
      expect(find.byIcon(Icons.front_hand_outlined), findsNothing);

      await tester.tap(find.text('terminal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ApprovalCard), findsOneWidget);
    });
  });

  group('tool views', () {
    testWidgets('a terminal call shows its command, output and exit code', (
      tester,
    ) async {
      await _pump(
        tester,
        const ToolCall(
          name: 'terminal',
          summary: 'false',
          status: ToolCallStatus.error,
          args: {'command': 'make test'},
          result: 'boom',
          resultData: {'output': 'boom', 'exit_code': 2, 'error': 'failed'},
        ),
      );

      await tester.tap(find.text('terminal'));
      await tester.pumpAndSettle();

      expect(find.byType(TerminalToolBody), findsOneWidget);
      expect(
        find.textContaining('make test', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('boom'), findsOneWidget);
      expect(find.text('Exit code 2'), findsOneWidget);
      expect(find.text('Input'), findsNothing);
    });

    testWidgets('a refused command shows why', (tester) async {
      await _pump(
        tester,
        const ToolCall(
          name: 'terminal',
          summary: 'chmod',
          status: ToolCallStatus.error,
          args: {'command': 'chmod -R 777 /srv'},
          resultData: {
            'output': '',
            'exit_code': -1,
            'error': 'BLOCKED: Command denied by user.',
          },
        ),
      );

      await tester.tap(find.text('terminal'));
      await tester.pumpAndSettle();

      expect(find.text('BLOCKED: Command denied by user.'), findsOneWidget);
      expect(find.text('Exit code -1'), findsOneWidget);
    });

    testWidgets('a patch read from history shows the diff in its result', (
      tester,
    ) async {
      await _pump(
        tester,
        const ToolCall(
          name: 'patch',
          summary: 'a.txt',
          resultData: {'success': true, 'diff': '-old\n+new'},
        ),
      );

      await tester.tap(find.text('patch'));
      await tester.pumpAndSettle();

      expect(find.byType(ToolDiffBody), findsOneWidget);
      expect(
        find.textContaining('-old\n+new', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a diff drops Hermes\' review heading', (tester) async {
      await _pump(
        tester,
        const ToolCall(
          name: 'patch',
          summary: 'a.txt',
          diff: '  \u250a review diff\na/a.txt \u2192 b/a.txt\n-old\n+new',
        ),
      );

      await tester.tap(find.text('patch'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('review diff', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('a/a.txt', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a web search lists what it found', (tester) async {
      await _pump(
        tester,
        const ToolCall(
          name: 'web_search',
          summary: 'flutter',
          resultData: {
            'success': true,
            'data': {
              'web': [
                {
                  'title': 'Flutter',
                  'url': 'https://flutter.dev',
                  'description': 'Build apps',
                },
              ],
            },
          },
        ),
      );

      await tester.tap(find.text('web_search'));
      await tester.pumpAndSettle();

      expect(find.text('1 result'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('https://flutter.dev'), findsOneWidget);
    });

    testWidgets('the todo tool shows the task list', (tester) async {
      await _pump(
        tester,
        const ToolCall(
          name: 'todo_list',
          summary: '',
          resultData: {
            'todos': [
              {'id': '1', 'content': 'Read logs', 'status': 'completed'},
              {'id': '2', 'content': 'Fix timer', 'status': 'in_progress'},
            ],
          },
        ),
      );

      await tester.tap(find.text('todo_list'));
      await tester.pumpAndSettle();

      expect(find.text('Read logs'), findsOneWidget);
      expect(find.text('Fix timer'), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
    });

    testWidgets('an edit shows its diff without the terminal colours', (
      tester,
    ) async {
      await _pump(
        tester,
        const ToolCall(
          name: 'patch',
          summary: 'a.txt',
          diff: '\x1B[31m-old\x1B[0m\n\x1B[32m+new\x1B[0m',
        ),
      );

      await tester.tap(find.text('patch'));
      await tester.pumpAndSettle();

      expect(find.byType(ToolDiffBody), findsOneWidget);
      expect(
        find.textContaining('-old\n+new', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a tool view falls back to input and result when the shape '
        'is not the one it knows', (tester) async {
      await _pump(
        tester,
        const ToolCall(name: 'web_search', summary: 'x', result: 'oops'),
      );

      await tester.tap(find.text('web_search'));
      await tester.pumpAndSettle();

      expect(find.text('Result'), findsOneWidget);
    });
  });
}
