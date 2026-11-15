import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/reply_reconnecting_note.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  late List<String> announced;

  setUp(() {
    announced = [];
    ReplyReconnectingNote.forgetAnnouncements();
  });

  Future<void> pumpNote(
    WidgetTester tester, {
    String? key,
    bool show = true,
    double scale = 1,
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
        theme: buildHermesLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SizedBox(
              width: 300,
              child: show
                  ? ReplyReconnectingNote(
                      text: 'Connection lost. Reconnecting…',
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

  testWidgets('shows an icon and the sentence', (tester) async {
    await pumpNote(tester);

    expect(find.text('Connection lost. Reconnecting…'), findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('is announced once per loss, however often it is built', (
    tester,
  ) async {
    await pumpNote(tester, key: 'reply-1#1');
    expect(announced, ['Connection lost. Reconnecting…']);

    await pumpNote(tester, key: 'reply-1#1', show: false);
    await pumpNote(tester, key: 'reply-1#1');
    expect(announced, hasLength(1));

    // A second loss of the same reply is a new one.
    await pumpNote(tester, key: 'reply-1#1', show: false);
    await pumpNote(tester, key: 'reply-1#2');
    expect(announced, hasLength(2));
  });

  testWidgets('a new key on the same row is announced, as when the tries run '
      'out', (tester) async {
    Future<void> pump(String text, String key) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: ReplyReconnectingNote(text: text, announceKey: key),
          ),
        ),
      );
      await tester.pump();
    }

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
    await pump('Reconnecting', 'r#1');
    await pump("Couldn't reconnect", 'r#1i');

    expect(announced, ['Reconnecting', "Couldn't reconnect"]);
  });

  testWidgets('without a key it never announces', (tester) async {
    await pumpNote(tester);

    expect(announced, isEmpty);
  });

  testWidgets('wraps at the largest text size without overflowing', (
    tester,
  ) async {
    await pumpNote(tester, scale: 3);

    expect(tester.takeException(), isNull);
    expect(find.text('Connection lost. Reconnecting…'), findsOneWidget);
  });
}
