import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/agent_messages/agent_delivery.dart';
import 'package:hermes_app/src/agent_messages/find_messages.dart';

AgentDelivery delivery(
  String id,
  double startedAt, {
  int messages = 1,
  bool unread = true,
}) => AgentDelivery(
  id: id,
  title: id,
  startedAt: startedAt,
  messageCount: messages,
  unread: unread,
);

DeliveryListing listing(
  List<AgentDelivery> rows, {
  bool capped = false,
  List<double>? listed,
}) => DeliveryListing(rows, capped: capped, listed: listed);

List<String> ids(MessagesFound found) => [
  for (final message in found.messages) message.delivery.id,
];

void main() {
  group('findMessages', () {
    test('a first look only records the newest delivery', () {
      final found = findMessages(
        now: 100,
        record: null,
        profileNames: ['work'],
        listings: {
          'work': listing([delivery('new', 30), delivery('old', 20)]),
        },
      );

      expect(found.messages, isEmpty);
      expect(found.record, {'work': 30});
    });

    test('a first look at a profile without deliveries records none yet', () {
      final found = findMessages(
        now: 100,
        record: {'home': 5},
        profileNames: ['home', 'ops'],
        listings: {'home': listing([]), 'ops': listing([])},
      );

      expect(found.record, {'home': 5, 'ops': 0});
    });

    test('a delivery after the record is found once it is unread', () {
      final found = findMessages(
        now: 100,
        record: {'ops': 0},
        profileNames: ['ops'],
        listings: {
          'ops': listing([delivery('first', 10)]),
        },
      );

      expect(ids(found), ['first']);
      expect(found.messages.single.profile, 'ops');
      expect(found.record, {'ops': 10});
    });

    test('a read delivery moves the record without being found', () {
      final found = findMessages(
        now: 100,
        record: {'work': 10},
        profileNames: ['work'],
        listings: {
          'work': listing([
            delivery('seen', 20, unread: false),
            delivery('old', 5),
          ]),
        },
      );

      expect(found.messages, isEmpty);
      expect(found.record, {'work': 20});
    });

    test('a delivery not newer than the record is not found', () {
      final found = findMessages(
        now: 100,
        record: {'work': 20},
        profileNames: ['work'],
        listings: {
          'work': listing([delivery('same', 20)]),
        },
      );

      expect(found.messages, isEmpty);
    });

    test('a delivery without a message holds the record before it', () {
      final unfinished = [delivery('new', 30, messages: 0), delivery('a', 20)];
      final first = findMessages(
        now: 100,
        record: {'work': 10},
        profileNames: ['work'],
        listings: {'work': listing(unfinished)},
      );

      expect(ids(first), ['a']);
      expect(first.record, {'work': 20});

      final next = findMessages(
        now: 100,
        record: first.record,
        profileNames: ['work'],
        listings: {
          'work': listing([delivery('new', 30), delivery('a', 20)]),
        },
      );

      expect(ids(next), ['new']);
      expect(next.record, {'work': 30});
    });

    test('a delivery behind an unfinished one waits for it', () {
      final rows = [
        delivery('late', 30),
        delivery('unfinished', 20, messages: 0),
      ];
      final first = findMessages(
        now: 100,
        record: {'work': 10},
        profileNames: ['work'],
        listings: {'work': listing(rows)},
      );

      expect(first.messages, isEmpty);
      expect(first.record, {'work': 10});

      final next = findMessages(
        now: 100,
        record: first.record,
        profileNames: ['work'],
        listings: {
          'work': listing([delivery('late', 30), delivery('unfinished', 20)]),
        },
      );

      expect(ids(next), ['late', 'unfinished']);
    });

    test('the record never moves back', () {
      final found = findMessages(
        now: 100,
        record: {'work': 30},
        profileNames: ['work'],
        listings: {
          'work': listing([delivery('older', 20)]),
        },
      );

      expect(found.messages, isEmpty);
      expect(found.record, {'work': 30});
    });

    test('a row listed twice counts once', () {
      final pinned = delivery('pinned', 20);
      final found = findMessages(
        now: 100,
        record: {'work': 10},
        profileNames: ['work'],
        listings: {
          'work': listing([delivery('new', 30), pinned, pinned]),
        },
      );

      expect(ids(found), ['new', 'pinned']);
    });

    test('a delivery already behind the record is not unfinished', () {
      final found = findMessages(
        now: 100,
        record: {'work': 50},
        profileNames: ['work'],
        listings: {
          'work': listing([
            delivery('new', 60),
            delivery('old', 40, messages: 0),
          ]),
        },
      );

      expect(ids(found), ['new']);
      expect(found.record, {'work': 60});
    });

    test('a first look does not wait for an unfinished delivery', () {
      final found = findMessages(
        now: 100,
        record: null,
        profileNames: ['work'],
        listings: {
          'work': listing([
            delivery('unfinished', 30, messages: 0),
            delivery('a', 20),
          ]),
        },
      );

      expect(found.record, {'work': 30});
    });

    test('gives up on a delivery that stays unfinished for an hour', () {
      final found = findMessages(
        now: 9000,
        record: {'work': 1000},
        profileNames: ['work'],
        listings: {
          'work': listing([
            delivery('late', 9000),
            delivery('orphan', 5000, messages: 0),
          ]),
        },
      );

      expect(ids(found), ['late']);
      expect(found.record, {'work': 9000});
    });

    test('keeps waiting for one that is less than an hour old', () {
      final found = findMessages(
        now: 4000,
        record: {'work': 1000},
        profileNames: ['work'],
        listings: {
          'work': listing([
            delivery('late', 4000),
            delivery('unfinished', 3000, messages: 0),
          ]),
        },
      );

      expect(found.messages, isEmpty);
      expect(found.record, {'work': 1000});
    });

    test('gives up on an orphan by the clock, with no later delivery', () {
      final found = findMessages(
        now: 5000 + kUnfinishedGrace + 1,
        record: {'work': 1000},
        profileNames: ['work'],
        listings: {
          'work': listing([
            delivery('after', 5100),
            delivery('orphan', 5000, messages: 0),
          ]),
        },
      );

      expect(ids(found), ['after']);
      expect(found.record, {'work': 5100});
    });

    test('a first look records past other chats, so older deliveries stay '
        'unannounced', () {
      final first = findMessages(
        now: 100,
        record: null,
        profileNames: ['work'],
        listings: {
          'work': listing([], listed: [50, 49, 48]),
        },
      );

      expect(first.record, {'work': 50});

      final next = findMessages(
        now: 100,
        record: first.record,
        profileNames: ['work'],
        listings: {
          'work': listing([delivery('older', 10)], listed: [50, 10]),
        },
      );

      expect(next.messages, isEmpty);
    });

    test('the record follows the newest chat listed, not only deliveries', () {
      final found = findMessages(
        now: 100,
        record: {'work': 10},
        profileNames: ['work'],
        listings: {
          'work': listing([delivery('d', 20)], listed: [40, 30, 20]),
        },
      );

      expect(ids(found), ['d']);
      expect(found.record, {'work': 40});
    });

    test('other chats do not move the record past an unfinished delivery', () {
      final found = findMessages(
        now: 100,
        record: {'work': 10},
        profileNames: ['work'],
        listings: {
          'work': listing(
            [delivery('unfinished', 20, messages: 0)],
            listed: [30, 20, 15],
          ),
        },
      );

      expect(found.record, {'work': 15});
    });

    test('a profile whose list failed keeps its value', () {
      final found = findMessages(
        now: 100,
        record: {'home': 7, 'work': 10},
        profileNames: ['home', 'work', 'ops'],
        listings: {
          'home': null,
          'work': listing([delivery('new', 20)]),
        },
      );

      expect(ids(found), ['new']);
      expect(found.record, {'home': 7, 'work': 20});
    });

    test('profiles the list no longer names are dropped', () {
      final found = findMessages(
        now: 100,
        record: {'gone': 9, 'work': 10},
        profileNames: ['work'],
        listings: {'work': listing([])},
      );

      expect(found.record, {'work': 10});
    });

    test('reports a look that stopped at its page limit', () {
      final found = findMessages(
        now: 100,
        record: {'a': 0, 'b': 0},
        profileNames: ['a', 'b'],
        listings: {
          'a': listing([delivery('x', 10)], capped: true),
          'b': listing([]),
        },
      );

      expect(found.capped, isTrue);
    });
  });

  group('listDeliveries', () {
    DeliveryPage page(int newest, {bool full = true, int deliveries = 20}) =>
        DeliveryPage(
          [
            for (var i = 0; i < deliveries; i++)
              delivery('d${newest - i}', (newest - i).toDouble()),
          ],
          full: full,
          oldestStartedAt: full ? (newest - 19).toDouble() : null,
          listed: [for (var i = 0; i < 20; i++) (newest - i).toDouble()],
        );

    test('reads only the newest page without a record', () async {
      final offsets = <int>[];
      final result = await listDeliveries((offset) async {
        offsets.add(offset);
        return page(100);
      }, since: null);

      expect(offsets, [0]);
      expect(result.capped, isFalse);
    });

    test('stops at the page that reaches the record', () async {
      final offsets = <int>[];
      final result = await listDeliveries((offset) async {
        offsets.add(offset);
        return page(100 - offset);
      }, since: 70);

      expect(offsets, [0, 20]);
      expect(result.capped, isFalse);
      expect(result.deliveries, hasLength(40));
    });

    test('stops at the last page', () async {
      final offsets = <int>[];
      await listDeliveries((offset) async {
        offsets.add(offset);
        return page(100, full: false, deliveries: 7);
      }, since: 0);

      expect(offsets, [0]);
    });

    test('keeps reading when other chats fill the window', () async {
      final offsets = <int>[];
      await listDeliveries((offset) async {
        offsets.add(offset);
        return page(1000 - offset, deliveries: 10);
      }, since: 0);

      expect(offsets, [0, 20, 40]);
    });

    test('reports the cap after three newer pages', () async {
      final result = await listDeliveries(
        (offset) async => page(1000 - offset),
        since: 0,
      );

      expect(result.capped, isTrue);
    });

    test('a third page that reaches the record is not the cap', () async {
      final result = await listDeliveries(
        (offset) async => page(1000 - offset),
        since: 941,
      );

      expect(result.capped, isFalse);
    });

    test('collects the start time of every chat listed', () async {
      final result = await listDeliveries(
        (offset) async => page(100 - offset, deliveries: 2),
        since: 70,
      );

      expect(result.listed, hasLength(40));
      expect(result.listed.first, 100);
    });

    test('after a look, the next reads one page', () async {
      // 60 app chats and one delivery: the first look reads the newest page.
      DeliveryPage window(int offset) => DeliveryPage(
        [if (offset == 0) delivery('d', 990)],
        full: true,
        oldestStartedAt: 1000.0 - offset - 19,
        listed: [for (var i = 0; i < 20; i++) 1000.0 - offset - i],
      );
      final first = findMessages(
        now: 1000,
        record: null,
        profileNames: ['work'],
        listings: {
          'work': await listDeliveries(
            (offset) async => window(offset),
            since: null,
          ),
        },
      );

      final offsets = <int>[];
      await listDeliveries((offset) async {
        offsets.add(offset);
        return window(offset);
      }, since: first.record['work']);

      expect(offsets, [0]);
    });

    test('lets a failing page fail the listing', () {
      expect(
        listDeliveries((_) async => throw StateError('down'), since: 0),
        throwsStateError,
      );
    });
  });
}
