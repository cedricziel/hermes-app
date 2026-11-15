import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_warning_state.dart';
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
  _groupGrowthTests();
  testWidgets('collapsed groups expose tool-output warnings', (tester) async {
    await _pump(tester, const [
      ToolCall(
        name: 'terminal',
        summary: '',
        outputRisk: ToolOutputRisk(
          risk: 'secret',
          findings: [],
          redacted: true,
        ),
      ),
      ToolCall(name: 'read_file', summary: ''),
    ]);
    expect(find.byTooltip('Tool output warning'), findsOneWidget);
  });
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

/// Rebuilds the group in place, as the chat does when a call arrives.
class _Host extends StatefulWidget {
  const _Host({super.key});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  List<ToolCall> calls = const [];
  Map<int, ApprovalRequest> approvals = const {};
  void set(List<ToolCall> next, {Map<int, ApprovalRequest>? held}) =>
      setState(() {
        calls = next;
        approvals = held ?? approvals;
      });
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ToolCallGroup(calls: calls, approvals: approvals),
      ),
    ),
  );
}

ToolCall _call(String id, {ToolCallStatus? status}) => ToolCall(
  id: id,
  name: 'tool_$id',
  summary: '',
  args: const {'q': 'INPUT-MARK'},
  status: status ?? ToolCallStatus.completed,
);

void _groupGrowthTests() {
  final host = GlobalKey<_HostState>();
  Future<void> setup(WidgetTester tester, List<ToolCall> calls) async {
    await tester.pumpWidget(_Host(key: host));
    host.currentState!.set(calls);
    await tester.pump();
  }

  Future<void> grow(WidgetTester tester, List<ToolCall> calls) async {
    host.currentState!.set(calls);
    await tester.pump();
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 400));
  }

  final input = find.textContaining('INPUT-MARK');

  testWidgets('1 to 2: the opened card stays open inside an opened group', (
    tester,
  ) async {
    await setup(tester, [_call('a')]);
    await tapIt(tester, find.byType(ToolCallCard));
    expect(input, findsOneWidget);

    await grow(tester, [
      _call('a'),
      _call('b', status: ToolCallStatus.running),
    ]);

    expect(find.text('Running tool_b…'), findsOneWidget);
    expect(find.byType(ToolCallCard), findsNWidgets(2));
    expect(input, findsOneWidget);
  });

  testWidgets('1 to 2 with nothing opened leaves the group folded', (
    tester,
  ) async {
    await setup(tester, [_call('a')]);

    await grow(tester, [_call('a'), _call('b')]);

    expect(find.byType(ToolCallCard), findsNothing);
    expect(find.text('Used 2 tools'), findsOneWidget);
  });

  testWidgets('2 to 3 keeps only the cards the reader opened open', (
    tester,
  ) async {
    await setup(tester, [_call('a'), _call('b')]);
    await tapIt(tester, find.text('Used 2 tools'));
    await tapIt(tester, find.byType(ToolCallCard).last);
    expect(input, findsOneWidget);

    await grow(tester, [_call('a'), _call('b'), _call('c')]);

    expect(find.byType(ToolCallCard), findsNWidgets(3));
    expect(input, findsOneWidget);
    final cards = tester
        .widgetList<ToolCallCard>(find.byType(ToolCallCard))
        .toList();
    expect(cards.map((c) => c.initiallyOpen), [false, true, false]);
  });

  testWidgets('a closed card is forgotten: the group opens without it', (
    tester,
  ) async {
    await setup(tester, [_call('a'), _call('b')]);
    await tapIt(tester, find.text('Used 2 tools'));
    await tapIt(tester, find.byType(ToolCallCard).first);
    await tapIt(tester, find.byType(ToolCallCard).first);
    await tapIt(tester, find.text('Used 2 tools'));
    await tapIt(tester, find.text('Used 2 tools'));

    expect(find.byType(ToolCallCard), findsNWidgets(2));
    expect(input, findsNothing);
  });

  testWidgets('a call that gets its id after it was opened stays open', (
    tester,
  ) async {
    await setup(tester, [_call('')]);
    await tapIt(tester, find.byType(ToolCallCard));
    expect(input, findsOneWidget);

    await grow(tester, [_call('a'), _call('b')]);

    expect(input, findsOneWidget);
  });

  testWidgets('open state follows the call, not its place in the run', (
    tester,
  ) async {
    await setup(tester, [_call('a'), _call('b')]);
    await tapIt(tester, find.text('Used 2 tools'));
    await tapIt(tester, find.byType(ToolCallCard).last);

    // The run is re-split: the first call leaves it.
    await grow(tester, [_call('b'), _call('c')]);
    await tapIt(tester, find.text('Used 2 tools'));
    await tapIt(tester, find.text('Used 2 tools'));

    final cards = tester
        .widgetList<ToolCallCard>(find.byType(ToolCallCard))
        .toList();
    expect(cards.map((c) => c.initiallyOpen), [true, false]);
  });

  testWidgets('an approval that arrives keeps the group open after an open '
      'card regrouped it', (tester) async {
    await setup(tester, [_call('a')]);
    await tapIt(tester, find.byType(ToolCallCard));
    await grow(tester, [
      _call('a'),
      _call('b', status: ToolCallStatus.running),
    ]);
    await tapIt(tester, find.text('Running tool_b…'));
    expect(find.byType(ToolCallCard), findsNothing);

    host.currentState!.set(
      [_call('a'), _call('b', status: ToolCallStatus.running)],
      held: const {
        1: ApprovalRequest(
          requestId: 'r1',
          command: 'rm',
          description: '',
          choices: ['once', 'deny'],
        ),
      },
    );
    await tester.pump();

    expect(find.text('Waiting on tool_b'), findsOneWidget);
    expect(find.byType(ApprovalCard), findsOneWidget);
  });

  testWidgets('the header still names the running call after a regroup', (
    tester,
  ) async {
    await setup(tester, [_call('a')]);
    await tapIt(tester, find.byType(ToolCallCard));
    await grow(tester, [
      _call('a'),
      _call('b', status: ToolCallStatus.running),
    ]);

    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('Running tool_b')), findsWidgets);
    handle.dispose();
  });
}
