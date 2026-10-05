import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/vault_request_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _saveLogin = VaultRequest(
  requestId: 'srq-1',
  kind: VaultKind.saveLogin,
  origin: 'https://www.example.com',
  site: 'www.example.com',
);

const _unlock = VaultRequest(
  requestId: 'srq-2',
  kind: VaultKind.unlock,
  backend: 'onepassword',
  displayName: '1Password',
);

const _code = VaultRequest(
  requestId: 'srq-3',
  kind: VaultKind.code,
  site: 'example.com',
  hint: 'The 6-digit code.',
);

Future<void> _pump(
  WidgetTester tester,
  VaultRequest request, {
  Future<void> Function(String, String, String)? onAnswer,
  Future<void> Function()? onSkip,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: VaultRequestCard(
        request: request,
        onAnswer: onAnswer,
        onSkip: onSkip,
      ),
    ),
  ),
);

void main() {
  testWidgets('the save-login card names the site and has masked fields', (
    tester,
  ) async {
    await _pump(tester, _saveLogin, onAnswer: (_, _, _) async {});

    expect(find.text('Save a login for www.example.com?'), findsOneWidget);
    expect(find.text('Username or email'), findsOneWidget);
    final password = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Password'),
    );
    expect(password.obscureText, isTrue);
    expect(find.text('Save login'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('Save stays disabled until both fields hold text', (
    tester,
  ) async {
    await _pump(tester, _saveLogin, onAnswer: (_, _, _) async {});

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save login'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Username or email'),
      'ada@example.com',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save login'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      's3cret',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save login'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('answering sends the values, Not now declines', (tester) async {
    final answers = <(String, String, String)>[];
    var skipped = false;
    await _pump(
      tester,
      _saveLogin,
      onAnswer: (identifier, password, code) async {
        answers.add((identifier, password, code));
      },
      onSkip: () async => skipped = true,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Username or email'),
      'ada@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      's3cret',
    );
    await tester.pump();
    await tester.tap(find.text('Save login'));
    await tester.pump();
    expect(answers.single, ('ada@example.com', 's3cret', ''));

    await _pump(
      tester,
      _saveLogin,
      onAnswer: (_, _, _) async {},
      onSkip: () async => skipped = true,
    );
    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(skipped, isTrue);
  });

  testWidgets('the unlock card asks for the master password only', (
    tester,
  ) async {
    await _pump(tester, _unlock, onAnswer: (_, _, _) async {});

    expect(find.text('Unlock 1Password'), findsOneWidget);
    expect(find.byType(TextField), findsOne);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
  });

  testWidgets('the code card shows the hint and sends the code', (
    tester,
  ) async {
    final answers = <String>[];
    await _pump(
      tester,
      _code,
      onAnswer: (_, _, code) async => answers.add(code),
    );

    expect(find.text('One-time code for example.com'), findsOneWidget);
    expect(find.text('The 6-digit code.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(answers.single, '123456');
  });

  testWidgets('an answered save-login says it was saved, a declined one does '
      'not pretend it was', (tester) async {
    await _pump(tester, _saveLogin.answered(identifier: 'ada@example.com'));

    expect(find.text('Login saved for www.example.com'), findsOneWidget);

    await _pump(tester, _saveLogin.withStatus(InputRequestStatus.answered));

    expect(find.text('You declined to save a login'), findsOneWidget);
  });

  testWidgets('an expired card only says so', (tester) async {
    await _pump(tester, _saveLogin.withStatus(InputRequestStatus.expired));

    expect(find.text('This request timed out'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
