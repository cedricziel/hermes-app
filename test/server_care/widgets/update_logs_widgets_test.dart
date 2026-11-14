import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/log_line.dart';
import 'package:hermes_app/src/server_care/widgets/command_row.dart';
import 'package:hermes_app/src/server_care/widgets/log_level_menu_button.dart';
import 'package:hermes_app/src/server_care/widgets/log_line_tile.dart';
import 'package:hermes_app/src/server_care/widgets/update_status_card.dart';
import 'package:hermes_app/src/server_care/widgets/update_step_list.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(platform: TargetPlatform.android),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('copying puts the command on the clipboard and announces it', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var calls = 0;
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      CommandRow(command: 'hermes update --yes', onCopied: () => calls++),
    );
    expect(find.bySemanticsLabel('Copy'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(copied, 'hermes update --yes');
    expect(calls, 1);
    expect(find.bySemanticsLabel('Command copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copy'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a step reads as its label and its state in words', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const UpdateStepList(
        steps: [
          UpdateStep.starting(UpdateStepState.done),
          UpdateStep.installing(UpdateStepState.running),
          UpdateStep.restarting(UpdateStepState.pending),
          UpdateStep.checking(UpdateStepState.failed),
        ],
        detailLines: ['one', 'two'],
      ),
    );
    expect(find.bySemanticsLabel('Starting the update, Done'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Downloading and installing, In progress'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r"Restarting Hermes, Waiting\. Chats continue when it's back\."),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Checking the result, Failed'),
      findsOneWidget,
    );
    expect(find.text('Show details'), findsOneWidget);
    // The card is titled "Updating…" and a failed step says Failed in words.
    expect(find.text('Updating…'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('one\ntwo'), findsNothing);
    await tester.tap(find.text('Show details'));
    // The running step's spinner never settles.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('one\ntwo'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a long traceback folds after three lines and unfolds', (
    tester,
  ) async {
    await _pump(
      tester,
      LogLineTile(
        time: '09:11:58',
        level: LogLevel.error,
        source: 'gateway.run',
        message: 'Unhandled error',
        continuation: [for (var i = 1; i <= 15; i++) 'frame $i'],
      ),
    );
    expect(find.text('frame 3'), findsOneWidget);
    expect(find.text('frame 4'), findsNothing);
    expect(find.text('Show 12 more lines'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);

    await tester.tap(find.text('Show 12 more lines'));
    await tester.pump();
    expect(find.text('frame 15'), findsOneWidget);
    expect(find.textContaining('more line'), findsNothing);
  });

  testWidgets('the level menu reports the chosen level', (tester) async {
    LogLevelFilter? chosen;
    await _pump(
      tester,
      Align(
        alignment: Alignment.centerLeft,
        child: LogLevelMenuButton(
          value: LogLevelFilter.all,
          onChanged: (v) => chosen = v,
        ),
      ),
    );
    expect(find.text('All levels'), findsOneWidget);
    await tester.tap(find.text('All levels'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Errors only'),
        matching: find.byType(CheckedPopupMenuItem<LogLevelFilter>),
      ),
    );
    await tester.pumpAndSettle();
    expect(chosen, LogLevelFilter.errors);
  });

  testWidgets('the status card fires its button', (tester) async {
    var updates = 0;
    await _pump(
      tester,
      UpdateStatusCard(
        status: const UpdateRollback(stableVersion: '0.22.0'),
        onUpdate: () => updates++,
      ),
    );
    expect(find.text('Move to 0.22.0'), findsOneWidget);
    expect(
      find.textContaining('This build is newer than stable release v0.22.0.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Move to 0.22.0'));
    expect(updates, 1);
  });

  testWidgets('a failed outcome offers Done and Try again', (tester) async {
    final pressed = <String>[];
    await _pump(
      tester,
      UpdateOutcomeCard(
        kind: UpdateOutcomeKind.failed,
        version: '0.22.2',
        onDone: () => pressed.add('done'),
        onTryAgain: () => pressed.add('again'),
      ),
    );
    expect(find.text('Hermes is still running 0.22.2.'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.tap(find.text('Try again'));
    expect(pressed, ['done', 'again']);
  });

  testWidgets('the cannot-apply card shows its command and a reachable Copy', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const UpdateStatusCard(
        status: UpdateCannotApply(
          message: 'Update Hermes on the server.',
          command: 'hermes update --yes',
        ),
      ),
    );
    expect(find.text('hermes update --yes'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Copy')),
      matchesSemantics(isButton: true, hasTapAction: true, label: 'Copy'),
    );
    handle.dispose();
  });

  testWidgets('a command in a section row keeps its text and Copy', (
    tester,
  ) async {
    await _pump(
      tester,
      GroupedSection(
        header: 'Things to fix',
        children: [
          Builder(
            builder: (context) => Padding(
              padding: EdgeInsets.symmetric(
                horizontal: GroupedMetrics.of(context).rowPadding,
                vertical: 8,
              ),
              child: const CommandRow(command: 'hermes tools install browser'),
            ),
          ),
        ],
      ),
    );
    expect(find.text('hermes tools install browser'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });
}
