import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/widgets/clarify_card.dart';
import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: ['once', 'deny'],
);

const _single = ClarifyRequest(
  requestId: 'r2',
  questions: [
    ClarifyQuestion(
      qid: '',
      question: 'Which colour?',
      choices: ['red', 'blue'],
    ),
  ],
);

const _batch = ClarifyRequest(
  requestId: 'r3',
  batch: true,
  questions: [
    ClarifyQuestion(qid: 'a', question: 'Your name?'),
    ClarifyQuestion(qid: 'b', question: 'Pick', choices: ['x', 'y']),
  ],
);

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody(const []));
    transport = FakeChatTransport();
  });

  /// Sends a prompt and has the agent raise [request] mid-turn.
  Future<FakeSend> raise(WidgetTester tester, ChatEvent request) async {
    await pumpChatScreen(tester, server: server, transport: transport);
    await tester.enterText(find.byType(EditableText), 'clean up');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    final turn = transport.sends.single;
    turn.emit(request);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return turn;
  }

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  /// Finds [matching] inside the clarify card, not the composer beside it.
  Finder inCard(Finder matching) =>
      find.descendant(of: find.byType(ClarifyCard), matching: matching);

  testWidgets('an approval shows a card, and no thinking indicator', (
    tester,
  ) async {
    await raise(tester, const ApprovalRequested(_approval));

    expect(find.byType(ApprovalCard), findsOneWidget);
    expect(find.text('rm -rf build'), findsOneWidget);
    expect(find.byType(ThinkingIndicator), findsNothing);
    await settle(tester);
  });

  testWidgets('allowing an approval sends it and locks the card', (
    tester,
  ) async {
    await raise(tester, const ApprovalRequested(_approval));

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(transport.approvalAnswers, [('r1', 'once')]);
    expect(find.text('Allowed once'), findsOneWidget);
    expect(find.text('Allow once'), findsNothing);
    await settle(tester);
  });

  testWidgets('an approval the backend no longer holds locks as expired', (
    tester,
  ) async {
    transport.accepts = false;
    await raise(tester, const ApprovalRequested(_approval));

    await tester.tap(find.text('Deny'));
    await tester.pump();

    expect(find.text('This request timed out'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a failed answer keeps the card open with an error', (
    tester,
  ) async {
    transport.answerError = Exception('socket closed');
    await raise(tester, const ApprovalRequested(_approval));

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(find.text('Could not send your answer. Try again.'), findsOneWidget);
    expect(find.text('Allow once'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('an expire event locks a pending card', (tester) async {
    final turn = await raise(tester, const ApprovalRequested(_approval));

    turn.emit(const InputRequestExpired('r1'));
    await tester.pump();

    expect(find.text('This request timed out'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a single clarify answer goes out without a question id', (
    tester,
  ) async {
    await raise(tester, const ClarifyRequested(_single));

    await tester.tap(find.text('blue'));
    await tester.pump();
    await tester.tap(inCard(find.widgetWithText(FilledButton, 'Send')));
    await tester.pump();

    expect(transport.clarifyAnswers.single.requestId, 'r2');
    expect(transport.clarifyAnswers.single.values, ['blue']);
    expect(transport.clarifyAnswers.single.questionId, isNull);
    await settle(tester);
  });

  testWidgets('a batch goes out one question id at a time', (tester) async {
    await raise(tester, const ClarifyRequested(_batch));

    await tester.enterText(inCard(find.byType(TextField)), 'Ada');
    await tester.tap(find.text('y'));
    await tester.pump();
    await tester.tap(inCard(find.widgetWithText(FilledButton, 'Confirm')));
    await tester.pump();

    expect(transport.clarifyAnswers.map((a) => a.questionId), ['a', 'b']);
    expect(transport.clarifyAnswers.map((a) => a.values), [
      ['Ada'],
      ['y'],
    ]);
    await settle(tester);
  });

  testWidgets('skipping a batch cancels it with one call', (tester) async {
    await raise(tester, const ClarifyRequested(_batch));

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(transport.clarifyAnswers.single.questionId, isNull);
    expect(transport.clarifyAnswers.single.values, isEmpty);
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.byType(ClarifyCard), findsOneWidget);
    await settle(tester);
  });

  testWidgets('finishing the reply expires a card nobody answered', (
    tester,
  ) async {
    final turn = await raise(tester, const ApprovalRequested(_approval));

    turn.emit(const ReplyCompleted('Done'));
    await tester.pump();

    expect(find.text('This request timed out'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a batch retries after a partial failure', (tester) async {
    transport.failClarifyCallNumber = 2;
    await raise(tester, const ClarifyRequested(_batch));

    await tester.enterText(inCard(find.byType(TextField)), 'Ada');
    await tester.tap(find.text('y'));
    await tester.pump();
    await tester.tap(inCard(find.widgetWithText(FilledButton, 'Confirm')));
    await tester.pump();

    expect(find.text('Could not send your answer. Try again.'), findsOneWidget);
    expect(
      inCard(find.widgetWithText(FilledButton, 'Confirm')),
      findsOneWidget,
    );
    expect(transport.clarifyAnswers.map((a) => a.questionId), ['a']);

    transport.failClarifyCallNumber = null;
    await tester.tap(inCard(find.widgetWithText(FilledButton, 'Confirm')));
    await tester.pump();

    expect(transport.clarifyAnswers.map((a) => a.questionId), ['a', 'a', 'b']);
    expect(transport.clarifyAnswers.map((a) => a.values), [
      ['Ada'],
      ['Ada'],
      ['y'],
    ]);
    expect(inCard(find.widgetWithText(FilledButton, 'Confirm')), findsNothing);
    expect(find.text('This request timed out'), findsNothing);
    await settle(tester);
  });

  testWidgets('an expiry during the answer is not overwritten by it', (
    tester,
  ) async {
    final gate = Completer<void>();
    transport.answerGate = gate;
    final turn = await raise(tester, const ApprovalRequested(_approval));

    await tester.tap(find.text('Allow once'));
    await tester.pump();
    turn.emit(const InputRequestExpired('r1'));
    await tester.pump();
    gate.complete();
    await tester.pump();

    expect(find.text('This request timed out'), findsOneWidget);
    expect(find.text('Allowed once'), findsNothing);
    await settle(tester);
  });
}
