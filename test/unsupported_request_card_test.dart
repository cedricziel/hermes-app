import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/unsupported_request_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Future<void> _pump(WidgetTester tester, UnsupportedRequest request) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(body: UnsupportedRequestCard(request: request)),
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

  testWidgets('the card collects nothing', (tester) async {
    await _pump(
      tester,
      const UnsupportedRequest(requestId: 'r', kind: UnsupportedKind.secret),
    );

    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(ButtonStyleButton), findsNothing);
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
  });
}
