import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_card_model.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_models.dart';
import 'package:hermes_app/src/bot_screen/install/install_state.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

import 'bot_screen_card_test.dart' show pumpCard;

const _install = 'Install on Server';

/// The states and results of Install on Server.
void main() {
  group('Install on Server', () {
    testWidgets('is offered when the model allows it, and presses', (
      tester,
    ) async {
      var pressed = 0;
      final trail = BreadcrumbTrail();
      await pumpCard(
        tester,
        const BotScreenNotInstalled(
          command: 'sudo apt-get install',
          canInstall: true,
        ),
        onInstall: () => pressed++,
        breadcrumbs: Breadcrumbs.of(trail),
      );

      await tester.tap(find.text(_install));

      expect(pressed, 1);
      expect([
        for (final c in trail.recent) '${c.name} ${c.attributes}',
      ], contains('bot_screen.install.pressed {}'));
    });

    testWidgets('is hidden when the model does not allow it', (tester) async {
      await pumpCard(
        tester,
        const BotScreenNotInstalled(command: 'sudo apt-get install'),
        onInstall: () {},
      );

      expect(find.text(_install), findsNothing);
    });

    testWidgets('is hidden without a callback', (tester) async {
      await pumpCard(
        tester,
        const BotScreenNotInstalled(
          command: 'sudo apt-get install',
          canInstall: true,
        ),
      );

      expect(find.text(_install), findsNothing);
    });

    testWidgets('a sandboxed profile keeps the sentence and gets no button', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const BotScreenNotInstalled(sandbox: true),
        onInstall: () {},
      );

      expect(find.textContaining('sandbox image'), findsOne);
      expect(find.text(_install), findsNothing);
    });
  });

  group('Installing', () {
    testWidgets('shows a spinner, the lines and that the install goes on', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const BotScreenInstalling(
          lines: ['Reading package lists…', 'Setting up x'],
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOne);
      expect(find.text('Reading package lists…'), findsOne);
      expect(find.text('Setting up x'), findsOne);
      expect(
        find.text('You can close this; the install keeps going.'),
        findsOne,
      );
      expect(find.text(_install), findsNothing);
    });

    testWidgets('with no line yet shows only the spinner and the note', (
      tester,
    ) async {
      await pumpCard(tester, const BotScreenInstalling());

      expect(find.text('Installing the desktop on the server…'), findsOne);
    });
  });

  group('results', () {
    Future<void> pumpResult(WidgetTester tester, InstallResult result) =>
        pumpCard(
          tester,
          BotScreenNotInstalled(
            command: 'sudo apt-get install',
            canInstall: true,
            result: result,
          ),
          onInstall: () {},
          onCopyCommand: () {},
        );

    testWidgets('refused says it could not start, with the server\'s words', (
      tester,
    ) async {
      await pumpResult(
        tester,
        const InstallRefused(message: 'an install is already running'),
      );

      expect(find.text("Couldn't start the install."), findsOne);
      expect(find.text('an install is already running'), findsOne);
      expect(find.text(_install), findsOne);
    });

    testWidgets('unreachable says why there was no answer', (tester) async {
      await pumpResult(
        tester,
        const InstallUnreachable(BotScreenFailure.timeout),
      );

      expect(find.text("Couldn't start the install."), findsOne);
      expect(find.text('Hermes did not answer in time.'), findsOne);
    });

    testWidgets('cancelled says so and offers it again', (tester) async {
      await pumpResult(tester, const InstallCancelled());

      expect(find.text('The install was cancelled.'), findsOne);
      expect(find.text(_install), findsOne);
    });

    testWidgets('no sudo says so and shows the command to run by hand', (
      tester,
    ) async {
      await pumpResult(
        tester,
        const InstallNoSudo(command: 'sudo apt-get install'),
      );

      expect(find.textContaining('no sudo'), findsOne);
      expect(find.text('sudo apt-get install'), findsOne);
      expect(find.text('Copy'), findsOne);
    });

    testWidgets('failed says so with the last lines', (tester) async {
      await pumpResult(
        tester,
        const InstallFailed(lines: ['E: unable to locate package']),
      );

      expect(find.text('The install failed.'), findsOne);
      expect(find.text('E: unable to locate package'), findsOne);
      expect(find.text(_install), findsOne);
    });

    testWidgets('may still run says to check again later', (tester) async {
      await pumpResult(tester, const InstallMayStillRun());

      expect(
        find.text('The install may still be running. Check again later.'),
        findsOne,
      );
    });
  });

  testWidgets('installing is recorded by a fixed word', (tester) async {
    final trail = BreadcrumbTrail();
    await pumpCard(
      tester,
      const BotScreenInstalling(lines: ['secret path']),
      breadcrumbs: Breadcrumbs.of(trail),
    );

    expect(
      [for (final c in trail.recent) '${c.name} ${c.attributes}'],
      ['bot_screen.card.shown {state: installing}'],
    );
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('every install state builds on $platform', (tester) async {
      for (final model in <BotScreenCardModel>[
        const BotScreenInstalling(lines: ['one']),
        const BotScreenNotInstalled(
          command: 'x',
          canInstall: true,
          result: InstallFailed(lines: ['E: no']),
        ),
        const BotScreenNotInstalled(
          command: 'x',
          canInstall: true,
          result: InstallRefused(message: 'busy'),
        ),
      ]) {
        await pumpCard(
          tester,
          model,
          platform: platform,
          onInstall: () {},
          onCopyCommand: () {},
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}
