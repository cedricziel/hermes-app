import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/watch/watch_complication.dart';

void main() {
  late List<Map<String, Object>> sent;
  late WatchComplicationStatus status;
  var appLocked = false;
  var now = DateTime.utc(2026, 10, 10, 12);
  Error? failure;
  String via = 'complication';
  late BreadcrumbTrail trail;

  Map<String, Object> last() => sent.last;

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
    appLocked = false;
    now = DateTime.utc(2026, 10, 10, 12);
    failure = null;
    via = 'complication';
    trail = BreadcrumbTrail();
    status = WatchComplicationStatus(
      send: (payload) async {
        if (failure != null) throw failure!;
        sent.add(payload);
        return via;
      },
      appLock: () => appLocked,
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

  test('clears once on sign-out, and not when nothing was shown', () async {
    status.clear();
    await settle();
    expect(sent, isEmpty);

    status.begin(Object(), title: 'A');
    status.clear();
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
    expect((calls.single.arguments as Map)['state'], 'working');
    expect(trail.recent.single.attributes, {'via': 'context'});
  });
}

const _allowed = {'v', 'state', 'title', 'threadId', 'updatedAt'};
