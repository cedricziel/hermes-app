import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../../memory/memory_tool_fixtures.dart';

// Each body below paints a lone surrogate from the server; painting one
// throws "string is not well-formed UTF-16", which the tester reports.
Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 320, child: child)),
    ),
  ),
);

Future<void> _open(WidgetTester tester, ToolCall call) async {
  await _pump(tester, ToolCallCard(call: call));
  await tester.tap(find.text(call.name));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('a web search paints lone surrogates in a hit', (tester) async {
    await _open(
      tester,
      const ToolCall(
        name: 'web_search',
        summary: 's',
        resultData: {
          'data': {
            'web': [
              {
                'title': 'T\ud800',
                'url': 'https://x.invalid/\udc00',
                'description': 'D\ud800',
              },
            ],
          },
        },
      ),
    );
    expect(find.text('T�'), findsOneWidget);
  });

  testWidgets('a todo list paints a lone surrogate', (tester) async {
    await _open(
      tester,
      const ToolCall(
        name: 'todo_list',
        summary: '',
        resultData: {
          'todos': [
            {'id': '1', 'content': 'Read\ud800', 'status': 'pending'},
          ],
        },
      ),
    );
    expect(find.text('Read�'), findsOneWidget);
  });

  testWidgets('a memory call paints lone surrogates', (tester) async {
    await _open(
      tester,
      const ToolCall(
        name: 'memory',
        summary: 'memory',
        args: {
          'action': 'replace',
          'target': 'memory',
          'old_text': 'old\ud800',
          'content': 'new\ud800',
        },
        resultData: savedResult,
      ),
    );
    expect(find.textContaining('�', findRichText: true), findsWidgets);
  });

  testWidgets('a full memory warning paints a lone surrogate', (tester) async {
    await _open(
      tester,
      ToolCall(
        name: 'memory',
        summary: 'memory',
        status: ToolCallStatus.warning,
        args: replaceArgs,
        resultData: {...fullResult, 'error': '${fullResult['error']}\ud800'},
      ),
    );
  });

  testWidgets('process output paints a lone surrogate', (tester) async {
    await _pump(
      tester,
      const ProcessOutputCard(
        output: ProcessOutput(
          processId: 'worker\ud800',
          text: 'out\ud800',
          closed: true,
        ),
        initiallyOpen: true,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('out�', findRichText: true), findsOne);
  });

  testWidgets('a handoff receipt paints lone surrogates', (tester) async {
    await _open(
      tester,
      const ToolCall(
        name: 'message_agent',
        summary: 's',
        resultData: {
          'status': 'settled',
          'to': 'agent\ud800',
          'reply': 'reply\ud800',
          'error': 'err\ud800',
        },
      ),
    );
    expect(find.textContaining('reply�'), findsOneWidget);
  });

  testWidgets('a group label paints a lone surrogate in a tool name', (
    tester,
  ) async {
    await _pump(
      tester,
      const ToolCallGroup(
        calls: [
          ToolCall(name: 'a', summary: ''),
          ToolCall(
            name: 'run\ud800',
            summary: '',
            status: ToolCallStatus.running,
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('run�'), findsOneWidget);
  });
}
