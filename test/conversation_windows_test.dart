import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_conversation_window_host.dart';

const _server = (baseUrl: 'https://hermes.test', authRequired: true);

void main() {
  late FakeConversationWindowHost host;
  late ConversationWindows windows;
  late BreadcrumbTrail trail;
  late List<(String, String?)> shownInMain;
  late List<String> events;
  ({String baseUrl, bool authRequired})? connection;
  String? owner;

  ConversationWindows build() => ConversationWindows(
    host: host,
    store: ConversationWindowStore(SharedPreferencesAsync()),
    ownerKey: () => owner,
    connection: () => connection,
    headers: ({rejected}) async => {'Authorization': 'Bearer t'},
    breadcrumbs: Breadcrumbs.of(trail),
    events: (name, [attributes = const {}]) => events.add('$name $attributes'),
  )..showInMainRequests.listen((r) => shownInMain.add((r.threadId, r.profile)));

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    trail = BreadcrumbTrail();
    host = FakeConversationWindowHost();
    shownInMain = [];
    events = [];
    connection = _server;
    owner = 'owner-A';
    windows = build();
  });

  tearDown(() => windows.dispose());

  test(
    'saved targets do not restore for another owner at the same server',
    () async {
      await windows.open('private-A', profile: 'work', title: 'Private');
      await pumpEventQueue();
      await windows.closeAll(forget: false);
      owner = 'owner-B';
      await windows.restore();
      expect(host.created, isEmpty);
      expect(
        await ConversationWindowStore(SharedPreferencesAsync()).load(),
        isEmpty,
      );
    },
  );

  test('missing owner proof cannot open a gated window or panel', () async {
    owner = null;
    expect(
      await windows.open('private', profile: null, title: 'Private'),
      isFalse,
    );
    expect(await windows.togglePanel(), isFalse);
    expect(host.created, isEmpty);
    expect(host.panels, isEmpty);
  });

  test('legacy gated records cannot restore without owner metadata', () async {
    await SharedPreferencesAsync().setString(
      'conversation_windows',
      jsonEncode([
        {
          'thread_id': 'legacy',
          'base_url': _server.baseUrl,
          'auth_required': true,
        },
      ]),
    );
    await windows.restore();
    expect(host.created, isEmpty);
  });

  test('a header lookup cannot complete after its window is retired', () async {
    windows.dispose();
    final headers = Completer<Map<String, String>>();
    final started = Completer<void>();
    windows = ConversationWindows(
      host: host,
      store: ConversationWindowStore(SharedPreferencesAsync()),
      connection: () => connection,
      ownerKey: () => owner,
      headers: ({rejected}) {
        started.complete();
        return headers.future;
      },
    );
    await windows.open('private-A', profile: null, title: 'Private');
    final pending = host.call('auth.headers', {'window_id': 'w0'});
    await started.future;
    await windows.closeAll(forget: false);
    owner = 'owner-B';
    headers.complete({'Authorization': 'Bearer old-A'});
    expect(await pending, isEmpty);
  });

  test('restoration waits for native teardown to finish', () async {
    await windows.open('private-A', profile: null, title: 'Private');
    await pumpEventQueue();
    final release = Completer<void>();
    host.onCloseAll = () => release.future;
    final closing = windows.closeAll(forget: false);
    final restoring = windows.restore();
    try {
      await pumpEventQueue();
      expect(host.created.keys, ['w0']);
    } finally {
      release.complete();
      await Future.wait([closing, restoring]);
    }
    expect(host.created.values.single.threadId, 'private-A');
    expect(windows.windows.single.windowId, host.created.keys.single);
  });

  test('late old creation is closed before fresh creation begins', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    host.onCreate = (args) async {
      if (args.threadId == 'old') {
        started.complete();
        await release.future;
      }
    };
    final old = windows.open('old', profile: null, title: 'Old');
    await started.future;
    final closing = windows.closeAll();
    owner = 'owner-B';
    final fresh = windows.open('new', profile: null, title: 'New');
    try {
      await pumpEventQueue();
      expect(host.created, isEmpty);
    } finally {
      release.complete();
      await Future.wait([old, closing, fresh]);
    }
    expect(await old, isFalse);
    expect(await fresh, isTrue);
    expect(host.created.values.single.threadId, 'new');
  });

  test('retired focus cannot start a replacement window', () async {
    await windows.open('private-A', profile: null, title: 'Private');
    final started = Completer<void>();
    final release = Completer<void>();
    host.onFocus = () async {
      started.complete();
      await release.future;
    };
    final opening = windows.open('private-A', profile: null, title: 'Private');
    await started.future;
    await windows.closeAll();
    owner = 'owner-B';
    release.complete();
    expect(await opening, isFalse);
    expect(host.created, isEmpty);
    expect(host.closedNatively, ['*']);
  });

  test('retired panel toggle cannot start a replacement panel', () async {
    await windows.togglePanel();
    await host.call('panel', {'window_id': 'p0', 'event': 'shown'});
    final started = Completer<void>();
    final release = Completer<bool>();
    host.onTogglePanel = () {
      started.complete();
      return release.future;
    };
    final toggling = windows.togglePanel();
    await started.future;
    await windows.closeAll();
    owner = 'owner-B';
    release.complete(false);
    expect(await toggling, isFalse);
    expect(host.panels, isEmpty);
  });

  test('queued show in main is dropped when its session retires', () async {
    await windows.open('private-A', profile: null, title: 'Private');
    final showing = host.call('showInMain', {
      'window_id': 'w0',
      'thread_id': 'private-A',
    });
    final closing = windows.closeAll();
    await Future.wait([showing, closing]);
    await pumpEventQueue();
    expect(shownInMain, isEmpty);
  });

  test('failed native teardown blocks fresh windows', () async {
    await windows.open('old', profile: null, title: 'Old');
    host.onCloseAll = () async => throw StateError('native close failed');
    await expectLater(windows.closeAll(), throwsStateError);
    expect(await windows.open('new', profile: null, title: 'New'), isFalse);
    expect(await windows.togglePanel(), isFalse);
    expect(windows.windows, isEmpty);
  });

  test('opening and closing windows leave crumbs without the chat', () async {
    await windows.open(
      'secret-thread',
      profile: 'secret-profile',
      title: 'Secret',
    );
    await windows.closeAll();

    final text = [for (final c in trail.recent) '${c.name} ${c.attributes}'];
    expect(text, ['window.opened {open: 1}', 'window.closed {open: 0}']);
    expect(text.join(), isNot(contains('secret')));
    expect(text.join(), isNot(contains('Secret')));
  });

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

    expect(host.closedNatively, ['w0']);
    expect(host.commands, [('w0', 'archive')]);
  });

  test('a renamed chat updates its window entry', () async {
    await windows.open('s1', profile: null, title: 'A');

    await host.call('title', {'window_id': 'w0', 'title': 'Renamed'});

    expect(windows.windows.single.args.title, 'Renamed');
  });

  test('answers a window asking for request headers', () async {
    await windows.open('s1', profile: null, title: 'A');

    final headers = await host.call('auth.headers', {
      'window_id': 'w0',
      'rejected': {'Authorization': 'Bearer old'},
    });

    expect(headers, {'Authorization': 'Bearer t'});
  });

  test(
    'a new window asking before its creation returned gets headers',
    () async {
      Future<Object?>? asked;
      host.onCreate = (_) async {
        asked = host.call('auth.headers', {'window_id': 'w0'});
      };

      await windows.open('s1', profile: null, title: 'A');

      expect(await asked, {'Authorization': 'Bearer t'});
      expect(host.closedNatively, isEmpty);
    },
  );

  test('a window it does not know gets no headers and is closed', () async {
    final headers = await host.call('auth.headers', {'window_id': 'w9'});

    expect(headers, isEmpty);
    expect(host.closedNatively, ['w9']);
  });

  test('a window of another server gets no headers and is closed', () async {
    await windows.open('s1', profile: null, title: 'A');
    connection = (baseUrl: 'https://other.test', authRequired: true);

    final headers = await host.call('auth.headers', {'window_id': 'w0'});

    expect(headers, isEmpty);
    expect(host.closedNatively, ['w0']);
    expect(windows.windows, isEmpty);
  });

  test('a window that went away without notice is opened again', () async {
    await windows.open('s1', profile: null, title: 'A');
    host.vanished('w0');

    await windows.open('s1', profile: null, title: 'A');

    expect(host.created.keys, ['w1']);
    expect(windows.windows.map((w) => w.windowId), ['w1']);
  });

  test(
    'a window the native side closed is forgotten before it answers',
    () async {
      await windows.open('s1', profile: null, title: 'A');

      await host.call('closed', {'window_id': 'w0'});
      windows.dispose();

      expect(windows.windows, isEmpty);
      host = FakeConversationWindowHost();
      windows = build();
      await windows.restore();
      expect(host.created, isEmpty);
    },
  );

  test('focusing a window that went away drops it', () async {
    await windows.open('s1', profile: null, title: 'A');
    host.vanished('w0');

    expect(await windows.focus('w0'), isFalse);
    expect(windows.windows, isEmpty);
  });

  test('a server change while restoring opens nothing more', () async {
    await windows.open('s1', profile: null, title: 'A');
    await windows.open('s2', profile: null, title: 'B');
    windows.dispose();
    host = FakeConversationWindowHost();
    windows = build();
    Future<void>? closing;
    host.onCreate = (_) async {
      connection = null;
      closing = windows.closeAll();
    };

    await windows.restore();
    await closing;

    expect(host.created, isEmpty);
    expect(windows.windows, isEmpty);
  });

  test(
    'show in main window selects the chat and brings the window back',
    () async {
      await windows.open('s1', profile: 'work', title: 'Plan');
      await host.call('showInMain', {
        'window_id': 'w0',
        'thread_id': 's1',
        'profile': 'work',
      });
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

    expect(host.closedNatively, ['*']);
    host = FakeConversationWindowHost();
    windows = build();
    await windows.restore();
    expect(host.created, isEmpty);
  });

  test(
    'closing all windows when the session expires keeps them for later',
    () async {
      await windows.open('s1', profile: 'work', title: 'A');

      await windows.closeAll(forget: false);
      await pumpEventQueue();
      expect(host.closedNatively, ['*']);
      expect(windows.windows, isEmpty);

      await windows.restore();
      expect(host.created.values.single.threadId, 's1');
    },
  );

  test('remembers the chats that were open in a window this session', () async {
    await windows.open('s1', profile: 'work', title: 'A');
    host.closed('w0');

    expect(windows.touched, [(threadId: 's1', profile: 'work')]);
  });

  test('closing all windows forgets the chats they had open', () async {
    await windows.open('s1', profile: 'work', title: 'A');

    await windows.closeAll();

    expect(windows.touched, isEmpty);
  });

  test('without a connection nothing opens', () async {
    connection = null;

    expect(await windows.open('s1', profile: null, title: 'A'), isFalse);

    expect(host.created, isEmpty);
  });

  test('says whether the window opened', () async {
    expect(await windows.open('s1', profile: null, title: 'A'), isTrue);
    expect(await windows.open('s1', profile: null, title: 'A'), isTrue);
    host.onCreate = (_) async => throw StateError('no window');
    expect(await windows.open('s2', profile: null, title: 'B'), isFalse);
  });

  group('quick panel', () {
    test('the first toggle creates the panel for the server', () async {
      expect(await windows.togglePanel(), isTrue);

      final launch = host.panels.values.single;
      expect(launch.baseUrl, 'https://hermes.test');
      expect(launch.authRequired, isTrue);
      expect(host.panelToggles, 0);
    });

    test('later toggles show or hide the open panel', () async {
      await windows.togglePanel();
      await host.present('p0');
      await windows.togglePanel();

      expect(host.panels, hasLength(1));
      expect(host.panelToggles, 1);
    });

    test('presses while the panel is being created make one panel', () async {
      await Future.wait([windows.togglePanel(), windows.togglePanel()]);

      expect(host.panels, hasLength(1));
    });

    test(
      'a press while the panel\'s engine starts makes no second one',
      () async {
        await windows.togglePanel();

        expect(await windows.togglePanel(), isTrue);

        expect(host.panels, hasLength(1));
        expect(host.panelToggles, 0);
      },
    );

    test('a panel whose engine never reports in is replaced', () async {
      final start = DateTime(2026, 10, 10, 12);
      await withClock(Clock.fixed(start), windows.togglePanel);

      await withClock(
        Clock.fixed(start.add(const Duration(seconds: 30))),
        windows.togglePanel,
      );

      expect(host.closedNatively, ['p0']);
      expect(host.panels.keys, ['p1']);
    });

    test('without a connection there is no panel', () async {
      connection = null;

      expect(await windows.togglePanel(), isFalse);
      expect(host.panels, isEmpty);
    });

    test('is neither saved for the next launch nor listed', () async {
      await windows.togglePanel();
      await windows.open('s1', profile: null, title: 'A');

      expect(windows.windows.map((w) => w.windowId), ['w1']);
      final saved = await ConversationWindowStore(SharedPreferencesAsync())
          .load();
      expect(saved.map((w) => w.threadId), ['s1']);
    });

    test('sign-out closes it, and the next toggle makes a new one', () async {
      await windows.togglePanel();

      await windows.closeAll();
      expect(host.panels, isEmpty);

      await windows.togglePanel();
      expect(host.panels.keys, ['p1']);
    });

    test('a panel closed natively is made again on the next toggle', () async {
      await windows.togglePanel();
      host.closed('p0');
      await pumpEventQueue();

      await windows.togglePanel();

      expect(host.panels.keys, ['p1']);
    });

    test('answers the panel asking for headers', () async {
      await windows.togglePanel();

      final headers = await host.call('auth.headers', {'window_id': 'p0'});

      expect(headers, {'Authorization': 'Bearer t'});
    });

    test('answers the current profile from the main window', () async {
      await windows.togglePanel();
      expect(await host.call('profile.current', {'window_id': 'p0'}), isNull);

      windows.currentProfile = () => 'work';

      expect(await host.call('profile.current', {'window_id': 'p0'}), 'work');
    });

    test('records shown and hidden without anything else', () async {
      await windows.togglePanel();

      await host.call('panel', {'window_id': 'p0', 'event': 'shown'});
      await host.call('panel', {
        'window_id': 'p0',
        'event': 'hidden',
        'reason': 'escape',
      });
      await host.call('panel', {
        'window_id': 'p0',
        'event': 'hidden',
        'reason': 'typed secret text',
      });

      final crumbs = [
        for (final c in trail.recent)
          if (c.name.startsWith('panel.')) '${c.name} ${c.attributes}',
      ];
      expect(crumbs, [
        'panel.shown {}',
        'panel.hidden {reason: escape}',
        'panel.hidden {reason: other}',
      ]);
    });

    test('records whether a shown panel continued its chat', () async {
      await windows.togglePanel();

      await host.call('panel', {
        'window_id': 'p0',
        'event': 'chat',
        'continued': true,
      });
      await host.call('panel', {'window_id': 'p0', 'event': 'chat'});

      expect(
        [
          for (final c in trail.recent)
            if (c.name == 'panel.chat') '${c.attributes}',
        ],
        ['{continued: true}', '{continued: false}'],
      );
    });

    test('Open in Hermes opens the chat in a window with its draft', () async {
      await windows.togglePanel();

      final move = await host.call('panel.showInWindow', {
        'window_id': 'p0',
        'thread_id': 's1',
        'profile': 'work',
        'title': 'Secret plan',
        'draft': {'text': 'and then?', 'files': <Object>[]},
      });

      final args = host.created.values.single;
      expect(
        (args.threadId, args.profile, args.title),
        ('s1', 'work', 'Secret plan'),
      );
      expect(host.drafts.values.single?.text, 'and then?');
      expect(events, ['panel.opened_in_window {}']);
      expect(move, 'opened');
    });

    test(
      'Open in Hermes focuses a window that already shows the chat',
      () async {
        await windows.open('s1', profile: 'work', title: 'Plan');
        await windows.togglePanel();

        final move = await host.call('panel.showInWindow', {
          'window_id': 'p1',
          'thread_id': 's1',
          'profile': 'work',
          'title': 'Plan',
        });

        expect(host.created, hasLength(1));
        expect(host.focused, ['w0']);
        expect(move, 'focused', reason: 'the window took no draft');
      },
    );

    test('Open in Hermes without a connection fails', () async {
      await windows.togglePanel();
      connection = null;

      final move = await host.call('panel.showInWindow', {
        'window_id': 'p0',
        'thread_id': 's1',
        'profile': 'work',
        'title': 'Plan',
      });

      expect(move, 'failed');
    });

    test('the panel and the main window never record at once', () async {
      var stopped = 0;
      windows.panelTookVoice.listen((_) => stopped++);
      await windows.togglePanel();
      await host.present('p0');

      await host.call('panel.dictating', {'window_id': 'p0'});
      await pumpEventQueue();
      await windows.stopPanelDictation();

      expect(stopped, 1);
      expect(host.commands, [('p0', 'stopDictation')]);
    });

    test('only the panel may open a chat in a window this way', () async {
      await windows.togglePanel();

      await host.call('panel.showInWindow', {
        'window_id': 'w9',
        'thread_id': 's1',
        'profile': 'work',
        'title': 'Plan',
      });

      expect(host.created, isEmpty);
      expect(events, isEmpty);
    });
  });
}
