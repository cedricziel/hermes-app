import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/agent_messages/agent_delivery.dart';
import 'package:hermes_app/src/agent_messages/find_messages.dart';
import 'package:hermes_app/src/agent_messages/message_alerts.dart';
import 'package:hermes_app/src/notifications/request_notifications.dart';

FoundMessage message(String profile, String id, {String? title = 'Report'}) =>
    FoundMessage(
      profile,
      AgentDelivery(
        id: id,
        title: title,
        startedAt: 1,
        messageCount: 1,
        unread: true,
      ),
    );

MessagesFound found(List<FoundMessage> messages, {bool capped = false}) =>
    MessagesFound(record: const {}, messages: messages, capped: capped);

void main() {
  group('messageAlertsFor', () {
    test('titles the chat and previews its text as plain text', () {
      final first = message('work', 'hermes-app-1');
      final alerts = messageAlertsFor(
        found([first]),
        {first.key: '**Daily** report ready: 3 builds failed'},
        shownProfile: 'work',
        appLock: false,
      );

      final alert = alerts.single;
      expect(alert.title, 'Report');
      expect(alert.body, 'Daily report ready: 3 builds failed');
      expect(alert.bodyIsPlainText, isTrue);
      expect(alert.threadId, 'hermes-app-1');
      expect(alert.profile, 'work');
      expect(alert.category, messageCategory);
      expect(alert.isMessage, isTrue);
      expect(alert.timeSensitive, isFalse);
    });

    test('names a profile other than the shown one', () {
      final first = message('work', 'hermes-app-1');
      final alerts = messageAlertsFor(
        found([first]),
        {first.key: 'Hi'},
        shownProfile: 'home',
        appLock: false,
      );

      expect(alerts.single.title, 'Report (work)');
    });

    test('a chat without a title is a message from Hermes', () {
      final blank = message('work', 'hermes-app-1', title: ' ');
      final none = message('work', 'hermes-app-2', title: null);
      final alerts = messageAlertsFor(
        found([blank, none]),
        {},
        shownProfile: 'work',
        appLock: false,
      );

      expect(
        [for (final alert in alerts) alert.title],
        ['Message from Hermes', 'Message from Hermes'],
      );
    });

    test('a chat of another profile without a title still names it', () {
      final alerts = messageAlertsFor(
        found([message('home', 'hermes-app-1', title: null)]),
        {},
        shownProfile: 'work',
        appLock: false,
      );

      expect(alerts.single.title, 'Message from Hermes (home)');
    });

    test('an empty or unreadable text is a new message', () {
      final empty = message('work', 'hermes-app-1');
      final unread = message('work', 'hermes-app-2');
      final alerts = messageAlertsFor(
        found([empty, unread]),
        {empty.key: '  '},
        shownProfile: 'work',
        appLock: false,
      );

      expect(
        [for (final alert in alerts) alert.body],
        ['New message', 'New message'],
      );
    });

    test('App Lock hides the title and the text', () {
      final first = message('work', 'hermes-app-1');
      final alerts = messageAlertsFor(
        found([first]),
        {first.key: 'Secret plans'},
        shownProfile: 'home',
        appLock: true,
      );

      expect(alerts.single.title, 'Message from Hermes');
      expect(alerts.single.body, 'New message');
    });

    test('more than five become one summary', () {
      final many = [
        for (var i = 0; i < 6; i++)
          message(i.isEven ? 'a' : 'b', 'hermes-app-$i'),
      ];
      final alerts = messageAlertsFor(
        found(many),
        {for (final one in many) one.key: 'Text'},
        shownProfile: 'a',
        appLock: false,
      );

      expect(alerts.single.title, 'Hermes');
      expect(alerts.single.body, '6 new messages');
      expect(alerts.single.threadId, isEmpty);
      expect(alerts.single.isMessage, isTrue);
      expect(alerts.single.category, isNull);
    });

    test('five are announced one by one', () {
      final five = [for (var i = 0; i < 5; i++) message('a', 'hermes-app-$i')];

      expect(
        messageAlertsFor(found(five), {}, shownProfile: 'a', appLock: false),
        hasLength(5),
      );
    });

    test('a look that stopped at its page limit says so', () {
      final many = [for (var i = 0; i < 6; i++) message('a', 'hermes-app-$i')];
      final alerts = messageAlertsFor(
        found(many, capped: true),
        {},
        shownProfile: 'a',
        appLock: false,
      );

      expect(alerts.single.title, 'Hermes');
      expect(alerts.single.body, '6 or more new messages');
    });

    test('a capped look with a few found announces them one by one', () {
      final few = [for (var i = 0; i < 3; i++) message('a', 'hermes-app-$i')];

      final alerts = messageAlertsFor(
        found(few, capped: true),
        {},
        shownProfile: 'a',
        appLock: false,
      );

      expect(alerts, hasLength(3));
    });

    test('keeps the paragraphs of a reply preview', () {
      final first = message('work', 'hermes-app-1');
      final alerts = messageAlertsFor(
        found([first]),
        {first.key: 'First paragraph.\n\nSecond paragraph.'},
        shownProfile: 'work',
        appLock: false,
      );

      expect(alerts.single.body, 'First paragraph.\n\nSecond paragraph.');
    });

    test('names no profile when none is shown', () {
      final first = message('work', 'hermes-app-1');
      final alerts = messageAlertsFor(
        found([first]),
        {},
        shownProfile: null,
        appLock: false,
      );

      expect(alerts.single.title, 'Report');
    });

    test('nothing found, nothing to announce', () {
      expect(
        messageAlertsFor(found([]), {}, shownProfile: 'a', appLock: false),
        isEmpty,
      );
    });
  });
}
