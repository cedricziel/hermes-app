import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/tool_call_presentation.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_group.dart';

import '../support/fake_hermes_server.dart';

ChatEvent event(String type, Map<String, Object?> payload) => mapGatewayEvent(
  GatewayEvent(type: type, sessionId: 'runtime', payload: payload),
)!;

const label = {
  'kind': 'connector',
  'name': 'connectors__github__GITHUB_LIST_ISSUES',
  'text': 'GitHub · list issues',
  'preview': 'Release bugs',
};

void main() {
  test('gateway labels survive preparation, completion and later updates', () {
    final reply = ChatMessage(
      id: 'reply',
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime(2026),
    );
    applyReplyEvent(reply, const ToolPreparing('tool_call'));
    applyReplyEvent(
      reply,
      event('tool.start', {
        'tool_id': 'call-1',
        'name': 'tool_call',
        'labels': [
          null,
          {'text': 4},
          label,
        ],
      }),
    );
    expect(reply.toolCalls, hasLength(1));
    final call = reply.toolCalls.single;
    expect(call.displayName, 'GitHub · list issues');
    expect(call.displaySummary, 'Release bugs');
    expect(call.name, 'tool_call');
    expect(call.id, 'call-1');
    applyReplyEvent(
      reply,
      event('tool.complete', {
        'tool_id': 'call-1',
        'name': 'tool_call',
        'result': {'ok': true},
      }),
    );
    expect(reply.toolCalls.single.status, ToolCallStatus.completed);
    expect(reply.toolCalls.single.displayName, 'GitHub · list issues');

    // Some hosts only attach the human label to the completion payload.
    applyReplyEvent(reply, const ToolStarted(id: 'call-2', name: 'tool_call'));
    applyReplyEvent(
      reply,
      event('tool.complete', {
        'tool_id': 'call-2',
        'name': 'tool_call',
        'labels': [label],
        'result': 'Done',
      }),
    );
    expect(reply.toolCalls.last.displayName, 'GitHub · list issues');
  });

  test(
    'history resolves the inner tool without changing its stored identity',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions/history/messages',
          messageListBody('history', [
            {
              ...messageRow(id: 1, role: 'assistant', content: ''),
              'tool_calls': [
                {
                  'id': 'history-call',
                  'type': 'function',
                  'function': {
                    'name': 'tool_call',
                    'arguments': jsonEncode({
                      'name': 'read_file',
                      'arguments': {'path': 'lib/main.dart'},
                    }),
                  },
                },
              ],
            },
          ]),
        );
      final messages = await HermesChatRepository(server.client().raw)
          .loadMessages('history');
      final call = messages.single.toolCalls.single;
      expect(call.displayName, 'read_file');
      expect(call.displaySummary, 'lib/main.dart');
      expect(call.id, 'history-call');
      expect(call.name, 'tool_call');
    },
  );

  test(
    'search, describe and malformed bridge arguments have honest fallbacks',
    () {
      expect(
        const ToolCall(
          name: 'tool_search',
          summary: '',
          args: {
            'queries': ['find github issues'],
          },
        ).displaySummary,
        'find github issues',
      );
      expect(
        const ToolCall(
          name: 'tool_describe',
          summary: '',
          args: {
            'names': ['read_file'],
          },
        ).displayName,
        'Tool details',
      );
      expect(
        const ToolCall(
          name: 'tool_call',
          summary: '',
          args: {'calls': 'invalid'},
        ).displayName,
        'Unnamed tool',
      );
      expect(
        const ToolCall(
          name: 'tool_call',
          summary: '',
          preparing: true,
        ).displayName,
        'Tool call',
      );
      expect(
        const ToolCall(name: 'terminal', summary: 'ls').displayName,
        'terminal',
      );
    },
  );

  testWidgets('batch cards name every target on expansion and keep raw input', (
    tester,
  ) async {
    const call = ToolCall(
      name: 'tool_call',
      summary: '',
      args: {
        'calls': [
          {
            'name': 'read_file',
            'arguments': {'path': 'lib/main.dart'},
          },
          {'name': 'mcp__github__list_issues', 'arguments': {}},
        ],
      },
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 320, child: ToolCallCard(call: call)),
        ),
      ),
    );
    expect(find.text('read_file +1'), findsOneWidget);
    expect(find.text('tool_call'), findsNothing);
    await tester.tap(find.text('read_file +1'));
    await tester.pumpAndSettle();
    expect(find.text('Dispatcher'), findsNothing);
    expect(find.text('Path'), findsOneWidget);
    expect(find.text('lib/main.dart'), findsOneWidget);
    expect(find.textContaining('github · list issues'), findsOneWidget);
    await tester.tap(find.text('Raw arguments'));
    await tester.pumpAndSettle();
    expect(find.text('Dispatcher'), findsOneWidget);
    expect(find.text('tool_call'), findsOneWidget);
    expect(find.text('Input'), findsOneWidget);
  });

  testWidgets(
    'command arguments stay selectable and preserve shell whitespace',
    (tester) async {
      const command =
          "printf '%s\\n' 'a && b'\npython - <<'PY'\n  print('indented')\nPY";
      const call = ToolCall(
        name: 'tool_call',
        summary: '',
        args: {
          'name': 'terminal',
          'arguments': {
            'command': command,
            'workdir': '/workspace/project',
            'timeout_s': 60,
            'background': false,
            'options': {
              'paths': ['lib', 'test'],
            },
          },
        },
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: ToolCallCard(call: call, initiallyOpen: true),
            ),
          ),
        ),
      );
      expect(find.text('Command'), findsOneWidget);
      expect(find.text('Working directory'), findsOneWidget);
      expect(find.text('Timeout (seconds)'), findsOneWidget);
      expect(find.text('false'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is SelectableText && widget.data == command,
        ),
        findsOneWidget,
      );
      expect(find.textContaining('"paths": [\n'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a running group uses the inner name and fits a narrow phone', (
    tester,
  ) async {
    const call = ToolCall(
      name: 'tool_call',
      summary: '',
      status: ToolCallStatus.running,
      labels: [
        ToolLabel(
          name: 'plugin',
          text: 'A plugin tool with a very long descriptive name',
        ),
      ],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 250,
            child: ToolCallGroup(
              calls: [
                ToolCall(name: 'read_file', summary: ''),
                call,
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Running A plugin tool with a very long descriptive name…'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
