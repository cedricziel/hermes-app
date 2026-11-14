import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_state_glyph.dart';
import 'package:hermes_app/src/chat/widgets/confirm_stop_program.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';

Future<void> pump(
  WidgetTester tester, {
  ProcessCardInfo? info,
  ProcessOutput output = const ProcessOutput(processId: 'p', text: 'out'),
  VoidCallback? onStop,
  bool open = true,
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme().copyWith(platform: platform),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProcessOutputCard(
          output: output,
          initiallyOpen: open,
          info: info,
          onStop: onStop,
        ),
      ),
    ),
  ),
);

ProcessCardInfo running({
  ProcessStopStatus stop = ProcessStopStatus.idle,
  bool seeded = false,
}) => ProcessCardInfo(
  command: 'npm test',
  status: ProcessCardStatus.running,
  runTime: const Duration(minutes: 2, seconds: 5),
  stop: stop,
  seeded: seeded,
);

void main() {
  group('state words', () {
    testWidgets('running shows the command, a spinner glyph and the time', (
      tester,
    ) async {
      await pump(tester, info: running(), open: false);
      expect(find.text('npm test'), findsOneWidget);
      expect(find.textContaining('Running · '), findsOneWidget);
      expect(find.byType(AgentStateGlyph), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-glyph-running-still')),
        findsOneWidget,
      );
      final command = tester.widget<Text>(find.text('npm test'));
      expect(command.style?.fontFamily, 'monospace');
      expect(command.maxLines, 2);
    });

    testWidgets('Stopped wins over a negative exit code', (tester) async {
      await pump(
        tester,
        info: const ProcessCardInfo(
          command: 'npm test',
          status: ProcessCardStatus.stopped,
          exitCode: -15,
          runTime: Duration(seconds: 30),
        ),
        open: false,
      );
      expect(find.textContaining('Stopped · '), findsOneWidget);
      expect(find.textContaining('Exited'), findsNothing);
      expect(find.textContaining('-15'), findsNothing);
      expect(find.byKey(const ValueKey('agent-glyph-stopped')), findsOneWidget);
    });

    testWidgets('exited reads the code, also zero, never Succeeded', (
      tester,
    ) async {
      for (final code in [1, 0]) {
        await pump(
          tester,
          info: ProcessCardInfo(
            command: 'npm test',
            status: ProcessCardStatus.exited,
            exitCode: code,
            runTime: const Duration(seconds: 14),
          ),
          open: false,
        );
        expect(
          find.textContaining('Exited with code $code · '),
          findsOneWidget,
        );
        expect(find.textContaining('Succe'), findsNothing);
        expect(find.byKey(const ValueKey('agent-glyph-ended')), findsOneWidget);
      }
    });

    testWidgets('ended has a word and a dash, and no time is just the word', (
      tester,
    ) async {
      await pump(
        tester,
        info: const ProcessCardInfo(
          command: 'x',
          status: ProcessCardStatus.ended,
        ),
        open: false,
      );
      expect(find.text('Ended'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-glyph-ended')), findsOneWidget);
    });

    testWidgets('no info keeps today\'s wording and shows no glyph', (
      tester,
    ) async {
      await pump(
        tester,
        output: const ProcessOutput(processId: 'p', closed: true),
        open: false,
      );
      expect(find.text('Process p · Closed'), findsOneWidget);
      expect(find.byType(AgentStateGlyph), findsNothing);
      await pump(tester, open: false);
      expect(find.text('Process p · Output received'), findsOneWidget);
      expect(find.byType(AgentStateGlyph), findsNothing);
    });

    testWidgets('German smoke check', (tester) async {
      await pump(
        tester,
        info: running(stop: ProcessStopStatus.killed),
        onStop: () {},
        locale: const Locale('de'),
      );
      expect(find.textContaining('Läuft'), findsOneWidget);
      expect(find.text('Running'), findsNothing);
    });
  });

  group('command', () {
    testWidgets('is cut at 200 characters with an ellipsis', (tester) async {
      final long = 'a' * 250;
      await pump(
        tester,
        info: ProcessCardInfo(command: long, status: ProcessCardStatus.running),
        open: false,
      );
      expect(find.text('${'a' * 200}…'), findsOneWidget);
      expect(processCommandLine('a' * 199), 'a' * 199);
      expect(processCommandLine('a' * 200), '${'a' * 200}…');
    });
  });

  group('seeded', () {
    testWidgets('shows the omission line above the text', (tester) async {
      await pump(tester, info: running(seeded: true));
      final line = find.text('Earlier output omitted');
      expect(line, findsOneWidget);
      expect(
        tester.getTopLeft(line).dy,
        lessThan(tester.getTopLeft(find.text('out')).dy),
      );
      await pump(tester, info: running());
      expect(find.text('Earlier output omitted'), findsNothing);
    });
  });

  group('Stop program', () {
    testWidgets('only while running and when onStop is given', (tester) async {
      await pump(tester, info: running());
      expect(find.byType(DestructiveTintButton), findsNothing);
      await pump(tester, info: running(), onStop: () {});
      expect(find.text('Stop program'), findsOneWidget);
      expect(find.byType(DestructiveTintButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      await pump(
        tester,
        info: const ProcessCardInfo(
          command: 'x',
          status: ProcessCardStatus.exited,
          exitCode: 0,
        ),
        onStop: () {},
      );
      expect(find.byType(DestructiveTintButton), findsNothing);
    });

    testWidgets('press calls onStop', (tester) async {
      var presses = 0;
      await pump(tester, info: running(), onStop: () => presses++);
      await tester.tap(find.text('Stop program'));
      expect(presses, 1);
    });

    testWidgets('sending shows the busy label and ignores presses', (
      tester,
    ) async {
      var presses = 0;
      await pump(
        tester,
        info: running(stop: ProcessStopStatus.sending),
        onStop: () => presses++,
      );
      expect(find.text('Stopping…'), findsOneWidget);
      expect(find.text('Stop program'), findsNothing);
      await tester.tap(find.text('Stopping…'));
      expect(presses, 0);
    });

    testWidgets('disabled while checking', (tester) async {
      var presses = 0;
      await pump(
        tester,
        info: running(stop: ProcessStopStatus.checking),
        onStop: () => presses++,
      );
      expect(find.text('Couldn\'t confirm the stop.'), findsOneWidget);
      expect(find.text('Checking…'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byType(DestructiveTintButton),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Stop program'), warnIfMissed: false);
      expect(presses, 0);
    });

    final outcomes = <ProcessStopStatus, (List<String>, bool)>{
      ProcessStopStatus.killed: (['Stopped'], false),
      ProcessStopStatus.alreadyEnded: (['It had already ended.'], false),
      ProcessStopStatus.notListed: (
        ['This program is no longer listed.'],
        false,
      ),
      ProcessStopStatus.failed: (
        ['Couldn\'t stop the program.', 'Try again.'],
        true,
      ),
      ProcessStopStatus.unconfirmed: (
        ['Couldn\'t confirm the stop.', 'It may still be running.'],
        true,
      ),
    };
    for (final MapEntry(key: stop, value: (words, back)) in outcomes.entries) {
      testWidgets('outcome ${stop.name}', (tester) async {
        await pump(
          tester,
          info: running(stop: stop),
          onStop: () {},
        );
        for (final word in words) {
          expect(find.text(word), findsWidgets);
        }
        expect(find.text('Stop program'), back ? findsOneWidget : findsNothing);
      });
    }
  });

  group('sizes', () {
    for (final (platform, height) in [
      (TargetPlatform.android, 48.0),
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.macOS, 28.0),
    ]) {
      testWidgets('Stop is $height high on $platform', (tester) async {
        await pump(tester, info: running(), onStop: () {}, platform: platform);
        expect(
          tester.getSize(find.byType(DestructiveTintButton)).height,
          greaterThanOrEqualTo(height),
        );
      });
    }

    testWidgets('honours the largest text size without overflow', (
      tester,
    ) async {
      await pump(
        tester,
        info: running(stop: ProcessStopStatus.failed, seeded: true),
        onStop: () {},
        textScale: 3,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('confirmation', () {
    Future<bool?> open(
      WidgetTester tester, {
      String command = 'npm test',
      TargetPlatform platform = TargetPlatform.android,
      Locale locale = const Locale('en'),
    }) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  answer = await confirmStopProgram(context, command: command),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('labels, message and Cancel first on Material', (tester) async {
      await open(tester, command: 'python -m http.server 8000 ' * 8);
      expect(find.text('Stop this program?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Stop program'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      final message = tester
          .widget<Text>(find.textContaining('Hermes ends'))
          .data!;
      expect(message, contains('python -m http.server'));
      expect(message, contains('…'));
      expect(message, isNot(contains('\n')));
      expect(
        tester.getTopLeft(find.text('Cancel')).dx,
        lessThan(tester.getTopLeft(find.text('Stop program')).dx),
      );
    });

    testWidgets('Cancel answers false, Stop true', (tester) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  answer = await confirmStopProgram(context, command: 'x'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(answer, isFalse);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop program'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });

    testWidgets('German alert on Apple platforms', (tester) async {
      await open(
        tester,
        platform: TargetPlatform.iOS,
        locale: const Locale('de'),
      );
      expect(find.text('Stop this program?'), findsNothing);
      expect(find.text('Abbrechen'), findsOneWidget);
    });

    test('command line collapses whitespace and cuts at 80', () {
      expect(confirmCommandLine('  a\n b  '), 'a b');
      expect(
        confirmCommandLine('x' * 100).runes.length,
        kConfirmCommandChars + 1,
      );
    });
  });
}
