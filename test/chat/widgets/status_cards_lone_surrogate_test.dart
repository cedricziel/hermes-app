import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_session_state.dart';
import 'package:hermes_app/src/chat/chat_warning_state.dart';
import 'package:hermes_app/src/chat/connector_operation_state.dart';
import 'package:hermes_app/src/chat/moa_progress_state.dart';
import 'package:hermes_app/src/chat/widgets/agent_notice_card.dart';
import 'package:hermes_app/src/chat/widgets/connector_operation_card.dart';
import 'package:hermes_app/src/chat/widgets/moa_progress_card.dart';
import 'package:hermes_app/src/chat/widgets/session_status_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';

import '../connector_fixtures.dart';

// Painting a lone surrogate throws "string is not well-formed UTF-16".
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('the output risk line paints a lone surrogate', (tester) async {
    await _pump(
      tester,
      const ToolCallCard(
        call: ToolCall(
          name: 'terminal',
          summary: 's',
          outputRisk: ToolOutputRisk(
            risk: 'secret\ud800',
            findings: [],
            redacted: true,
          ),
        ),
      ),
    );
    expect(find.textContaining('secret�'), findsOneWidget);
  });

  testWidgets('a connector card paints lone surrogates', (tester) async {
    final update = {
      ...connectionUpdateFixture,
      'targets': [
        {
          ...(connectionRequestFixture['targets']! as List).first as Map,
          'name': 'name\ud800',
          'instructions': 'steps\ud800',
        },
      ],
    };
    await _pump(
      tester,
      ConnectorOperationCard(
        operation: ConnectorOperationSnapshot.fromUpdate(update)!,
        initiallyOpen: true,
      ),
    );
    expect(find.text('name�'), findsOneWidget);
    expect(find.text('steps�'), findsOneWidget);
  });

  testWidgets('an agent notice paints a lone surrogate', (tester) async {
    await _pump(
      tester,
      const AgentNoticeCard(
        notice: AgentNotice(text: 'note\ud800'),
        initiallyOpen: true,
      ),
    );
    expect(find.textContaining('note�'), findsWidgets);
  });

  testWidgets('a MoA reference paints lone surrogates', (tester) async {
    await _pump(
      tester,
      const MoaProgressCard(
        progress: MoaProgress(
          turn: 'turn',
          references: [
            MoaReference(
              eventIdentity: 'one',
              label: 'Advisor\ud800',
              text: 'Answer\ud800',
            ),
          ],
        ),
        initiallyOpen: true,
      ),
    );
    expect(find.text('Advisor�'), findsOneWidget);
    expect(find.text('Answer�'), findsOneWidget);
  });

  testWidgets('the session status summary paints a lone surrogate', (
    tester,
  ) async {
    final state = ChatSessionState()
      ..control = const SessionControlSnapshot(
        revision: 'r',
        goal: {'status': 'paused\ud800'},
      );
    await _pump(tester, SessionStatusCard(state: state));
    expect(find.textContaining('paused�'), findsOneWidget);
  });
}
