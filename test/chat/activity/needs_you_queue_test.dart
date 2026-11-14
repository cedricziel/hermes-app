import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/needs_you_queue.dart';
import 'package:hermes_app/src/chat/activity/widgets/needs_you_models.dart';
import 'package:hermes_app/src/chat/billing_verification_controller.dart';
import 'package:hermes_app/src/chat/chat_session_state.dart';
import 'package:hermes_app/src/chat/connector_operation_controller.dart';
import 'package:hermes_app/src/chat/connector_operation_state.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

import '../billing_fixtures.dart' show billingVerificationFixture;
import '../connector_fixtures.dart'
    show connectionRequestFixture, connectionUpdateFixture;

/// The three sources of a chat and what the queue makes of them, with a
/// clock the test moves.
class _Rig {
  _Rig() {
    connector.bind(
      connectorScope,
      profile: 'private-profile',
      respond: (_) async => {'status': 'ok', 'settled': false},
    );
    billing.bind(
      BillingVerificationScope(
        connection: Object(),
        attachment: billingScope,
        sessionId: 'runtime-a',
        profile: 'private-profile',
      ),
    );
    queue = NeedsYouQueue(
      changes: Listenable.merge([connector, billing, poke]),
      read: () => (
        scope: 'chat-1',
        billing: billing,
        connector: connector,
        session: session,
      ),
      now: () => now,
      breadcrumbs: Breadcrumbs.of(trail),
      onArrived: arrived.add,
    );
  }

  var now = DateTime.utc(2030);
  final connectorScope = Object(), billingScope = Object();
  final poke = ChangeNotifier();
  final trail = BreadcrumbTrail(capacity: 50);
  final arrived = <NeedsYouEntry>[];
  final session = ChatSessionState();
  late final connector = ConnectorOperationController(
    now: () => now,
    openBrowser: (_) async => true,
  );
  final billing = BillingVerificationController();
  late final NeedsYouQueue queue;

  /// Moves the clock and shows [id] as a waiting sign-in.
  void connect(String id, {int seq = 1, bool settled = false}) {
    now = now.add(const Duration(seconds: 1));
    connector.accept(
      ConnectorOperationSnapshot.fromUpdate({
        ...connectionUpdateFixture,
        'op_id': id,
        'seq': seq,
        'settled': settled,
        'owner': {'type': 'session', 'session_id': 'runtime-a'},
      })!,
      attachment: connectorScope,
    );
  }

  void verify() {
    now = now.add(const Duration(seconds: 1));
    billing.acceptVerification(
      billingVerificationFixture,
      attachment: billingScope,
    );
  }

  void reclaim() {
    now = now.add(const Duration(seconds: 1));
    session
      ..adopt('runtime-a')
      ..reclaimedReason = 'elsewhere';
    poke.notifyListeners();
  }

  List<NeedsYouKind> get kinds => [for (final e in queue.entries) e.kind];
  List<String> get crumbs => [for (final c in trail.recent) c.name];

  void dispose() {
    queue.dispose();
    connector.dispose();
    billing.dispose();
    poke.dispose();
  }
}

