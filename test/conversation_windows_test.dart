import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_conversation_window_host.dart';

const _server = (baseUrl: 'https://hermes.test', authRequired: true);

void main() {
  late FakeConversationWindowHost host;
  late ConversationWindows windows;
  late List<(String, String?)> shownInMain;
  ({String baseUrl, bool authRequired})? connection;

  ConversationWindows build() => ConversationWindows(
    host: host,
    store: ConversationWindowStore(SharedPreferencesAsync()),
    connection: () => connection,
    headers: ({rejected}) async => {'Authorization': 'Bearer t'},
  )..showInMainRequests.listen((r) => shownInMain.add((r.threadId, r.profile)));

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    host = FakeConversationWindowHost();
    shownInMain = [];
    connection = _server;
    windows = build();
  });

  tearDown(() => windows.dispose());

  test('opens a chat in a window that stays on its profile', () async {
    await windows.open('s1', profile: 'work', title: 'Plan');

    final args = host.created.values.single;
    expect(args.threadId, 's1');
    expect(args.profile, 'work');
    expect(args.title, 'Plan');
    expect(args.baseUrl, 'https://hermes.test');
    expect(windows.windows.single.args.threadId, 's1');
  });

  test(
    'a chat that already has a window is focused, not opened again',
    () async {
      await windows.open('s1', profile: 'work', title: 'Plan');
      await windows.open('s1', profile: 'work', title: 'Plan');
      await windows.open('s1', profile: 'home', title: 'Plan');

      expect(host.created, hasLength(2));
      expect(host.focused, ['w0']);
    },
  );

  test('a window the user closed is dropped from the list', () async {
    await windows.open('s1', profile: null, title: 'A');
    await windows.open('s2', profile: null, title: 'B');

    host.closed('w0');

    expect(windows.windows.map((w) => w.windowId), ['w1']);
  });

  test('tracks the key window', () async {
    await windows.open('s1', profile: null, title: 'A');

    await host.call('focused', {'window_id': 'w0', 'focused': true});
    expect(windows.keyWindowId, 'w0');

    host.focusMain();
    expect(windows.keyWindowId, isNull);
  });

  test('a window that loses focus to another conversation window is not '
      'left key', () async {
    await windows.open('s1', profile: null, title: 'A');
    await windows.open('s2', profile: null, title: 'B');

    await host.call('focused', {'window_id': 'w1', 'focused': true});
    await host.call('focused', {'window_id': 'w0', 'focused': false});

    expect(windows.keyWindowId, 'w1');
  });

  test('routes commands to the key window only', () async {
    await windows.open('s1', profile: null, title: 'A');

    expect(await windows.closeKeyWindow(), isFalse);
    await host.call('focused', {'window_id': 'w0', 'focused': true});
    expect(await windows.closeKeyWindow(), isTrue);
    expect(await windows.runInKeyWindow(ThreadAction.archive), isTrue);

    expect(host.commands, [('w0', 'close'), ('w0', 'archive')]);
  });

  test('a renamed chat updates its window entry', () async {
    await windows.open('s1', profile: null, title: 'A');

    await host.call('title', {'window_id': 'w0', 'title': 'Renamed'});

    expect(windows.windows.single.args.title, 'Renamed');
  });

  test('answers a window asking for request headers', () async {
    final headers = await host.call('auth.headers', {
      'rejected': {'Authorization': 'Bearer old'},
    });

    expect(headers, {'Authorization': 'Bearer t'});
  });

  test(
    'show in main window selects the chat and brings the window back',
    () async {
      await host.call('showInMain', {'thread_id': 's1', 'profile': 'work'});
      await pumpEventQueue();

      expect(shownInMain, [('s1', 'work')]);
      expect(host.mainShown, 1);
    },
  );

  test('reopens the windows of the current server after a relaunch', () async {
    await windows.open('s1', profile: 'work', title: 'A');
    await windows.open('s2', profile: 'home', title: 'B');
    windows.dispose();

    host = FakeConversationWindowHost();
    windows = build();
    await windows.restore();
    await windows.restore();

    expect(host.created.values.map((a) => (a.threadId, a.profile)), [
      ('s1', 'work'),
      ('s2', 'home'),
    ]);
  });

  test('does not reopen windows saved for another server', () async {
    await windows.open('s1', profile: null, title: 'A');
    windows.dispose();

    host = FakeConversationWindowHost();
    connection = (baseUrl: 'https://other.test', authRequired: true);
    windows = build();
    await windows.restore();

    expect(host.created, isEmpty);
  });

  test('a closed window is not reopened after a relaunch', () async {
    await windows.open('s1', profile: null, title: 'A');
    await windows.open('s2', profile: null, title: 'B');
    host.closed('w0');
    await pumpEventQueue();
    windows.dispose();

    host = FakeConversationWindowHost();
    windows = build();
    await windows.restore();

    expect(host.created.values.map((a) => a.threadId), ['s2']);
  });

  test('closing all windows on sign-out forgets them', () async {
    await windows.open('s1', profile: null, title: 'A');

    await windows.closeAll();
    host.closed('w0');
    await pumpEventQueue();
    windows.dispose();

    expect(host.commands, [('w0', 'close')]);
    host = FakeConversationWindowHost();
    windows = build();
    await windows.restore();
    expect(host.created, isEmpty);
  });

  test('remembers the chats that were open in a window this session', () async {
    await windows.open('s1', profile: 'work', title: 'A');
    host.closed('w0');

    expect(windows.touched, [(threadId: 's1', profile: 'work')]);
  });

  test('without a connection nothing opens', () async {
    connection = null;

    await windows.open('s1', profile: null, title: 'A');

    expect(host.created, isEmpty);
  });
}
