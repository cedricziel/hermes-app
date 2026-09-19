import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/clarify_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _single = ClarifyRequest(
  requestId: 'r1',
  questions: [
    ClarifyQuestion(
      qid: '',
      question: 'Which colour?',
      choices: ['red', 'blue'],
    ),
  ],
);

const _batch = ClarifyRequest(
  requestId: 'r2',
  batch: true,
  questions: [
    ClarifyQuestion(qid: 'a', question: 'Your name?'),
    ClarifyQuestion(
      qid: 'b',
      question: 'Toppings?',
      choices: ['ham', 'olives', 'onion'],
      multiSelect: true,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  ClarifyRequest request, {
  Future<void> Function(Map<String, List<String>>)? onAnswer,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ClarifyCard(request: request, onAnswer: onAnswer),
      ),
    ),
  ),
);

Finder _send() => find.widgetWithText(FilledButton, 'Send');

Finder _confirm() => find.widgetWithText(FilledButton, 'Confirm');

void main() {
  testWidgets('a single question shows its choices; Send needs a pick', (
    tester,
  ) async {
    await _pump(tester, _single, onAnswer: (_) async {});

    expect(find.text('Which colour?'), findsOneWidget);
    expect(find.text('red'), findsOneWidget);
    expect(tester.widget<FilledButton>(_send()).onPressed, isNull);

    await tester.tap(find.text('blue'));
    await tester.pump();

    expect(tester.widget<FilledButton>(_send()).onPressed, isNotNull);
  });

  testWidgets('a single choice replaces the earlier pick', (tester) async {
    final sent = <Map<String, List<String>>>[];
    await _pump(tester, _single, onAnswer: (a) async => sent.add(a));

    await tester.tap(find.text('red'));
    await tester.tap(find.text('blue'));
    await tester.pump();
    await tester.tap(_send());
    await tester.pump();

    expect(sent.single, {
      '': ['blue'],
    });
  });

  testWidgets('an open-ended question sends the typed text', (tester) async {
    const open = ClarifyRequest(
      requestId: 'r1',
      questions: [ClarifyQuestion(qid: '', question: 'Your name?')],
    );
    final sent = <Map<String, List<String>>>[];
    await _pump(tester, open, onAnswer: (a) async => sent.add(a));

    await tester.enterText(find.byType(TextField), '  Ada ');
    await tester.pump();
    await tester.tap(_send());
    await tester.pump();

    expect(sent.single, {
      '': ['Ada'],
    });
  });

  testWidgets('Confirm waits until every batch question has an answer', (
    tester,
  ) async {
    final sent = <Map<String, List<String>>>[];
    await _pump(tester, _batch, onAnswer: (a) async => sent.add(a));
    expect(tester.widget<FilledButton>(_confirm()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    expect(tester.widget<FilledButton>(_confirm()).onPressed, isNull);

    await tester.tap(find.text('ham'));
    await tester.tap(find.text('onion'));
    await tester.pump();
    expect(tester.widget<FilledButton>(_confirm()).onPressed, isNotNull);

    await tester.tap(_confirm());
    await tester.pump();

    expect(sent.single, {
      'a': ['Ada'],
      'b': ['ham', 'onion'],
    });
  });

  testWidgets('tapping a picked multi-select choice again drops it', (
    tester,
  ) async {
    final sent = <Map<String, List<String>>>[];
    await _pump(tester, _batch, onAnswer: (a) async => sent.add(a));

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.text('ham'));
    await tester.tap(find.text('olives'));
    await tester.tap(find.text('ham'));
    await tester.pump();
    await tester.tap(_confirm());
    await tester.pump();

    expect(sent.single['b'], ['olives']);
  });

  testWidgets('Skip sends an empty answer set', (tester) async {
    final sent = <Map<String, List<String>>>[];
    await _pump(tester, _batch, onAnswer: (a) async => sent.add(a));

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(sent.single, isEmpty);
  });

  testWidgets('a failed answer shows an error and can be retried', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      _single,
      onAnswer: (_) async {
        calls++;
        if (calls == 1) throw Exception('socket closed');
      },
    );
    await tester.tap(find.text('red'));
    await tester.pump();

    await tester.tap(_send());
    await tester.pump();
    expect(find.text('Could not send your answer. Try again.'), findsOneWidget);

    await tester.tap(_send());
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Could not send your answer. Try again.'), findsNothing);
  });

  testWidgets('an answered request lists the answers and no controls', (
    tester,
  ) async {
    await _pump(
      tester,
      _batch.answeredWith({
        'a': ['Ada'],
        'b': ['ham', 'onion'],
      }),
      onAnswer: (_) async {},
    );

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('ham, onion'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a skipped request says so', (tester) async {
    await _pump(tester, _single.answeredWith(const {}), onAnswer: (_) async {});

    expect(find.text('Skipped'), findsOneWidget);
  });

  testWidgets('an expired request says so and has no controls', (tester) async {
    await _pump(
      tester,
      _single.withStatus(InputRequestStatus.expired),
      onAnswer: (_) async {},
    );

    expect(find.text('This request timed out'), findsOneWidget);
    expect(find.text('red'), findsNothing);
  });
}
