import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/main.dart' as app;
import 'package:hermes_app/src/auth/token_store.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/server_care/widgets/server_status_card.dart';
import 'package:hermes_app/src/platform_hint/widgets/platform_hint_prompt.dart';
import 'package:integration_test/integration_test.dart';

const _shotsDir = String.fromEnvironment('HERMES_VERIFY_SHOTS');
const _reply = 'Scripted reply: the verify check reached the model.';
const _prompt = 'Say hello for the verify check';

/// Certifies the real Linux app end to end against the throwaway, password
/// gated dashboard that `scripts/verify.sh app` starts: it signs in through
/// the stand-in browser, sends a prompt and waits for the scripted model's
/// reply. Run it only through that script.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 1]) async {
    for (var i = 0; i < seconds * 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  String visibleTexts(WidgetTester tester) {
    final texts = <String>{};
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final value = text.data ?? text.textSpan?.toPlainText();
      if (value != null && value.trim().isNotEmpty) texts.add(value.trim());
    }
    return texts.map((t) => '"$t"').join(', ');
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    if (_shotsDir.isEmpty) return;
    final result = await Process.run('import', [
      '-window',
      'root',
      '$_shotsDir/$name.png',
    ]);
    if (result.exitCode != 0) {
      fail('screenshot $name failed: ${result.stderr}');
    }
  }

  /// Pumps until [finder] matches, failing with the visible texts after
  /// [timeout] and [what] naming the step.
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder,
    Duration timeout,
    String what,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail(
          '$what within ${timeout.inSeconds}s; visible texts: '
          '${visibleTexts(tester)}',
        );
      }
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// The prompt asking to tell the server about the app shows once after
  /// sign-in; it covers the chat.
  Future<void> dismissHint(WidgetTester tester) async {
    final hintPrompt = find.byType(PlatformHintPrompt);
    if (hintPrompt.evaluate().isEmpty) return;
    await tester.tap(
      find.descendant(of: hintPrompt, matching: find.text('Not now')),
    );
    await settle(tester);
  }

  testWidgets('sign in and get a scripted reply', (tester) async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await app.main();
    await settle(tester, 4);

    await dismissHint(tester);

    // 1. The sign-in screen for the dashboard.
    final signIn = find.text('Sign in with username & password');
    await waitFor(
      tester,
      signIn,
      const Duration(seconds: 30),
      'the sign-in screen did not appear',
    );
    await shot(tester, '01-sign-in');

    // 2. Sign in through the stand-in browser.
    await tester.tap(signIn);
    final composer = find.byKey(chatComposerFieldKey);
    await waitFor(
      tester,
      composer,
      const Duration(seconds: 60),
      'sign-in did not finish (no chat composer)',
    );
    await settle(tester, 2);
    // The session went to secure storage: the run's throwaway keyring, over
    // the Secret Service on the run's private D-Bus session.
    expect(
      await TokenStore.defaultStorage.containsKey(key: 'hermes.session.v1'),
      isTrue,
      reason: 'the signed-in session is not in secure storage',
    );
    await dismissHint(tester);
    await shot(tester, '02-signed-in');

    // 3. Send a prompt and wait for the scripted reply.
    await tester.enterText(composer, _prompt);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    await waitFor(
      tester,
      find.textContaining(_reply, findRichText: true),
      const Duration(seconds: 90),
      'the scripted reply did not appear',
    );
    await dismissHint(tester);
    await shot(tester, '03-reply');
    expect(find.textContaining(_reply, findRichText: true), findsWidgets);

    // 4. The Server screen: account menu, Server, status read from the
    // dashboard. Which headline shows depends on the backend's gateway and
    // disk, so only the card, the row and the absence of a failure are
    // asserted.
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.byTooltip('Account'));
    await settle(tester);
    final serverItem = find.text(l10n.serverCareTitle);
    await waitFor(
      tester,
      serverItem,
      const Duration(seconds: 10),
      'the account menu has no Server entry',
    );
    await tester.tap(serverItem.last);
    await waitFor(
      tester,
      find.text(l10n.serverCareVersionRow),
      const Duration(seconds: 30),
      'the Server screen did not show the Hermes version row',
    );
    await settle(tester, 2);
    expect(find.byType(ServerStatusCard), findsOneWidget);
    expect(find.text(l10n.serverCareHeadlineReadFailed), findsNothing);
    expect(find.text(l10n.serverCareHeadlineChecking), findsNothing);
    await shot(tester, '04-server');
  });
}
