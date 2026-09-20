import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart'
    show kAnswerFailedMessage;
import 'package:hermes_app/src/chat/widgets/unsupported_request_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pump(
  WidgetTester tester,
  UnsupportedRequest request, {
  Future<void> Function()? onSkip,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: UnsupportedRequestCard(request: request, onSkip: onSkip),
    ),
  ),
);

void main() {
  testWidgets('a sudo request says the app cannot ask for it yet', (
    tester,
  ) async {
    await _pump(
      tester,
      const UnsupportedRequest(requestId: 'r', kind: UnsupportedKind.sudo),
    );

    expect(find.text('Hermes needs something else'), findsOneWidget);
    expect(
      find.text(
        'Hermes asked for your sudo password. This app cannot ask for it yet. '
        'Answer it in the Hermes terminal or dashboard.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a secret request names a secret value', (tester) async {
    await _pump(
      tester,
      const UnsupportedRequest(requestId: 'r', kind: UnsupportedKind.secret),
    );

    expect(
      find.text(
        'Hermes asked for a secret value, such as an API key. This app '
        'cannot ask for it yet. Answer it in the Hermes terminal or dashboard.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the card collects nothing and only offers to skip', (
    tester,
  ) async {
    await _pump(
      tester,
      const UnsupportedRequest(requestId: 'r', kind: UnsupportedKind.secret),
      onSkip: () async {},
    );

    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('skip is disabled while the answer is in flight', (tester) async {
    final gate = Completer<void>();
    await _pump(
      tester,
      const UnsupportedRequest(requestId: 'r', kind: UnsupportedKind.sudo),
      onSkip: () => gate.future,
    );

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    gate.complete();
    await tester.pump();
  });

  testWidgets('a skip that fails says so and can be tried again', (
    tester,
  ) async {
    await _pump(
      tester,
      const UnsupportedRequest(requestId: 'r', kind: UnsupportedKind.sudo),
      onSkip: () async => throw Exception('socket closed'),
    );

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text(kAnswerFailedMessage), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('a skipped request says so and has no button', (tester) async {
    await _pump(
      tester,
      const UnsupportedRequest(
        requestId: 'r',
        kind: UnsupportedKind.sudo,
        status: InputRequestStatus.answered,
      ),
      onSkip: () async {},
    );

    expect(find.text('You skipped this request'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('an expired request says it timed out', (tester) async {
    await _pump(
      tester,
      const UnsupportedRequest(
        requestId: 'r',
        kind: UnsupportedKind.sudo,
        status: InputRequestStatus.expired,
      ),
    );

    expect(find.text('This request timed out'), findsOneWidget);
    expect(find.textContaining('terminal or dashboard'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