void main() {
  late _Rig rig;
  setUp(() => rig = _Rig());
  tearDown(() => rig.dispose());

  test('items wait oldest first across the three sources', () {
    rig.connect('op-1');
    rig.verify();
    rig.reclaim();
    expect(rig.kinds, [
      NeedsYouKind.connector,
      NeedsYouKind.billing,
      NeedsYouKind.reclaim,
    ]);
    expect(rig.queue.count, 3);
    expect(rig.queue.shown, 0);
  });

  test('an item that came first stays first when a source changes again', () {
    rig.connect('op-1');
    rig.verify();
    rig.connect('op-1', seq: 2);
    rig.verify();
    expect(rig.kinds, [NeedsYouKind.connector, NeedsYouKind.billing]);
  });

  test('a settling operation leaves and the next takes its slot', () {
    rig.connect('op-1');
    rig.verify();
    rig.connect('op-2');
    rig.queue.show(0);
    rig.connect('op-1', seq: 2, settled: true);
    expect(rig.kinds, [NeedsYouKind.billing, NeedsYouKind.connector]);
    expect(rig.queue.shown, 0);
    expect(rig.queue.entries.first.kind, NeedsYouKind.billing);
  });

  test('the shown slot survives a re-render and new arrivals', () {
    rig.connect('op-1');
    rig.verify();
    rig.queue.show(1);
    rig.poke.notifyListeners();
    expect(rig.queue.shown, 1);
    rig.connect('op-2');
    expect(rig.queue.shown, 1);
    expect(rig.queue.entries[1].kind, NeedsYouKind.billing);
  });

  test('the shown item keeps the card while an earlier one leaves', () {
    rig.connect('op-1');
    rig.verify();
    rig.queue.show(1);
    rig.connect('op-1', seq: 2, settled: true);
    expect(rig.kinds, [NeedsYouKind.billing]);
    expect(rig.queue.shown, 0);
  });

  test('when the shown item leaves the next one takes its slot', () {
    rig.connect('op-1');
    rig.verify();
    rig.connect('op-2');
    rig.queue.show(1);
    rig.billing.setLocked(true);
    expect(rig.kinds, [NeedsYouKind.connector, NeedsYouKind.connector]);
    expect(rig.queue.shown, 1);
    rig.connect('op-2', seq: 2, settled: true);
    expect(rig.queue.shown, 0, reason: 'no item is left to take slot 1');
  });

  test('a connection-wide operation never enters', () {
    rig.connector.bind(
      rig.connectorScope,
      profile: 'private-profile',
      actionsAllowed: false,
    );
    rig.connector.accept(
      ConnectorOperationSnapshot.fromUpdate({
        ...connectionUpdateFixture,
        'owner': {'type': 'account'},
      })!,
      attachment: rig.connectorScope,
      accountProfileKnown: false,
    );
    expect(rig.connector.operations, hasLength(1));
    expect(rig.queue.entries, isEmpty);
  });

  test('a failed restore enters as resume and a reclaim outranks it', () {
    rig.session
      ..adopt('runtime-a')
      ..resume = const ResumeProgress('restore', 'failed');
    rig.poke.notifyListeners();
    expect(rig.kinds, [NeedsYouKind.resume]);
    rig.session.reclaimedReason = 'elsewhere';
    rig.poke.notifyListeners();
    expect(rig.kinds, [NeedsYouKind.reclaim]);
  });

  test('a restore that is still going is not Needs you', () {
    rig.session
      ..adopt('runtime-a')
      ..resume = const ResumeProgress('restore', 'running');
    rig.poke.notifyListeners();
    expect(rig.queue.entries, isEmpty);
  });

  test('App Lock clearing the billing details removes the item', () {
    rig.verify();
    expect(rig.kinds, [NeedsYouKind.billing]);
    rig.billing.setLocked(true);
    expect(rig.queue.entries, isEmpty);
  });

  test('a scope retirement empties the queue', () {
    rig.connect('op-1');
    rig.verify();
    rig.connector.bind(null);
    rig.billing.bind(null);
    expect(rig.queue.entries, isEmpty);
    expect(rig.queue.shown, 0);
  });

  test('going offline keeps a connector item display-only, drops billing '
      'and still lets retirement remove it', () {
    rig.connect('op-1');
    rig.verify();
    final since = rig.queue.entries.first.since;
    rig.connector.suspend();
    // What a drop does to the billing controller: it is released.
    final offline = NeedsYouQueue(
      changes: rig.poke,
      read: () => (
        scope: 'chat-1',
        billing: null,
        connector: rig.connector,
        session: rig.session,
      ),
      now: () => rig.now,
    );
    addTearDown(offline.dispose);
    expect(offline.entries.map((e) => e.kind), [NeedsYouKind.connector]);
    expect(rig.kinds, [NeedsYouKind.connector, NeedsYouKind.billing]);
    expect(rig.queue.entries.first.since, since);

    rig.connector.bind(null);
    rig.poke.notifyListeners();
    expect(offline.entries, isEmpty);
  });

  test('a deadline that passes while offline removes the item without a '
      'poke', () {
    fakeAsync((async) {
      final start = DateTime.utc(2030);
      DateTime now() => start.add(async.elapsed);
      final scope = Object();
      final connector = ConnectorOperationController(now: now);
      connector.bind(scope, profile: 'p', respond: (_) async => {});
      final queue = NeedsYouQueue(
        changes: connector,
        read: () =>
            (scope: 'chat', billing: null, connector: connector, session: null),
        now: now,
      );
      connector.accept(
        ConnectorOperationSnapshot.fromUpdate({
          ...connectionUpdateFixture,
          'op_id': 'op-1',
          'owner': {'type': 'session', 'session_id': 'runtime-a'},
          'deadline_at': start.millisecondsSinceEpoch / 1000 + 60,
        })!,
        attachment: scope,
      );
      connector.suspend();
      expect(queue.entries, hasLength(1));
      async.elapse(const Duration(seconds: 59));
      expect(queue.entries, hasLength(1));
      async.elapse(const Duration(seconds: 2));
      expect(queue.entries, isEmpty);
      queue.dispose();
      connector.dispose();
    });
  });

  test('another chat starts with an empty queue', () {
    rig.connect('op-1');
    var chat = 'chat-1';
    final other = NeedsYouQueue(
      changes: rig.poke,
      read: () =>
          (scope: chat, billing: null, connector: rig.connector, session: null),
      now: () => rig.now,
    );
    addTearDown(other.dispose);
    other.show(0);
    expect(other.entries, hasLength(1));
    rig.now = rig.now.add(const Duration(seconds: 5));
    chat = 'chat-2';
    rig.poke.notifyListeners();
    // Same controllers, new chat: what it holds is new to the queue.
    expect(other.entries, hasLength(1));
    expect(other.entries.single.since, rig.now);
  });

  group('observability', () {
    test('a new front item records shown with its kind and the count', () {
      rig.verify();
      expect(rig.trail.recent.single.name, 'chat.activity.needs_you.shown');
      expect(rig.trail.recent.single.attributes, {
        'kind': 'billing',
        'count': 1,
      });
    });

    test('an item that joins behind the front records nothing', () {
      rig.verify();
      rig.connect('op-1');
      expect(rig.crumbs, ['chat.activity.needs_you.shown']);
    });

    test('a later item reaching the front records shown again', () {
      rig.verify();
      rig.connect('op-1');
      rig.billing.setLocked(true);
      expect(rig.crumbs, [
        'chat.activity.needs_you.shown',
        'chat.activity.needs_you.shown',
      ]);
      expect(rig.trail.recent.last.attributes, {
        'kind': 'connector',
        'count': 1,
      });
    });

    test('paging records paged with the count and nothing else', () {
      rig.verify();
      rig.connect('op-1');
      rig.trail.recent;
      rig.queue.show(1);
      expect(rig.crumbs.last, 'chat.activity.needs_you.paged');
      expect(rig.trail.recent.last.attributes, {'count': 2});
      rig.queue.show(1);
      expect(rig.crumbs, hasLength(2), reason: 'no move, no crumb');
    });

    test('crumbs never carry a code, url, name or id', () {
      rig.verify();
      rig.connect('op-1');
      rig.queue.show(1);
      final text = [
        for (final c in rig.trail.recent) '${c.name} ${c.attributes}',
      ].join(' ');
      for (final secret in [
        'PRIVATE-CODE',
        'billing.invalid',
        'op-1',
        'synthetic',
        'runtime-a',
      ]) {
        expect(text, isNot(contains(secret)));
      }
    });
  });

  group('arrivals', () {
    test('an item is announced once, however often its source changes', () {
      rig.verify();
      rig.verify();
      rig.poke.notifyListeners();
      expect([for (final e in rig.arrived) e.kind], [NeedsYouKind.billing]);
    });

    test('an item behind the front waits until it is the front', () {
      rig.verify();
      rig.connect('op-1');
      expect([for (final e in rig.arrived) e.kind], [NeedsYouKind.billing]);
      rig.billing.setLocked(true);
      expect(
        [for (final e in rig.arrived) e.kind],
        [NeedsYouKind.billing, NeedsYouKind.connector],
      );
    });

    test('paging to an item is not an announcement', () {
      rig.verify();
      rig.connect('op-1');
      rig.queue.show(1);
      rig.billing.setLocked(true);
      expect(rig.arrived, hasLength(1));
    });

    test('an item that left and came back is announced again', () {
      rig.verify();
      rig.billing.setLocked(true);
      rig.billing.setLocked(false);
      rig.verify();
      expect(rig.arrived, hasLength(2));
    });

    test('what a chat already held when it was opened is not announced', () {
      rig.connect('op-1');
      var chat = 'other';
      final announced = <NeedsYouEntry>[];
      final queue = NeedsYouQueue(
        changes: rig.poke,
        read: () => (
          scope: chat,
          billing: null,
          connector: rig.connector,
          session: null,
        ),
        now: () => rig.now,
        onArrived: announced.add,
      );
      addTearDown(queue.dispose);
      expect(queue.entries, hasLength(1));
      chat = 'chat-3';
      rig.poke.notifyListeners();
      expect(announced, isEmpty);
      rig.connect('op-2');
      expect(announced, isEmpty, reason: 'op-2 waits behind op-1');
    });

    test('nothing is announced while the card is not drawn', () {
      var drawn = false;
      final announced = <NeedsYouEntry>[];
      final queue = NeedsYouQueue(
        changes: rig.poke,
        read: () => (
          scope: 'chat-1',
          billing: rig.billing,
          connector: null,
          session: null,
        ),
        now: () => rig.now,
        onArrived: announced.add,
        canAnnounce: () => drawn,
      );
      addTearDown(queue.dispose);
      rig.verify();
      expect(announced, isEmpty);
      drawn = true;
      rig.poke.notifyListeners();
      expect(announced, hasLength(1));
    });

    test('the keys hold no code, url, name or id', () {
      rig.verify();
      rig.connect('op-1');
      rig.reclaim();
      for (final entry in rig.queue.entries) {
        expect(entry.key, isNot(contains('PRIVATE')));
        expect(entry.key, isNot(contains('invalid')));
      }
    });
  });

  test('requests seen again as a request keep their place', () {
    rig.connect('synthetic-operation');
    rig.connector.accept(
      ConnectorOperationSnapshot.fromRequest(
        connectionRequestFixture,
        runtimeId: 'runtime-a',
      )!,
      attachment: rig.connectorScope,
    );
    expect(rig.queue.entries, hasLength(1));
  });
}
