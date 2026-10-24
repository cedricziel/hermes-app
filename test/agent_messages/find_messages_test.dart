import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/agent_messages/agent_delivery.dart';
import 'package:hermes_app/src/agent_messages/find_messages.dart';

AgentDelivery delivery(
  String id,
  double startedAt, {
  int messages = 1,
  bool unread = true,
  bool pinned = false,
}) => AgentDelivery(
  id: id,
  title: id,
  startedAt: startedAt,
  messageCount: messages,
  unread: unread,
  pinned: pinned,
);

DeliveryListing listing(List<AgentDelivery> rows, {bool capped = false}) =>
    DeliveryListing(rows, capped: capped);

List<String> ids(MessagesFound found) => [
  for (final message in found.messages) message.delivery.id,
];

void main() {
  group('findMessages', () {
    test('a first look only records the newest delivery', () {
      final found = findMessages(
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
        record: {'home': 5},
        profileNames: ['home', 'ops'],
        listings: {'home': listing([]), 'ops': listing([])},
      );

      expect(found.record, {'home': 5, 'ops': 0});
    });

    test('a delivery after the record is found once it is unread', () {
      final found = findMessages(
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
        record: {'work': 10},
        profileNames: ['work'],
        listings: {'work': listing(unfinished)},
      );

      expect(ids(first), ['a']);
      expect(first.record, {'work': 20});

      final next = findMessages(
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
        record: {'work': 10},
        profileNames: ['work'],
        listings: {'work': listing(rows)},
      );

      expect(first.messages, isEmpty);
      expect(first.record, {'work': 10});

      final next = findMessages(
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
        record: {'work': 30},
        profileNames: ['work'],
        listings: {
          'work': listing([delivery('older', 20)]),
        },
      );

      expect(found.messages, isEmpty);
      expect(found.record, {'work': 30});
    });

    test('a pinned row listed twice counts once', () {
      final pinned = delivery('pinned', 20, pinned: true);
      final found = findMessages(
        record: {'work': 10},
        profileNames: ['work'],
        listings: {
          'work': listing([delivery('new', 30), pinned, pinned]),
        },
      );

      expect(ids(found), ['new', 'pinned']);
    });

    test('a profile whose list failed keeps its value', () {
      final found = findMessages(
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
        record: {'gone': 9, 'work': 10},
        profileNames: ['work'],
        listings: {'work': listing([])},
      );

      expect(found.record, {'work': 10});
    });

    test('reports a look that stopped at its page limit', () {
      final found = findMessages(
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
    List<AgentDelivery> page(int newest, {int count = kDeliveryPageSize}) => [
      for (var i = 0; i < count; i++)
        delivery('d${newest - i}', (newest - i).toDouble()),
    ];

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

    test('stops at a page that is not full', () async {
      final offsets = <int>[];
      await listDeliveries((offset) async {
        offsets.add(offset);
        return page(100, count: 7);
      }, since: 0);

      expect(offsets, [0]);
    });

    test('reports the cap after three newer pages', () async {
      final offsets = <int>[];
      final result = await listDeliveries((offset) async {
        offsets.add(offset);
        return page(1000 - offset);
      }, since: 0);

      expect(offsets, [0, 20, 40]);
      expect(result.capped, isTrue);
    });

    test('ignores pinned rows when deciding to stop', () async {
      final offsets = <int>[];
      await listDeliveries((offset) async {
        offsets.add(offset);
        return [...page(100 - offset), delivery('pinned', 1, pinned: true)];
      }, since: 10);

      expect(offsets, [0, 20, 40]);
    });

    test('lets a failing page fail the listing', () {
      expect(
        listDeliveries((_) async => throw StateError('down'), since: 0),
        throwsStateError,
      );
    });
  });
}
