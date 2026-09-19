import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _request = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete the build folder',
  choices: ['once', 'session', 'always', 'deny'],
);

Future<void> _pump(
  WidgetTester tester,
  ApprovalRequest request, {
  Future<void> Function(String)? onAnswer,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: ApprovalCard(request: request, onAnswer: onAnswer),
    ),
  ),
);

void main() {
  testWidgets('shows the description, the command and one button per choice', (
    tester,
  ) async {
    await _pump(tester, _request, onAnswer: (_) async {});

    expect(find.text('delete the build folder'), findsOneWidget);
    expect(find.text('rm -rf build'), findsOneWidget);
    for (final label in [
      'Allow once',
      'Allow for session',
      'Always allow',
      'Deny',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('offers only the choices the agent allows', (tester) async {
    const limited = ApprovalRequest(
      requestId: 'r1',
      command: 'x',
      description: 'y',
      choices: ['once', 'deny'],
    );

    await _pump(tester, limited, onAnswer: (_) async {});

    expect(find.text('Always allow'), findsNothing);
    expect(find.text('Allow for session'), findsNothing);
  });

  testWidgets('a tap sends the choice', (tester) async {
    final sent = <String>[];
    await _pump(tester, _request, onAnswer: (c) async => sent.add(c));

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(sent, ['once']);
  });

  testWidgets('always allow asks first and sends nothing on cancel', (
    tester,
  ) async {
    final sent = <String>[];
    await _pump(tester, _request, onAnswer: (c) async => sent.add(c));

    await tester.tap(find.text('Always allow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(sent, isEmpty);
  });

  testWidgets('always allow sends once confirmed', (tester) async {
    final sent = <String>[];
    await _pump(tester, _request, onAnswer: (c) async => sent.add(c));

    await tester.tap(find.text('Always allow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, always allow'));
    await tester.pumpAndSettle();

    expect(sent, ['always']);
  });

  testWidgets('buttons are disabled while the answer is in flight', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      _request,
      onAnswer: (_) {
        calls++;
        return Future<void>.delayed(const Duration(seconds: 1));
      },
    );

    await tester.tap(find.text('Allow once'));
    await tester.pump();
    await tester.tap(find.text('Allow once'), warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a failed answer shows an error and can be retried', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      _request,
      onAnswer: (_) async {
        calls++;
        if (calls == 1) throw Exception('socket closed');
      },
    );

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(find.text('Could not send your answer. Try again.'), findsOneWidget);

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(calls, 2);
    expect(find.text('Could not send your answer. Try again.'), findsNothing);
  });

  testWidgets('an answered request shows the outcome and no buttons', (
    tester,
  ) async {
    await _pump(tester, _request.answered('deny'), onAnswer: (_) async {});

    expect(find.text('Denied'), findsOneWidget);
    expect(find.text('Allow once'), findsNothing);
  });

  testWidgets('an expired request says so and has no buttons', (tester) async {
    await _pump(
      tester,
      _request.withStatus(InputRequestStatus.expired),
      onAnswer: (_) async {},
    );

    expect(find.text('This request timed out'), findsOneWidget);
    expect(find.text('Allow once'), findsNothing);
  });

  testWidgets('without a handler the buttons are disabled', (tester) async {
    await _pump(tester, _request);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Allow once'),
    );
    expect(button.onPressed, isNull);
  });
}
