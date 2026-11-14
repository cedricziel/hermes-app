import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/generated/app_localizations.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_note_field.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

Future<void> _pump(
  WidgetTester tester,
  AgentNoteModel model, {
  VoidCallback? onSend,
  VoidCallback? onCopy,
  ValueChanged<String>? onChanged,
  TargetPlatform platform = TargetPlatform.android,
  double scale = 1,
  Size size = const Size(360, 900),
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AgentNoteField(
            model: model,
            onChanged: onChanged ?? (_) {},
            onSend: onSend ?? () {},
            onCopy: onCopy,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

AgentNoteModel _m({
  String text = 'Skip vendored packages',
  int? length,
  AgentNoteStatus status = AgentNoteStatus.idle,
  bool frozen = false,
  bool offline = false,
  bool canSend = true,
  List<String> sent = const [],
}) => AgentNoteModel(
  goal: 'Audit the dependency tree',
  text: text,
  length: length ?? text.trim().length,
  status: status,
  frozen: frozen,
  offline: offline,
  canSend: canSend,
  sentNotes: sent,
);

bool _sendEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton)).onPressed != null;

void main() {
  testWidgets('idle shows the section, recipient, placeholder and helper', (
    tester,
  ) async {
    await _pump(tester, _m(text: ''));
    expect(find.text('Redirect this agent'), findsOneWidget);
    expect(find.text('To: Audit the dependency tree'), findsOneWidget);
    expect(find.text('Tell this agent what to do differently'), findsOneWidget);
    expect(
      find.text(
        "Goes only to this agent, after the step it's on. It isn't added to "
        "the chat. Notes aren't kept once you close this.",
      ),
      findsOneWidget,
    );
    expect(find.text('Send to agent'), findsOneWidget);
    expect(find.textContaining(' / '), findsNothing);
    expect(find.byType(AppBanner), findsNothing);
  });

  testWidgets('Send is the only filled button', (tester) async {
    await _pump(
      tester,
      _m(sent: const ['An earlier note'], status: AgentNoteStatus.queued),
    );
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets(
    'Send is disabled while blank, over the limit, sending, offline',
    (tester) async {
      await _pump(tester, _m(text: '', canSend: false));
      expect(_sendEnabled(tester), isFalse);
      await _pump(tester, _m(length: 4001));
      expect(_sendEnabled(tester), isFalse);
      await _pump(tester, _m(status: AgentNoteStatus.sending));
      expect(_sendEnabled(tester), isFalse);
      expect(find.text('Sending…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await _pump(tester, _m(offline: true));
      expect(_sendEnabled(tester), isFalse);
      await _pump(tester, _m(length: 4000));
      expect(_sendEnabled(tester), isTrue);
    },
  );

  testWidgets('the counter shows from 3,500 and flags the overflow', (
    tester,
  ) async {
    await _pump(tester, _m(length: 3499));
    expect(find.textContaining(' / '), findsNothing);
    await _pump(tester, _m(length: 3500));
    expect(find.text('3,500 / 4,000'), findsOneWidget);
    await _pump(tester, _m(length: 4001));
    expect(find.text('4,001 / 4,000'), findsOneWidget);
  });

  testWidgets('outcome banners', (tester) async {
    await _pump(tester, _m(status: AgentNoteStatus.queued, sent: ['Do X']));
    expect(find.text('Sent.'), findsOneWidget);
    expect(find.text('The agent gets it after its current step.'), findsOne);
    expect(find.text('Your notes'), findsOneWidget);
    expect(find.text('Do X'), findsOneWidget);
    await _pump(tester, _m(status: AgentNoteStatus.rejected));
    expect(find.text("This agent isn't taking notes now."), findsOneWidget);
    await _pump(tester, _m(status: AgentNoteStatus.lost));
    expect(find.text("Couldn't confirm the note was sent."), findsOneWidget);
    expect(find.text('Sending it again may deliver it twice.'), findsOne);
    expect(_sendEnabled(tester), isTrue);
    await _pump(tester, _m(status: AgentNoteStatus.failed));
    expect(find.text("Couldn't send the note."), findsOneWidget);
    expect(find.text('Try again.'), findsOneWidget);
    await _pump(tester, _m(status: AgentNoteStatus.missed));
    expect(find.text("Your note didn't reach the agent."), findsOneWidget);
    expect(find.text('It had finished first.'), findsOneWidget);
  });

  testWidgets('banner tones', (tester) async {
    for (final (status, tone) in [
      (AgentNoteStatus.queued, AppBannerTone.success),
      (AgentNoteStatus.rejected, AppBannerTone.warning),
      (AgentNoteStatus.lost, AppBannerTone.warning),
      (AgentNoteStatus.failed, AppBannerTone.error),
      (AgentNoteStatus.missed, AppBannerTone.warning),
    ]) {
      await _pump(tester, _m(status: status));
      expect(tester.widget<AppBanner>(find.byType(AppBanner)).tone, tone);
    }
  });

  testWidgets('unsupported removes the field and the button', (tester) async {
    await _pump(tester, _m(status: AgentNoteStatus.unsupported));
    expect(
      find.text("This server can't take notes for agents."),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('frozen shows Not sent with Copy and no field', (tester) async {
    var copied = 0;
    await _pump(tester, _m(frozen: true), onCopy: () => copied++);
    expect(find.text('Not sent'), findsOneWidget);
    expect(find.text('Skip vendored packages'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    await tester.tap(find.text('Copy'));
    expect(copied, 1);
  });

  testWidgets('not controllable keeps typed text as Not sent', (tester) async {
    await _pump(tester, _m(status: AgentNoteStatus.notControllable));
    expect(find.text('Not sent'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await _pump(tester, _m(text: '', status: AgentNoteStatus.notControllable));
    expect(find.text('Redirect this agent'), findsNothing);
  });

  testWidgets('field switches suggestions, autocorrect and learning off', (
    tester,
  ) async {
    await _pump(tester, _m());
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enableSuggestions, isFalse);
    expect(field.autocorrect, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.autofillHints, isNull);
    await _pump(tester, _m(), platform: TargetPlatform.iOS);
    final apple = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(apple.enableSuggestions, isFalse);
    expect(apple.autocorrect, isFalse);
    expect(apple.enableIMEPersonalizedLearning, isFalse);
    expect(apple.autofillHints, isNull);
  });

  testWidgets('typing reports changes', (tester) async {
    final seen = <String>[];
    await _pump(tester, _m(text: ''), onChanged: seen.add);
    await tester.enterText(find.byType(TextField), 'hello');
    expect(seen, ['hello']);
  });

  testWidgets('Control-Enter sends once; Return does not', (tester) async {
    var sent = 0;
    await _pump(tester, _m(), onSend: () => sent++);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sent, 0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(sent, 1);
  });

  testWidgets('Command-Return sends on Apple platforms, not when disabled', (
    tester,
  ) async {
    var sent = 0;
    await _pump(
      tester,
      _m(),
      onSend: () => sent++,
      platform: TargetPlatform.macOS,
    );
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(sent, 1);
    await _pump(
      tester,
      _m(offline: true),
      onSend: () => sent++,
      platform: TargetPlatform.macOS,
    );
    await tester.tap(find.byType(CupertinoTextField));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(sent, 1);
  });

  testWidgets('Send is full width when narrow, natural width when wide', (
    tester,
  ) async {
    await _pump(tester, _m());
    final narrow = tester.getSize(find.byType(FilledButton)).width;
    expect(narrow, greaterThan(300));
    await _pump(tester, _m(), size: const Size(900, 900));
    expect(tester.getSize(find.byType(FilledButton)).width, lessThan(250));
  });

  for (final (platform, height) in [
    (TargetPlatform.iOS, 44.0),
    (TargetPlatform.android, 48.0),
    (TargetPlatform.macOS, 28.0),
  ]) {
    testWidgets('Send and Copy are $height tall on $platform', (tester) async {
      await _pump(tester, _m(), platform: platform);
      expect(tester.getSize(find.byType(FilledButton)).height, height);
      await _pump(tester, _m(frozen: true), platform: platform);
      expect(tester.getSize(find.byType(OutlinedButton)).height, height);
    });
  }

  testWidgets('the field grows to five lines at the largest text size', (
    tester,
  ) async {
    await _pump(tester, _m(), scale: 3, size: const Size(390, 1600));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.minLines, 5);
    await _pump(tester, _m());
    expect(tester.widget<TextField>(find.byType(TextField)).minLines, 3);
  });

  testWidgets('the field has a screen-reader name', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _m());
    expect(find.bySemanticsLabel(RegExp('Note to this agent')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('German copy', (tester) async {
    await _pump(
      tester,
      _m(status: AgentNoteStatus.failed, length: 3600),
      locale: const Locale('de'),
    );
    final de = lookupAppLocalizations(const Locale('de'));
    expect(find.text(de.chatSubagentsNoteTitle), findsOneWidget);
    expect(find.text(de.chatSubagentsNoteSend), findsOneWidget);
    expect(find.text(de.chatSubagentsBannerNoteFailedTitle), findsOneWidget);
    expect(find.text(de.chatSubagentsNoteHelper), findsOneWidget);
    expect(find.text(de.chatSubagentsNoteCounter(3600, 4000)), findsOneWidget);
  });
}
