import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/watch/watch_complication.dart';

void main() {
  late List<Map<String, Object>> sent;
  late List<bool> urgents;
  late ChangeNotifier lock;
  late WatchComplicationStatus status;
  var appLocked = false;
  var now = DateTime.utc(2026, 10, 10, 12);
  Error? failure;
  String via = 'complication';
  late BreadcrumbTrail trail;

  Map<String, Object> last() => {...sent.last}..remove('seq');

  const approval = ApprovalRequested(
    ApprovalRequest(
      requestId: 'r1',
      command: 'rm -rf build',
      description: 'delete files',
      choices: ['once', 'deny'],
    ),
  );

  setUp(() {
    sent = [];
    urgents = [];
    lock = ChangeNotifier();
    appLocked = false;
    now = DateTime.utc(2026, 10, 10, 12);
    failure = null;
    via = 'complication';
    trail = BreadcrumbTrail();
    status = WatchComplicationStatus(
      send: (payload, {required urgent}) async {
        if (failure != null) throw failure!;
        sent.add(payload);
        urgents.add(urgent);
        return via;
      },
      appLock: () => appLocked,
      lockChanges: lock,
      breadcrumbs: Breadcrumbs.of(trail),
      now: () => now,
    );
  });

  Future<void> settle() => pumpEventQueue();

  test('a turn that starts is working, with its chat and a time', () async {
    status.begin(Object(), title: 'Backup', threadId: 'p/s1');
    await settle();

    expect(last(), {
      'v': 1,
      'state': 'working',
      'title': 'Backup',
      'threadId': 'p/s1',
      'updatedAt': now.millisecondsSinceEpoch ~/ 1000,
    });
  });

  test('the state follows the turn to its end', () async {
    final turn = Object();
    status.begin(turn, title: 'Backup', threadId: 'p/s1');
    status.onEvent(turn, approval, title: 'Backup', threadId: 'p/s1');
    await settle();
    expect(last()['state'], 'waiting');

    status.onEvent(turn, const ReplyDelta('go'), title: 'Backup');
    await settle();
    expect(last()['state'], 'working');

    status.onEvent(turn, const ReplyCompleted('Done'), title: 'Backup');
    await settle();
    expect(last()['state'], 'ready');
  });

  test('a failed reply is failed, and a question or a secret wait', () async {
    final turn = Object();
    status.begin(turn, title: 'A');
    status.onEvent(
      turn,
      const UnsupportedRequested(
        UnsupportedRequest(requestId: 'r', kind: UnsupportedKind.sudo),
      ),
      title: 'A',
    );
    await settle();
    expect(last()['state'], 'waiting');

    status.onEvent(
      turn,
      const ReplyCompleted('Model unavailable', failed: true),
      title: 'A',
    );
    await settle();
    expect(last()['state'], 'failed');
  });

  test('says nothing a reply, a command or a question said', () async {
    final turn = Object();
    status.begin(turn, title: 'Backup', threadId: 'p/s1');
    status.onEvent(turn, approval, title: 'Backup', threadId: 'p/s1');
    status.onEvent(
      turn,
      const ReplyDelta('The secret answer'),
      title: 'Backup',
      threadId: 'p/s1',
    );
    status.onEvent(
      turn,
      const ReplyCompleted('The secret answer'),
      title: 'Backup',
      threadId: 'p/s1',
    );
    await settle();

    final text = sent.map((payload) => payload.toString()).join();
    expect(text, isNot(contains('rm -rf')));
    expect(text, isNot(contains('secret answer')));
    expect(text, isNot(contains('delete files')));
    for (final payload in sent) {
      expect(payload.keys, everyElement(isIn(_allowed)));
    }
  });

  test('sends only a change, not every streamed delta', () async {
    final turn = Object();
    status.begin(turn, title: 'A', threadId: 'p/s1');
    for (var i = 0; i < 5; i++) {
      status.onEvent(turn, ReplyDelta('$i'), title: 'A', threadId: 'p/s1');
    }
    await settle();

    expect(sent, hasLength(1));
  });

  test('a new title or a thread id that arrives is sent', () async {
    final turn = Object();
    status.begin(turn, title: 'New chat');
    status.onEvent(turn, const ThreadBound('s9'), title: 'New chat');
    status.onEvent(
      turn,
      const ThreadTitled('Backup'),
      title: 'Backup',
      threadId: 'p/s9',
    );
    await settle();

    expect(sent, hasLength(2));
    expect(last()['title'], 'Backup');
    expect(last()['threadId'], 'p/s9');
    expect(sent.first.containsKey('threadId'), isFalse);
  });

  test('a chat the gateway has not named has no title', () async {
    status.begin(Object(), title: null, threadId: 'p/s1');
    await settle();

    expect(last().containsKey('title'), isFalse);
    expect(last()['threadId'], 'p/s1');
  });

  test('App Lock keeps the title and the chat off the watch', () async {
    appLocked = true;
    status.begin(Object(), title: 'Backup', threadId: 'p/s1');
    await settle();

    expect(last(), {
      'v': 1,
      'state': 'working',
      'updatedAt': now.millisecondsSinceEpoch ~/ 1000,
    });
  });

  test('the turn that waits for the user is the one shown', () async {
    final first = Object();
    final second = Object();
    status.begin(first, title: 'First', threadId: 'p/a');
    now = now.add(const Duration(seconds: 5));
    status.onEvent(first, approval, title: 'First', threadId: 'p/a');
    now = now.add(const Duration(seconds: 5));
    status.begin(second, title: 'Second', threadId: 'p/b');
    await settle();

    expect(last()['title'], 'First');
    expect(last()['state'], 'waiting');

    now = now.add(const Duration(seconds: 5));
    status.onEvent(first, const ReplyCompleted('ok'), title: 'First');
    await settle();
    expect(last()['title'], 'First');
    expect(last()['state'], 'ready');
  });

  test('the latest turn is shown when none waits', () async {
    final first = Object();
    final second = Object();
    status.begin(first, title: 'First');
    now = now.add(const Duration(seconds: 5));
    status.begin(second, title: 'Second');
    await settle();

    expect(last()['title'], 'Second');
  });

  test('a finished reply stays until a newer turn replaces it', () async {
    final first = Object();
    final second = Object();
    status.begin(first, title: 'First');
    status.onEvent(first, const ReplyCompleted('ok'), title: 'First');
    now = now.add(const Duration(minutes: 1));
    status.begin(second, title: 'Second');
    status.onEvent(second, const ReplyCompleted('ok'), title: 'Second');
    await settle();

    expect(last()['title'], 'Second');
    expect(last()['state'], 'ready');
  });

  test('a stopped reply is not shown, and nothing remains', () async {
    final turn = Object();
    status.begin(turn, title: 'A');
    status.onEvent(turn, const ReplyCompleted('', stopped: true), title: 'A');
    await settle();

    expect(last(), {'v': 1, 'state': 'none'});
  });

  test('a deleted chat is dropped', () async {
    final turn = Object();
    status.begin(turn, title: 'A');
    status.drop(turn);
    await settle();

    expect(last()['state'], 'none');
  });

  test('clears on sign-out even when this run showed nothing', () async {
    status.clear();
    await settle();

    expect(last(), {'v': 1, 'state': 'none'});
    expect(urgents.last, isTrue);
  });

  test('clears what was shown', () async {
    status.begin(Object(), title: 'A');
    status.clear();
    await settle();

    expect(sent.map((payload) => payload['state']), ['working', 'none']);
  });

  test('a finished turn begun again in the same chat works again', () async {
    final turn = Object();
    status.begin(turn, title: 'A');
    status.onEvent(turn, const ReplyCompleted('ok'), title: 'A');
    status.begin(turn, title: 'A');
    await settle();

    expect(last()['state'], 'working');
  });

  test('a begin while the turn runs keeps its state', () async {
    final turn = Object();
    status.begin(turn, title: 'A');
    status.onEvent(turn, approval, title: 'A');
    status.begin(turn, title: 'A');
    await settle();

    expect(last()['state'], 'waiting');
  });

  test('records how it was sent, and a failure, without text', () async {
    final turn = Object();
    status.begin(turn, title: 'Backup');
    await settle();
    via = 'context';
    status.onEvent(turn, const ReplyCompleted('ok'), title: 'Backup');
    await settle();
    failure = StateError('no session');
    status.begin(Object(), title: 'Other');
    await settle();

    final crumbs = trail.recent;
    expect(crumbs.map((crumb) => crumb.name), [
      'watch.complication.sent',
      'watch.complication.sent',
      'watch.complication.failed',
    ]);
    expect(crumbs[0].attributes, {'via': 'complication'});
    expect(crumbs[1].attributes, {'via': 'context'});
    expect(crumbs.toString(), isNot(contains('Backup')));
  });

  test('a phone that cannot reach a watch is not an event', () async {
    via = 'none';
    status.begin(Object(), title: 'A');
    await settle();

    expect(trail.recent, isEmpty);
  });

  group('a finished turn', () {
    test('restarts when the same chat opens another turn', () async {
      final turn = Object();
      status.begin(turn, title: 'A', threadId: 'p/s1');
      status.onEvent(turn, const ReplyCompleted('ok'), title: 'A');
      now = now.add(const Duration(minutes: 1));
      status.onEvent(turn, const ReplyStarted(), title: 'A', threadId: 'p/s1');
      await settle();

      expect(last()['state'], 'working');
      expect(last()['updatedAt'], now.millisecondsSinceEpoch ~/ 1000);
    });

    test('restarts on a request, which needs the user', () async {
      final turn = Object();
      status.begin(turn, title: 'A');
      status.onEvent(turn, const ReplyCompleted('ok'), title: 'A');
      status.onEvent(turn, approval, title: 'A');
      await settle();

      expect(last()['state'], 'waiting');
    });

    test('is not restarted by what is not a turn', () async {
      final turn = Object();
      status.begin(turn, title: 'A');
      status.onEvent(turn, const ReplyCompleted('ok'), title: 'A');
      status.onEvent(turn, const SessionInfo(running: false), title: 'A');
      status.onEvent(turn, const ReplyCompleted('late'), title: 'A');
      await settle();

      expect(last()['state'], 'ready');
    });

    test('still takes the title that arrives after the reply', () async {
      final turn = Object();
      status.begin(turn, title: null, threadId: 'p/s1');
      status.onEvent(turn, const ReplyCompleted('ok'), title: null);
      status.onEvent(
        turn,
        const ThreadTitled('Backup'),
        title: 'Backup',
        threadId: 'p/s1',
      );
      await settle();

      expect(last()['state'], 'ready');
      expect(last()['title'], 'Backup');
    });

    test('a turn nobody began here opens on a turn event', () async {
      final turn = Object();
      status.onEvent(turn, const SessionInfo(running: false), title: 'A');
      status.onEvent(turn, const ThreadTitled('A'), title: 'A');
      await settle();
      expect(sent, isEmpty);

      status.onEvent(turn, const ReplyDelta('x'), title: 'A', threadId: 'p/s1');
      await settle();
      expect(last()['state'], 'working');
      expect(last()['title'], 'A');
    });
  });

  group('the sequence number', () {
    test('rises with every payload, even on a standing clock', () async {
      final turn = Object();
      status.begin(turn, title: 'A');
      status.onEvent(turn, approval, title: 'A');
      status.onEvent(turn, const ReplyCompleted('ok'), title: 'A');
      await settle();

      final seqs = sent.map((payload) => payload['seq'] as int).toList();
      expect(seqs, hasLength(3));
      expect(seqs[1], greaterThan(seqs[0]));
      expect(seqs[2], greaterThan(seqs[1]));
    });

    test(
      'is the clock in milliseconds at least, so a restart keeps going',
      () async {
        status.begin(Object(), title: 'A');
        await settle();
        final before = sent.last['seq'] as int;

        now = now.add(const Duration(seconds: 3));
        final restarted = WatchComplicationStatus(
          send: (payload, {required urgent}) async {
            sent.add(payload);
            return 'context';
          },
          now: () => now,
        );
        restarted.begin(Object(), title: 'B');
        await settle();

        expect(sent.last['seq'], greaterThan(before));
        expect(
          sent.last['seq'],
          greaterThanOrEqualTo(now.millisecondsSinceEpoch),
        );
      },
    );

    test('does not go back when the clock does', () async {
      final turn = Object();
      status.begin(turn, title: 'A');
      now = now.subtract(const Duration(hours: 1));
      status.onEvent(turn, approval, title: 'A');
      await settle();

      expect(sent.last['seq'], greaterThan(sent.first['seq'] as int));
    });
  });

  group('which update wakes the watch app', () {
    test('a change of state does, a new title does not', () async {
      final turn = Object();
      status.begin(turn, title: null, threadId: 'p/s1');
      status.onEvent(
        turn,
        const ThreadTitled('A'),
        title: 'A',
        threadId: 'p/s1',
      );
      status.onEvent(turn, approval, title: 'A', threadId: 'p/s1');
      await settle();

      expect(urgents, [true, false, true]);
    });

    test('the first working of a turn the watch sent does not', () async {
      final turn = Object();
      status.begin(turn, title: null, fromWatch: true);
      status.onEvent(turn, const ReplyDelta('x'), title: null, fromWatch: true);
      await settle();

      expect(urgents, [false]);
    });

    test('every later state of a turn the watch sent does', () async {
      final turn = Object();
      status.begin(turn, title: null, fromWatch: true);
      status.onEvent(turn, approval, title: null, fromWatch: true);
      status.onEvent(turn, const ReplyDelta('x'), title: null, fromWatch: true);
      status.onEvent(
        turn,
        const ReplyCompleted('ok'),
        title: null,
        fromWatch: true,
      );
      await settle();

      expect(urgents, [false, true, true, true]);
    });

    test('a title or a chat id that arrives does not', () async {
      final turn = Object();
      status.begin(turn, title: null);
      status.onEvent(
        turn,
        const ThreadBound('s1'),
        title: null,
        threadId: 'p/s1',
      );
      status.onEvent(
        turn,
        const ThreadTitled('A'),
        title: 'A',
        threadId: 'p/s1',
      );
      await settle();

      expect(urgents, [true, false, false]);
    });

    test('a clear does, even when this run showed nothing', () async {
      status.begin(Object(), title: 'A');
      status.clear();
      status.clear();
      await settle();

      expect(urgents, [true, true, true]);
    });

    test('a chat that is dropped or abandoned does', () async {
      final dropped = Object();
      status.begin(dropped, title: 'A');
      status.drop(dropped);
      final abandoned = Object();
      status.begin(abandoned, title: 'B');
      status.abandon(abandoned);
      await settle();

      expect(urgents, [true, true, true, true]);
      expect(sent.map((payload) => payload['state']), [
        'working',
        'none',
        'working',
        'none',
      ]);
    });

    test('taking a title off the watch for App Lock does', () async {
      status.begin(Object(), title: 'Backup', threadId: 'p/s1');
      appLocked = true;
      lock.notifyListeners();
      appLocked = false;
      lock.notifyListeners();
      await settle();

      expect(urgents, [true, true, false]);
    });
  });

  group('a delivery that did not happen', () {
    test('is tried again with the next change', () async {
      final turn = Object();
      failure = StateError('no session');
      status.begin(turn, title: 'A');
      await settle();
      failure = null;

      status.onEvent(turn, const ReplyDelta('x'), title: 'A');
      await settle();

      expect(last()['state'], 'working');
    });

    test('is tried again when no watch could be told', () async {
      final turn = Object();
      via = 'none';
      status.begin(turn, title: 'A');
      await settle();
      via = 'complication';

      status.onEvent(turn, const ReplyDelta('x'), title: 'A');
      await settle();

      expect(sent, hasLength(2));
    });

    test('is not repeated when it did arrive', () async {
      final turn = Object();
      status.begin(turn, title: 'A');
      await settle();
      status.onEvent(turn, const ReplyDelta('x'), title: 'A');
      await settle();

      expect(sent, hasLength(1));
    });
  });

  group('a turn that waits and nothing ends', () {
    const vault = UnsupportedRequested(
      UnsupportedRequest(requestId: 'r2', kind: UnsupportedKind.sudo),
    );

    test('is replaced by the next turn of the same chat', () async {
      final watchTurn = Object();
      status.begin(watchTurn, title: null, threadId: 'p/s1', fromWatch: true);
      status.onEvent(
        watchTurn,
        vault,
        title: null,
        threadId: 'p/s1',
        fromWatch: true,
      );
      expect(sent.last['state'], 'waiting');

      final phoneTurn = Object();
      status.begin(phoneTurn, title: 'A', threadId: 'p/s1');
      await settle();
      expect(last()['state'], 'working');
      expect(last()['title'], 'A');

      status.onEvent(
        phoneTurn,
        const ReplyCompleted('ok'),
        title: 'A',
        threadId: 'p/s1',
      );
      await settle();
      expect(last()['state'], 'ready');
    });

    test('is not replaced by a turn of another chat', () async {
      final watchTurn = Object();
      status.begin(watchTurn, title: null, threadId: 'p/s1', fromWatch: true);
      status.onEvent(
        watchTurn,
        vault,
        title: null,
        threadId: 'p/s1',
        fromWatch: true,
      );
      status.begin(Object(), title: 'B', threadId: 'p/s2');
      await settle();

      expect(last()['state'], 'waiting');
    });

    test('stops showing after half an hour, and gives way', () async {
      final watchTurn = Object();
      status.begin(watchTurn, title: null, threadId: 'p/s1', fromWatch: true);
      status.onEvent(
        watchTurn,
        vault,
        title: null,
        threadId: 'p/s1',
        fromWatch: true,
      );

      now = now.add(const Duration(minutes: 31));
      status.begin(Object(), title: 'B', threadId: 'p/s2');
      await settle();

      expect(last()['state'], 'working');
      expect(last()['title'], 'B');
    });

    test('is not shown after half an hour with nothing else to show', () async {
      status.begin(Object(), title: 'A');
      now = now.add(const Duration(minutes: 31));
      lock.notifyListeners();
      await settle();

      expect(last(), {'v': 1, 'state': 'none'});
    });

    test('a reply that finished is not forgotten after half an hour', () async {
      final turn = Object();
      status.begin(turn, title: 'A');
      status.onEvent(turn, const ReplyCompleted('ok'), title: 'A');
      now = now.add(const Duration(minutes: 31));
      lock.notifyListeners();
      await settle();

      expect(last()['state'], 'ready');
    });
  });

  group('App Lock', () {
    test('turning it on takes the title off the watch', () async {
      status.begin(Object(), title: 'Backup', threadId: 'p/s1');
      await settle();
      expect(last()['title'], 'Backup');

      appLocked = true;
      lock.notifyListeners();
      await settle();

      expect(last().keys, unorderedEquals(['v', 'state', 'updatedAt']));
    });

    test('turning it off gives the title back', () async {
      appLocked = true;
      status.begin(Object(), title: 'Backup');
      await settle();

      appLocked = false;
      lock.notifyListeners();
      await settle();

      expect(last()['title'], 'Backup');
    });

    test('a change with nothing shown sends nothing', () async {
      appLocked = true;
      lock.notifyListeners();
      await settle();

      expect(sent, isEmpty);
    });
  });

  test('goes to the native side as a complication call', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('test/watch');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return 'context';
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final overChannel = WatchComplicationStatus.overChannel(
      channel,
      breadcrumbs: Breadcrumbs.of(trail),
    );

    overChannel.begin(Object(), title: 'A');
    await settle();

    expect(calls.single.method, 'complication');
    final arguments = calls.single.arguments as Map;
    expect((arguments['payload'] as Map)['state'], 'working');
    expect(arguments['urgent'], isTrue);
    expect(trail.recent.single.attributes, {'via': 'context'});
  });
}

const _allowed = {'v', 'state', 'title', 'threadId', 'updatedAt', 'seq'};
