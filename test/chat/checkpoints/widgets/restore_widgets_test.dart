import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_state.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_all_confirmation.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_file_confirmation.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_outcome_note.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = const Size(390, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: app!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 640),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

RestoreFileConfirmation _file({
  bool agentWorking = false,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
}) => RestoreFileConfirmation(
  fileName: 'src/auth/token_refresh.dart',
  timeLabel: '12 min ago',
  reason: CheckpointReason.beforeEdit,
  agentWorking: agentWorking,
  onConfirm: onConfirm ?? () {},
  onCancel: onCancel ?? () {},
);

RestoreAllConfirmation _all({
  int? differingFiles = 5,
  String? quotedPrompt = 'Split the token refresh out',
  bool replying = false,
  VoidCallback? onConfirm,
}) => RestoreAllConfirmation(
  timeLabel: '12 min ago',
  reason: CheckpointReason.beforeEdit,
  differingFiles: differingFiles,
  quotedPrompt: quotedPrompt,
  replying: replying,
  onConfirm: onConfirm ?? () {},
  onCancel: () {},
);

String? _primaryFocusLabel() {
  final focus = FocusManager.instance.primaryFocus;
  final context = focus?.context;
  if (context == null) return null;
  String? label;
  void visit(Element element) {
    if (label != null) return;
    final widget = element.widget;
    if (widget is Text) {
      label = widget.data;
      return;
    }
    element.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
  return label;
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('RestoreFileConfirmation', () {
    testWidgets('says what goes back, to when, and what it overwrites', (
      tester,
    ) async {
      await _pump(tester, _file());
      expect(find.text('Restore this file?'), findsOneWidget);
      expect(
        find.text(
          'src/auth/token_refresh.dart goes back to how it was 12 min ago, '
          'before editing a file. Changes made to it since, by you or Hermes, '
          'will be overwritten. Hermes tries to save the current version '
          "first. Your chat isn't changed. Another chat working in this "
          'folder can change this file again.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Hermes is working in this folder right now. It may change the file '
          'again.',
        ),
        findsNothing,
      );
    });

    testWidgets('adds the warning while the agent works', (tester) async {
      await _pump(tester, _file(agentWorking: true));
      expect(
        find.text(
          'Hermes is working in this folder right now. It may change the file '
          'again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('leaves the reason out when it is not known', (tester) async {
      await _pump(
        tester,
        RestoreFileConfirmation(
          fileName: 'a.dart',
          timeLabel: '12 min ago',
          reason: CheckpointReason.other,
          onConfirm: () {},
          onCancel: () {},
        ),
      );
      expect(
        find.textContaining('a.dart goes back to how it was 12 min ago. '),
        findsOneWidget,
      );
    });

    testWidgets('Cancel has the first focus and Restore is not filled', (
      tester,
    ) async {
      await _pump(tester, _file());
      expect(_primaryFocusLabel(), 'Cancel');
      expect(find.byType(DestructiveTintButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Cancel'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Android: two text buttons, Cancel first, Restore in red', (
      tester,
    ) async {
      await _pump(tester, _file(), platform: TargetPlatform.android);
      expect(_primaryFocusLabel(), 'Cancel');
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(DestructiveTintButton), findsNothing);
      final cancel = tester.getTopLeft(find.text('Cancel'));
      final restore = tester.getTopLeft(find.text('Restore file'));
      expect(cancel.dx, lessThan(restore.dx));
      final text = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Restore file'),
      );
      final color = text.style!.foregroundColor!.resolve({});
      expect(color, buildHermesLightTheme().colorScheme.error);
    });

    testWidgets('buttons stack at the largest text and the body scrolls', (
      tester,
    ) async {
      await _pump(tester, _file(agentWorking: true), scale: 3);
      expect(tester.takeException(), isNull);
      final cancel = tester.getRect(find.byType(FilledButton));
      final restore = tester.getRect(find.byType(DestructiveTintButton));
      expect(restore.top, greaterThanOrEqualTo(cancel.bottom));
      expect(restore.width, cancel.width);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('buttons sit side by side at the normal size', (tester) async {
      await _pump(tester, _file());
      final cancel = tester.getRect(find.byType(FilledButton));
      final restore = tester.getRect(find.byType(DestructiveTintButton));
      expect(restore.left, greaterThan(cancel.right));
      expect(restore.top, cancel.top);
    });

    testWidgets('the buttons call back', (tester) async {
      var confirmed = 0;
      var cancelled = 0;
      await _pump(
        tester,
        _file(onConfirm: () => confirmed++, onCancel: () => cancelled++),
      );
      await tester.tap(find.text('Cancel'));
      await tester.tap(find.text('Restore file'));
      expect((confirmed, cancelled), (1, 1));
    });

    testWidgets('reads in German', (tester) async {
      await _pump(tester, _file(), locale: const Locale('de'));
      expect(find.text('Diese Datei wiederherstellen?'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
    });
  });

  group('RestoreAllConfirmation', () {
    testWidgets('lists what happens, then the warning, the quote, the note', (
      tester,
    ) async {
      await _pump(tester, _all());
      for (final text in [
        'Restore all files?',
        'Files in this folder go back to how they were 12 min ago, before '
            'editing a file.',
        '5 files differ now. Changes made since, by you or Hermes, will be '
            'overwritten.',
        'Files created after that stay where they are.',
        'Hermes tries to save the current state first.',
        'Another chat working in this folder can change these files again.',
        'This also removes your last message and Hermes\' answers after it '
            'from this chat.',
        'Split the token refresh out',
        'If this is the message removed, it goes back into the message box, '
            'unsent.',
        "Chats don't track which message a checkpoint belongs to, so only "
            'your last message is removed, whichever checkpoint you pick. '
            'Other chats in this folder keep their messages but see the '
            'restored files.',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(
        find.textContaining("aren't in checkpoints: this leaves them as they"),
        findsOneWidget,
      );
    });

    testWidgets('says some files differ when the number is unknown', (
      tester,
    ) async {
      await _pump(tester, _all(differingFiles: null));
      expect(find.textContaining('Some files differ now.'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d files differ now')), findsNothing);
    });

    testWidgets('says one file differs', (tester) async {
      await _pump(tester, _all(differingFiles: 1));
      expect(find.textContaining('1 file differs now.'), findsOneWidget);
    });

    testWidgets('hides the quote when there is no message to hand back', (
      tester,
    ) async {
      await _pump(tester, _all(quotedPrompt: null));
      expect(
        find.textContaining('goes back into the message box'),
        findsNothing,
      );
      expect(find.text('Split the token refresh out'), findsNothing);
      expect(
        find.textContaining('This also removes your last message'),
        findsOneWidget,
      );
    });

    testWidgets('cuts a long quote after four lines', (tester) async {
      await _pump(tester, _all(quotedPrompt: 'Split the token refresh. ' * 40));
      final quote = tester.widget<Text>(
        find.textContaining('Split the token refresh.').first,
      );
      expect(quote.maxLines, kQuotedPromptMaxLines);
      expect(find.byType(ShaderMask), findsWidgets);
    });

    testWidgets('a short quote has no fade', (tester) async {
      await _pump(tester, _all());
      expect(
        find.descendant(
          of: find.byType(RestoreAllConfirmation),
          matching: find.byWidgetPredicate(
            (w) => w is ShaderMask && w.blendMode == BlendMode.dstIn,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('Cancel has the first focus and Restore is red outlined', (
      tester,
    ) async {
      await _pump(tester, _all());
      expect(_primaryFocusLabel(), 'Cancel');
      expect(find.byType(DestructiveTintButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DestructiveTintButton),
          matching: find.text('Restore all files'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('while replying the button is disabled with its reason', (
      tester,
    ) async {
      var confirmed = 0;
      await _pump(tester, _all(replying: true, onConfirm: () => confirmed++));
      expect(find.text('Wait for the reply to finish.'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byType(DestructiveTintButton),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Restore all files'), warnIfMissed: false);
      expect(confirmed, 0);
    });

    testWidgets('buttons stack at 2x and 3x text, the body scrolls', (
      tester,
    ) async {
      for (final scale in [2.0, 3.0]) {
        await _pump(tester, _all(), scale: scale);
        expect(tester.takeException(), isNull);
        final cancel = tester.getRect(find.byType(FilledButton));
        final restore = tester.getRect(find.byType(DestructiveTintButton));
        expect(restore.top, greaterThanOrEqualTo(cancel.bottom));
        expect(restore.width, cancel.width);
        expect(find.byType(SingleChildScrollView), findsWidgets);
      }
    });

    testWidgets('Android: text buttons, Cancel first', (tester) async {
      await _pump(tester, _all(), platform: TargetPlatform.android);
      expect(_primaryFocusLabel(), 'Cancel');
      expect(find.byType(FilledButton), findsNothing);
      // The test font is wide, so the buttons may wrap onto two lines.
      final cancel = tester.getTopLeft(find.text('Cancel'));
      final restore = tester.getTopLeft(find.text('Restore all files'));
      expect(
        cancel.dy < restore.dy || cancel.dx < restore.dx,
        isTrue,
        reason: 'Cancel comes first',
      );
    });
  });

  group('RestoreOutcomeNote', () {
    String say(
      RestoreOutcome outcome, {
      bool oneFile = false,
      AppLocalizations? l10n,
    }) {
      final parts = restoreOutcomeParts(
        l10n ?? en,
        outcome,
        filesWereFile: oneFile,
      );
      if (parts == null) return '';
      return parts.detail.isEmpty
          ? parts.title
          : '${parts.title}. ${parts.detail.replaceAll('\n', ' ')}';
    }

    test('restored says N only when it was read, else Files restored', () {
      expect(
        say(
          const RestoreOutcome(RestoreOutcomeKind.restored, filesRestored: 3),
        ),
        'Restored 3 files',
      );
      expect(
        say(
          const RestoreOutcome(RestoreOutcomeKind.restored, filesRestored: 1),
        ),
        'Restored 1 file',
      );
      expect(
        say(const RestoreOutcome(RestoreOutcomeKind.restored)),
        'Files restored',
      );
    });

    test('one file: Restored 1 file and the chat is not changed', () {
      expect(
        say(
          const RestoreOutcome(RestoreOutcomeKind.restored, filesRestored: 4),
          oneFile: true,
        ),
        "Restored 1 file. Your chat isn't changed.",
      );
    });

    test('a safety checkpoint is claimed only when it is known', () {
      const saved =
          'Hermes saved the previous state as the top checkpoint, '
          '‘Before a restore’.';
      const none = 'No new “Before a restore” checkpoint was added.';
      expect(
        say(
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            safetyCheckpoint: true,
          ),
        ),
        'Files restored. $saved',
      );
      expect(
        say(
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            safetyCheckpoint: false,
          ),
        ),
        'Files restored. $none',
      );
      final unknown = say(const RestoreOutcome(RestoreOutcomeKind.restored));
      expect(unknown, isNot(contains('Before a restore')));
    });

    test('a last message that was not the one removed is said', () {
      expect(
        say(
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            historyRemoved: 2,
            lastMessageNotRemoved: true,
          ),
        ),
        "Files restored. Your last message in this app wasn't the one "
        'removed.',
      );
    });

    test('no message is claimed removed when none was', () {
      final text = say(
        const RestoreOutcome(RestoreOutcomeKind.restored, filesRestored: 3),
      );
      expect(text, isNot(contains('removed')));
      expect(
        transcriptLineForRestore(
          en,
          const RestoreOutcome(RestoreOutcomeKind.restored, filesRestored: 3),
          removedMessages: false,
        ),
        'Restored 3 files',
      );
    });

    test('the chat that could not be rewound is told as it is', () {
      expect(
        say(const RestoreOutcome(RestoreOutcomeKind.historyNotRewound)),
        "Files were restored, but the chat couldn't be rewound. Your "
        'messages are unchanged. The list and the chat were read again.',
      );
    });

    test('refusals say what was refused and that nothing was changed', () {
      String refused(CheckpointFailureKind? kind) =>
          say(RestoreOutcome(RestoreOutcomeKind.refused, refusal: kind));
      expect(
        refused(CheckpointFailureKind.nestedRepositories),
        "This checkpoint includes a project inside the folder that Hermes "
        "didn't capture, so it can't restore it. Nothing was changed.",
      );
      expect(
        refused(CheckpointFailureKind.notFound),
        'That checkpoint is gone. The list was read again.',
      );
      expect(
        refused(CheckpointFailureKind.container),
        "Checkpoints don't cover this chat's workspace. Nothing was changed.",
      );
      for (final kind in [CheckpointFailureKind.pathRejected, null]) {
        expect(
          refused(kind),
          "Hermes couldn't restore the files. Nothing was changed.",
        );
      }
    });

    test('busy outcomes', () {
      expect(
        say(const RestoreOutcome(RestoreOutcomeKind.busyReplying)),
        'Wait for the reply to finish, then try again.',
      );
      expect(
        say(const RestoreOutcome(RestoreOutcomeKind.busyCompressing)),
        "Hermes is compressing this chat. Try again when it's done.",
      );
    });

    test('no answer: the files may have been restored', () {
      expect(
        say(const RestoreOutcome(RestoreOutcomeKind.mayHaveHappened)),
        "Hermes didn't answer. The files may have been restored. The list "
        'and the chat were read again.',
      );
    });

    test('session gone', () {
      expect(
        say(const RestoreOutcome(RestoreOutcomeKind.sessionGone)),
        'Hermes lost the connection to this chat. Try again.',
      );
    });

    test('a failure part-way never says nothing changed', () {
      for (final lang in ['en', 'de']) {
        final l10n = lookupAppLocalizations(Locale(lang));
        for (final oneFile in [false, true]) {
          for (final kind in [
            RestoreOutcomeKind.failedMaybeChanged,
            RestoreOutcomeKind.historyNotRewound,
            RestoreOutcomeKind.mayHaveHappened,
          ]) {
            final text = say(
              RestoreOutcome(kind),
              oneFile: oneFile,
              l10n: l10n,
            ).toLowerCase();
            expect(text, isNot(contains('nothing')), reason: '$lang $kind');
            expect(text, isNot(contains('nichts')), reason: '$lang $kind');
          }
        }
      }
      expect(
        say(const RestoreOutcome(RestoreOutcomeKind.failedMaybeChanged)),
        "Hermes couldn't restore the files. Some may have changed. The list "
        'and the chat were read again.',
      );
    });

    test('a failure with nothing changed says so', () {
      expect(
        say(const RestoreOutcome(RestoreOutcomeKind.failedNothingChanged)),
        "Hermes couldn't restore the files. Nothing was changed.",
      );
    });

    test('unsupported has no words', () {
      expect(
        restoreOutcomeParts(
          en,
          const RestoreOutcome(RestoreOutcomeKind.unsupported),
          filesWereFile: false,
        ),
        isNull,
      );
    });

    test('tones: success green, partial warning, failure error', () {
      String tone(RestoreOutcomeKind kind) => restoreOutcomeParts(
        en,
        RestoreOutcome(kind),
        filesWereFile: false,
      )!.tone.name;
      expect(tone(RestoreOutcomeKind.restored), 'success');
      expect(tone(RestoreOutcomeKind.mayHaveHappened), 'warning');
      expect(tone(RestoreOutcomeKind.historyNotRewound), 'warning');
      expect(tone(RestoreOutcomeKind.failedMaybeChanged), 'error');
      expect(tone(RestoreOutcomeKind.busyReplying), 'neutral');
    });

    testWidgets('draws the note once, with Try again only when offered', (
      tester,
    ) async {
      var again = 0;
      await _pump(
        tester,
        RestoreOutcomeNote(
          outcome: const RestoreOutcome(RestoreOutcomeKind.mayHaveHappened),
          filesWereFile: false,
          onTryAgain: () => again++,
        ),
      );
      expect(find.text("Hermes didn't answer"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(again, 1);

      await _pump(
        tester,
        RestoreOutcomeNote(
          outcome: const RestoreOutcome(RestoreOutcomeKind.restored),
          filesWereFile: false,
          onTryAgain: () => again++,
        ),
      );
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Files restored'), findsOneWidget);
    });

    testWidgets('draws nothing for an unsupported server', (tester) async {
      await _pump(
        tester,
        const RestoreOutcomeNote(
          outcome: RestoreOutcome(RestoreOutcomeKind.unsupported),
          filesWereFile: false,
        ),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('the banner is a live region with the words as its label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const RestoreOutcomeNote(
          outcome: RestoreOutcome(
            RestoreOutcomeKind.restored,
            filesRestored: 3,
          ),
          filesWereFile: false,
        ),
      );
      expect(
        tester.getSemantics(find.byType(RestoreOutcomeNote)),
        matchesSemantics(label: 'Restored 3 files', isLiveRegion: true),
      );
      handle.dispose();
    });
  });

  group('transcriptLineForRestore', () {
    test('words the line for a success', () {
      String? line(RestoreOutcome outcome, {required bool removed}) =>
          transcriptLineForRestore(en, outcome, removedMessages: removed);
      const three = RestoreOutcome(
        RestoreOutcomeKind.restored,
        filesRestored: 3,
        historyRemoved: 1,
      );
      const unknown = RestoreOutcome(
        RestoreOutcomeKind.restored,
        historyRemoved: 1,
      );
      expect(
        line(three, removed: true),
        'Restored 3 files · removed your last message',
      );
      expect(
        line(unknown, removed: true),
        'Files restored · removed your last message',
      );
      // History was removed but not the message the app expected to lose: the
      // line must not say the last message went.
      const rewound = RestoreOutcome(
        RestoreOutcomeKind.restored,
        filesRestored: 3,
        historyRemoved: 1,
        lastMessageNotRemoved: true,
      );
      expect(
        line(rewound, removed: true),
        'Restored 3 files · rewound the chat',
      );
      expect(
        line(
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            historyRemoved: 1,
            lastMessageNotRemoved: true,
          ),
          removed: true,
        ),
        'Files restored · rewound the chat',
      );
      expect(line(three, removed: false), 'Restored 3 files');
      expect(line(unknown, removed: false), 'Files restored');
    });

    test('is null for every outcome that is not a success', () {
      for (final kind in RestoreOutcomeKind.values) {
        if (kind == RestoreOutcomeKind.restored) continue;
        expect(
          transcriptLineForRestore(
            en,
            RestoreOutcome(kind),
            removedMessages: true,
          ),
          isNull,
          reason: '$kind',
        );
      }
    });
  });
}
