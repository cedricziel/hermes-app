import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/queued_prompt.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _report = SharedFile(path: '/tmp/a/report.pdf', name: 'report.pdf');
const _pill = Text('claude-opus-4', key: Key('pill'));

void main() {
  final controller = TextEditingController();
  final sent = <String>[];
  var attachTaps = 0;

  setUp(() {
    controller.clear();
    sent.clear();
    attachTaps = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    List<SharedFile> attachments = const [],
    bool replying = false,
    List<QueuedPrompt> queued = const [],
    Widget? modelPill = _pill,
    bool canAttach = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ChatComposer(
            controller: controller,
            onSend: sent.add,
            onAttach: canAttach ? () => attachTaps++ : null,
            attachments: attachments,
            onRemoveAttachment: (_) {},
            replying: replying,
            onStop: replying ? () async {} : null,
            queued: queued,
            onRemoveQueued: (_) {},
            modelPill: modelPill,
          ),
        ),
      ),
    ),
  );

  IconButton sendButton(WidgetTester tester) => tester.widget<IconButton>(
    find.ancestor(
      of: find.byIcon(Icons.arrow_upward),
      matching: find.byType(IconButton),
    ),
  );

  testWidgets('attach, pill and send sit in a row below the field', (
    tester,
  ) async {
    await pump(tester);

    final field = tester.getRect(find.byType(TextField));
    final attach = tester.getCenter(find.byTooltip('Add attachment'));
    final pill = tester.getCenter(find.byKey(const Key('pill')));
    final send = tester.getCenter(find.byIcon(Icons.arrow_upward));
    expect(find.text('Message Hermes…'), findsOneWidget);
    for (final control in [attach, pill, send]) {
      expect(control.dy, greaterThan(field.bottom));
    }
    expect(attach.dx, lessThan(pill.dx));
    expect(pill.dx, lessThan(send.dx));
    expect(attach.dy, moreOrLessEquals(send.dy, epsilon: 1));
  });

  testWidgets('without a pill the row holds only attach and send', (
    tester,
  ) async {
    await pump(tester, modelPill: null);

    expect(find.byKey(const Key('pill')), findsNothing);
    expect(find.byTooltip('Add attachment'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('send is a filled button, disabled with nothing to send', (
    tester,
  ) async {
    await pump(tester);

    expect(sendButton(tester).onPressed, isNull);
    await tester.tap(find.byIcon(Icons.arrow_upward));
    expect(sent, isEmpty);
  });

  testWidgets('text enables send; the field is left to the caller', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(EditableText), '  hello ');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNotNull);
    await tester.tap(find.byIcon(Icons.arrow_upward));

    expect(sent, ['hello']);
    expect(controller.text, '  hello ');
  });

  testWidgets('an enabled send shows its arrow on the primary colour', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(EditableText), 'hello');
    await tester.pumpAndSettle();

    final scheme = buildHermesLightTheme().colorScheme;
    final arrow = find.byIcon(Icons.arrow_upward);
    expect(IconTheme.of(tester.element(arrow)).color, scheme.onPrimary);
  });

  testWidgets('attachments alone are enough to send', (tester) async {
    await pump(tester, attachments: [_report]);

    expect(find.text('report.pdf'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_upward));

    expect(sent, ['']);
  });

  testWidgets('Enter sends and Shift+Enter does not', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), 'hello');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(sent, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(sent, ['hello']);
  });

  testWidgets('Enter on a blank field sends nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(EditableText));
    await tester.enterText(find.byType(EditableText), '   ');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(sent, isEmpty);
  });

  testWidgets('the attach button calls back, and is gone without one', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Add attachment'));
    expect(attachTaps, 1);

    await pump(tester, canAttach: false);
    expect(find.byTooltip('Add attachment'), findsNothing);
  });

  testWidgets('while replying: stop bar, queue and a queueing hint', (
    tester,
  ) async {
    await pump(
      tester,
      replying: true,
      queued: const [QueuedPrompt('Then open a PR', [])],
    );

    expect(find.text('Queue a message…'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Then open a PR'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Then open a PR')).dy,
      lessThan(tester.getRect(find.byType(TextField)).top),
    );
  });

  testWidgets('the field grows to eight lines at most', (tester) async {
    await pump(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.minLines, 1);
    expect(field.maxLines, 8);
  });
}
