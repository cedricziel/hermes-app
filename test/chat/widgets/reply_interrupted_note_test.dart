import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/reply_interrupted_note.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  late List<String> announced;

  setUp(() {
    announced = [];
    ReplyInterruptedNote.forgetAnnouncements();
  });

  Future<void> pumpNote(
    WidgetTester tester, {
    String text = 'Hermes restarted. This reply was interrupted.',
    String? key,
    bool show = true,
    bool unconfirmed = false,
    double scale = 1,
    ThemeData? theme,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        if (message is Map && message['type'] == 'announce') {
          announced.add((message['data'] as Map)['message'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility,
            null,
          ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? buildHermesLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SizedBox(
              width: 300,
              child: show
                  ? ReplyInterruptedNote(
                      text: text,
                      unconfirmed: unconfirmed,
                      announceKey: key,
                    )
                  : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('says it with an icon and the sentence, not colour alone', (
    tester,
  ) async {
    await pumpNote(tester);

    expect(
      find.text('Hermes restarted. This reply was interrupted.'),
      findsOneWidget,
    );
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('an ending nobody could confirm has its own icon', (
    tester,
  ) async {
    await pumpNote(tester);
    final interrupted = tester.widget<Icon>(find.byType(Icon)).icon;

    await pumpNote(tester, unconfirmed: true, text: "Couldn't confirm.");
    final unconfirmed = tester.widget<Icon>(find.byType(Icon)).icon;

    expect(unconfirmed, isNot(interrupted));
  });

  testWidgets('is announced once per reply, however often it is built', (
    tester,
  ) async {
    await pumpNote(tester, key: 'reply-1');
    expect(announced, ['Hermes restarted. This reply was interrupted.']);

    await pumpNote(tester, key: 'reply-1', show: false);
    await pumpNote(tester, key: 'reply-1');
    expect(announced, hasLength(1));

    await pumpNote(tester, key: 'reply-1', show: false);
    await pumpNote(tester, key: 'reply-2');
    expect(announced, hasLength(2));
  });

  testWidgets('without a key it never announces', (tester) async {
    await pumpNote(tester);

    expect(announced, isEmpty);
  });

  testWidgets('is one labelled node for a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpNote(tester);

    expect(
      find.bySemanticsLabel('Hermes restarted. This reply was interrupted.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('wraps at the largest text size without overflowing '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      await pumpNote(
        tester,
        scale: 3,
        text:
            "Couldn't confirm how this reply ended. It may have finished; "
            'check the conversation before trying again.',
        unconfirmed: true,
        theme: dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
