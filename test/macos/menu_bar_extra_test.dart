import 'dart:async';
import 'dart:convert';

import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_link.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_model.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_settings.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_menu_bar_tray.dart';
import '../support/recorded_events.dart';

const _alwaysApproval = ApprovalRequest(
  requestId: 'r1',
  command: 'ls',
  description: '',
  choices: ['once', 'always'],
);

const _approval2 = ApprovalRequest(
  requestId: 'r2',
  command: 'make',
  description: '',
  choices: ['once', 'deny'],
);

const _approval = ApprovalRequest(
  requestId: 'r-secret-id',
  command: 'rm -rf build',
  description: 'Clean the build',
  choices: ['once', 'deny'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatTransport transport;
  late FakeMenuBarTray tray;
  late MenuBarExtraLink link;
  late MenuBarExtraSettings settings;
  late ChatController chat;
  late BreadcrumbTrail trail;
  late RecordedEvents events;
  late List<NotificationTarget> opened;
  late List<String> calls;
  late Set<String> windows;
  late Future<bool> Function() confirm;
  late AppLockController lock;
  late FakeDeviceAuthenticator authenticator;
  late MenuBarExtra extra;

  MenuBarExtra build({Duration interval = Duration.zero}) => MenuBarExtra(
    tray: tray,
    settings: settings,
    link: link,
    lock: lock,
    refreshInterval: interval,
    showMainWindow: () async => calls.add('show main'),
    focusWindow: (threadId, profile) async {
      if (!windows.contains(threadId)) return false;
      calls.add('focus $threadId');
      return true;
    },
    confirmAlways: () => confirm(),
    quit: () async => calls.add('quit'),
    breadcrumbs: Breadcrumbs.of(trail),
    events: () => events.call,
  );

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    tray = FakeMenuBarTray();
    link = MenuBarExtraLink();
    settings = MenuBarExtraSettings();
    trail = BreadcrumbTrail();
    events = RecordedEvents();
    opened = [];
    calls = [];
    windows = {};
    confirm = () async => true;
    authenticator = FakeDeviceAuthenticator();
    lock = AppLockController(
      authenticator: authenticator,
      coverWhenInactive: false,
    );
    await lock.load();
    await settings.load();
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    extra = build();
    addTearDown(() {
      extra.dispose();
      lock.dispose();
      link.dispose();
      settings.dispose();
      chat.dispose();
      attention.dispose();
    });
  });

  void connect() => link.connect(
    chat: chat,
    openChat: opened.add,
    newChat: () => calls.add('new chat'),
  );

  /// Sends a prompt in a new chat and returns its thread.
  ChatThread startReply({String prompt = 'Run it'}) {
    chat.newThread();
    final thread = chat.selectedThread!;
    chat.submit(prompt, const []);
    return thread;
  }

  Future<void> raiseApproval([ApprovalRequest request = _approval]) async {
    transport.sends.last.emit(ApprovalRequested(request));
    await pumpEventQueue();
  }

  group('icon', () {
    test('is idle with nothing to show', () {
      expect(tray.last.state, MenuBarIconState.idle);
      expect(tray.titles, ['New Chat', 'Show Main Window', 'Quit Hermes']);
    });

    test('works while a reply runs and idles when it is done', () async {
      connect();
      startReply();
      expect(tray.last.state, MenuBarIconState.working);

      transport.sends.single.emit(const ReplyCompleted('Done'));
      await pumpEventQueue();

      expect(tray.last.state, MenuBarIconState.idle);
    });

    test('needs attention over working while an approval waits', () async {
      connect();
      startReply();
      await raiseApproval();

      expect(tray.last.state, MenuBarIconState.attention);

      await tray.pick('Allow once');

      expect(tray.last.state, MenuBarIconState.working);
    });

    test('needs attention for a request only the chat can answer', () async {
      connect();
      startReply();
      transport.sends.single.emit(
        const UnsupportedRequested(
          UnsupportedRequest(requestId: 's1', kind: UnsupportedKind.sudo),
        ),
      );
      await pumpEventQueue();

      expect(tray.last.state, MenuBarIconState.attention);
    });

    test('does not rebuild the menu when only the reply text moved', () async {
      connect();
      startReply();
      final before = tray.updates.length;

      transport.sends.single
        ..emit(const ReplyDelta('One '))
        ..emit(const ReplyDelta('two'));
      await pumpEventQueue();

      expect(tray.updates, hasLength(before));
    });
  });

  group('menu', () {
    test('lists the replying chats and ends with the fixed entries', () {
      connect();
      startReply(prompt: 'Plan the trip');

      expect(tray.titles, [
        'Running replies',
        'Plan the trip',
        'New Chat',
        'Show Main Window',
        'Quit Hermes',
      ]);
    });

    test('offers exactly the choices the request offers', () async {
      connect();
      startReply();
      await raiseApproval(
        const ApprovalRequest(
          requestId: 'r1',
          command: 'ls',
          description: '',
          choices: ['once', 'session', 'always', 'deny'],
        ),
      );

      expect(tray.submenuOf('ls'), [
        'Run it: ls',
        'Allow once',
        'Allow for session',
        'Always allow',
        'Deny',
      ]);
    });

    test('offers once and deny when the request lists no choices', () async {
      connect();
      startReply();
      await raiseApproval(
        const ApprovalRequest(
          requestId: 'r1',
          command: 'ls',
          description: '',
          choices: [],
        ),
      );

      expect(tray.submenuOf('ls').skip(1), ['Allow once', 'Deny']);
    });

    test('trims a long command in the row and in the submenu', () async {
      connect();
      startReply();
      final command = 'echo ${'x' * 400}';
      await raiseApproval(
        ApprovalRequest(
          requestId: 'r1',
          command: command,
          description: '',
          choices: const ['once'],
        ),
      );

      final row = tray.titles.firstWhere((t) => t.startsWith('echo'));
      expect(row.length, 60);
      expect(row, endsWith('…'));
      final note = tray.submenuOf(row).first;
      expect(note.length, lessThanOrEqualTo(310));
      expect(note, endsWith('…'));
    });

    test('lists a question as a row that opens its chat', () async {
      connect();
      startReply(prompt: 'Ask me');
      transport.sends.single.emit(
        const ClarifyRequested(
          ClarifyRequest(
            requestId: 'q1',
            questions: [ClarifyQuestion(qid: '', question: 'Which one?')],
          ),
        ),
      );
      await pumpEventQueue();

      expect(tray.titles, contains('Open Ask me'));
    });

    test('shows only the fixed entries once signed out', () async {
      connect();
      startReply();
      await raiseApproval();

      link.disconnect(chat);

      expect(tray.last.state, MenuBarIconState.idle);
      expect(tray.titles, ['New Chat', 'Show Main Window', 'Quit Hermes']);
    });

    test('opening it sends nothing to the server', () async {
      connect();
      startReply();
      await raiseApproval();
      final sends = transport.sends.length;

      tray.openMenu();

      expect(transport.sends, hasLength(sends));
      expect(transport.approvalAnswers, isEmpty);
      expect(transport.openAnswers, isEmpty);
    });
  });

  group('actions', () {
    test('a running reply opens in the main window', () async {
      connect();
      final thread = startReply();

      await tray.pick('Run it');

      expect(calls, ['show main']);
      expect(opened.single.threadId, thread.id);
    });

    test(
      'a reply whose chat has a window brings that window forward',
      () async {
        connect();
        final thread = startReply();
        windows.add(thread.id);

        await tray.pick('Run it');

        expect(calls, ['focus ${thread.id}']);
        expect(opened, isEmpty);
      },
    );

    test('allow once answers as the card does', () async {
      connect();
      final thread = startReply();
      await raiseApproval();

      await tray.pick('Allow once');

      expect(transport.approvalAnswers, [('r-secret-id', 'once')]);
      final request =
          thread.messages.last.inputRequests.single as ApprovalRequest;
      expect(request.status, InputRequestStatus.answered);
      expect(request.choice, 'once');
      expect(tray.titles, isNot(contains('rm -rf build')));
    });

    test('always allow asks first and sends nothing when declined', () async {
      connect();
      startReply();
      await raiseApproval(
        const ApprovalRequest(
          requestId: 'r1',
          command: 'ls',
          description: '',
          choices: ['once', 'always'],
        ),
      );
      confirm = () async => false;

      await tray.pick('Always allow');

      expect(calls, ['show main']);
      expect(transport.approvalAnswers, isEmpty);

      confirm = () async => true;
      authenticator = FakeDeviceAuthenticator();
      lock = AppLockController(
        authenticator: authenticator,
        coverWhenInactive: false,
      );
      await lock.load();
      await settings.load();
      await tray.pick('Always allow');

      expect(transport.approvalAnswers, [('r1', 'always')]);
    });

    test('an approval the server withdrew expires and leaves', () async {
      connect();
      final thread = startReply();
      await raiseApproval();
      transport.accepts = false;

      await tray.pick('Allow once');

      final request =
          thread.messages.last.inputRequests.single as ApprovalRequest;
      expect(request.status, InputRequestStatus.expired);
      expect(tray.titles, isNot(contains('rm -rf build')));
      expect(opened, isEmpty);
      expect(events.named('menubar.approval_answered'), [
        {'choice': 'once', 'accepted': false},
      ]);
    });

    test('an answer that cannot be sent opens the chat', () async {
      connect();
      final thread = startReply();
      await raiseApproval();
      transport.answerError = StateError('socket closed');

      await tray.pick('Allow once');

      expect(calls, ['show main']);
      expect(opened.single.threadId, thread.id);
    });

    test('new chat shows the main window and starts a chat', () async {
      connect();

      await tray.pick('New Chat');

      expect(calls, ['show main', 'new chat']);
    });

    test('show main window and quit', () async {
      connect();

      await tray.pick('Show Main Window');
      await tray.pick('Quit Hermes');

      expect(calls, ['show main', 'quit']);
    });
  });

  group('settings', () {
    test('hides the item and shows it again', () async {
      connect();
      expect(tray.last.visible, isTrue);

      await settings.setEnabled(false);
      expect(tray.last.visible, isFalse);

      await settings.setEnabled(true);
      expect(tray.last.visible, isTrue);
    });

    test('removes the item when the app lets go of it', () {
      extra.dispose();

      expect(tray.last.visible, isFalse);
    });
  });

  group('telemetry', () {
    test('records the menu opening with counts only', () async {
      connect();
      startReply(prompt: 'Private plan');
      await raiseApproval();

      tray.openMenu();

      expect(_crumbs(trail), ['menubar.opened {replies: 1, approvals: 1}']);
    });

    test('records each action with fixed names', () async {
      connect();
      startReply(prompt: 'Private plan');
      await raiseApproval();

      await tray.pick('Allow once');
      await tray.pick('Private plan');
      await tray.pick('New Chat');
      await tray.pick('Show Main Window');
      await tray.pick('Quit Hermes');

      expect(_crumbs(trail), [
        'menubar.action {kind: approve, choice: once}',
        'menubar.action {kind: open_chat}',
        'menubar.action {kind: new_chat}',
        'menubar.action {kind: show_main}',
        'menubar.action {kind: quit}',
      ]);
      expect(events.named('menubar.approval_answered'), [
        {'choice': 'once', 'accepted': true},
      ]);
    });

    test('never carries a title, a command or an id', () async {
      connect();
      startReply(prompt: 'Private plan');
      await raiseApproval();
      tray.openMenu();
      await tray.pick('Allow once');

      final everything = [
        ..._crumbs(trail),
        ...events.named('menubar.approval_answered').map((e) => '$e'),
      ].join();
      expect(everything, isNot(contains('Private')));
      expect(everything, isNot(contains('rm -rf')));
      expect(everything, isNot(contains('r-secret-id')));
    });
  });

  group('App Lock', () {
    Future<void> lockApp() async {
      await lock.setEnabled(true);
      lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
    }

    test(
      'shows counts and an unlock entry, never a title or command',
      () async {
        connect();
        startReply(prompt: 'Private plan');
        await raiseApproval();

        await lockApp();

        expect(tray.titles, [
          '1 reply running',
          '1 request waiting',
          'Unlock Hermes…',
          'New Chat',
          'Show Main Window',
          'Quit Hermes',
        ]);
        expect(tray.last.state, MenuBarIconState.attention);
        final sent = jsonEncode([for (final i in tray.last.items) i.toJson()]);
        expect(sent, isNot(contains('Private')));
        expect(sent, isNot(contains('rm -rf')));
        expect(sent, isNot(contains('Allow once')));
      },
    );

    test('says how many replies and requests are waiting', () async {
      connect();
      startReply(prompt: 'One');
      await raiseApproval();
      chat.newThread();
      chat.submit('Two', const []);
      transport.sends.last.emit(const ApprovalRequested(_approval2));
      await pumpEventQueue();

      await lockApp();

      expect(tray.titles.take(2), ['2 replies running', '2 requests waiting']);
    });

    test('offers only the unlock entry when nothing is running', () async {
      connect();

      await lockApp();

      expect(tray.titles, [
        'Unlock Hermes…',
        'New Chat',
        'Show Main Window',
        'Quit Hermes',
      ]);
    });

    test('a pick made before the lock cannot answer an approval', () async {
      connect();
      startReply();
      await raiseApproval();
      final allow = tray.item('Allow once').key!;

      await lockApp();
      tray.pickKey(allow);
      await tray.settle();

      expect(transport.approvalAnswers, isEmpty);
      expect(_crumbs(trail), ['menubar.stale_pick {}']);
    });

    test('unlock shows the main window and asks the device', () async {
      connect();
      startReply();
      await raiseApproval();
      await lockApp();

      await tray.pick('Unlock Hermes…');
      await pumpEventQueue();

      expect(calls, ['show main']);
      expect(authenticator.reasons.last, 'Unlock Hermes');
      expect(lock.locked, isFalse);
      expect(tray.titles, contains('Run it'));
      expect(tray.submenuOf('rm -rf build'), contains('Allow once'));
    });

    test('a failed unlock leaves the menu locked', () async {
      connect();
      await lockApp();
      authenticator.succeeds = false;

      await tray.pick('Unlock Hermes…');
      await pumpEventQueue();

      expect(lock.locked, isTrue);
      expect(tray.titles, contains('Unlock Hermes…'));
    });

    test('locking behind the always question sends nothing', () async {
      connect();
      startReply();
      await raiseApproval(_alwaysApproval);
      final question = Completer<bool>();
      confirm = () => question.future;

      tray.pickKey(tray.item('Always allow').key!);
      await tray.settle();
      await lockApp();
      question.complete(true);
      await pumpEventQueue();

      expect(transport.approvalAnswers, isEmpty);
    });

    test(
      'locking is urgent so an open menu does not keep the titles',
      () async {
        connect();
        startReply();
        await raiseApproval();
        expect(tray.updates.every((u) => !u.urgent), isTrue);

        await lockApp();

        expect(tray.last.urgent, isTrue);
        expect(tray.titles, contains('Unlock Hermes…'));

        authenticator.succeeds = true;
        await tray.pick('Unlock Hermes…');
        await pumpEventQueue();

        expect(tray.last.urgent, isFalse);
      },
    );

    test('unlock leaves a fixed crumb', () async {
      connect();
      startReply();
      await raiseApproval();
      await lockApp();

      await tray.pick('Unlock Hermes…');

      expect(_crumbs(trail), ['menubar.action {kind: unlock}']);
    });
  });

  group('picks', () {
    test(
      'a key that is not in the menu does nothing and leaves a crumb',
      () async {
        connect();

        tray.pickKey('approve:gone:gone:once');
        await tray.settle();

        expect(calls, isEmpty);
        expect(opened, isEmpty);
        expect(_crumbs(trail), ['menubar.stale_pick {}']);
      },
    );

    test('an approval answered meanwhile cannot be answered again', () async {
      connect();
      final thread = startReply();
      await raiseApproval();
      final deny = tray.item('Deny').key!;

      await chat.answerApproval(thread, 'r-secret-id', 'once');
      tray.pickKey(deny);
      await tray.settle();

      expect(transport.approvalAnswers, [('r-secret-id', 'once')]);
      expect(_crumbs(trail), ['menubar.stale_pick {}']);
    });

    test('a key names what it does, not where it is', () async {
      connect();
      startReply();
      await raiseApproval(
        const ApprovalRequest(
          requestId: 'a',
          command: 'first',
          description: '',
          choices: ['once', 'deny'],
        ),
      );
      final denyFirst = tray.item('Deny').key!;

      // Another approval is added to the menu.
      transport.sends.last.emit(
        const ApprovalRequested(
          ApprovalRequest(
            requestId: 'b',
            command: 'second',
            description: '',
            choices: ['session', 'always', 'once', 'deny'],
          ),
        ),
      );
      await pumpEventQueue();
      tray.pickKey(denyFirst);
      await tray.settle();

      expect(transport.approvalAnswers, [('a', 'deny')]);
    });

    test('a key stays the same while the menu is rebuilt around it', () async {
      connect();
      startReply();
      await raiseApproval();
      final allow = tray.item('Allow once').key!;

      transport.sends.single.emit(const ReplyDelta('still going'));
      await pumpEventQueue();

      expect(tray.item('Allow once').key, allow);
    });

    test('an answer for a chat that left the list opens the chat', () async {
      connect();
      final thread = startReply();
      await raiseApproval();
      chat.threads.remove(thread);

      await tray.pick('Allow once');

      expect(transport.approvalAnswers, isEmpty);
      expect(calls, ['show main']);
      expect(opened.single.threadId, thread.id);
    });
  });

  group('answers in flight', () {
    test('a second pick while one is on its way sends nothing', () async {
      connect();
      startReply();
      await raiseApproval();
      final gate = transport.answerGate = Completer<void>();
      final allow = tray.item('Allow once').key!;
      final deny = tray.item('Deny').key!;

      tray.pickKey(allow);
      await tray.settle();

      expect(tray.submenuOf('rm -rf build'), ['Answering…']);
      tray.pickKey(deny);
      tray.pickKey(allow);
      await tray.settle();
      gate.complete();
      await pumpEventQueue();

      expect(transport.approvalAnswers, [('r-secret-id', 'once')]);
      expect(tray.titles, isNot(contains('rm -rf build')));
    });

    test(
      'a request answered during the always question is left alone',
      () async {
        connect();
        final thread = startReply();
        await raiseApproval(_alwaysApproval);
        final question = Completer<bool>();
        confirm = () => question.future;

        tray.pickKey(tray.item('Always allow').key!);
        await tray.settle();
        await chat.answerApproval(thread, 'r1', 'once');
        question.complete(true);
        await pumpEventQueue();

        expect(transport.approvalAnswers, [('r1', 'once')]);
      },
    );

    test('the choices come back when the answer could not be sent', () async {
      connect();
      startReply();
      await raiseApproval();
      transport.answerError = StateError('socket closed');

      await tray.pick('Allow once');

      expect(opened, hasLength(1));
      expect(tray.submenuOf('rm -rf build'), contains('Allow once'));
    });
  });

  group('visibility', () {
    MenuBarExtra extraFor(MenuBarExtraSettings settings, FakeMenuBarTray tray) {
      final extra = MenuBarExtra(
        tray: tray,
        settings: settings,
        link: MenuBarExtraLink(),
        showMainWindow: () async {},
        focusWindow: (_, _) async => false,
        confirmAlways: () async => true,
        quit: () async {},
        refreshInterval: Duration.zero,
      );
      addTearDown(extra.dispose);
      return extra;
    }

    test('stays hidden until the setting has loaded', () async {
      final unloaded = MenuBarExtraSettings();
      final other = FakeMenuBarTray();
      extraFor(unloaded, other);

      expect(other.updates, isEmpty);

      await unloaded.load();

      expect(other.last.visible, isTrue);
    });

    test('a saved off never shows the item', () async {
      await SharedPreferencesAsync().setBool('menuBarExtra.enabled', false);
      final saved = MenuBarExtraSettings();
      final other = FakeMenuBarTray();
      extraFor(saved, other);

      await saved.load();

      expect(other.updates, isEmpty);
    });

    test('sends nothing while the item is hidden', () async {
      connect();
      await settings.setEnabled(false);
      final sent = tray.updates.length;

      startReply();
      await raiseApproval();

      expect(tray.updates, hasLength(sent));
      expect(tray.last.visible, isFalse);

      await settings.setEnabled(true);

      expect(tray.last.visible, isTrue);
      expect(tray.last.state, MenuBarIconState.attention);
    });
  });

  group('rebuilds', () {
    test('streamed changes are applied at most once per interval', () async {
      extra.dispose();
      extra = build(interval: const Duration(milliseconds: 60));
      connect();
      final sent = tray.updates.length;

      startReply();
      await raiseApproval();

      // The first change went out at once; the rest wait for the interval.
      expect(tray.updates.length, lessThanOrEqualTo(sent + 1));
      expect(tray.last.state, isNot(MenuBarIconState.attention));

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(tray.last.state, MenuBarIconState.attention);
      expect(tray.updates.length, lessThanOrEqualTo(sent + 2));
    });
  });

  group('telemetry choices', () {
    test('an unknown choice is reported as other', () async {
      connect();
      startReply();
      await raiseApproval(
        const ApprovalRequest(
          requestId: 'r1',
          command: 'ls',
          description: '',
          choices: ['once', 'only-on-tuesdays'],
        ),
      );

      await tray.pick('only-on-tuesdays');

      expect(_crumbs(trail), ['menubar.action {kind: approve, choice: other}']);
      expect(events.named('menubar.approval_answered'), [
        {'choice': 'other', 'accepted': true},
      ]);
      expect(transport.approvalAnswers, [('r1', 'only-on-tuesdays')]);
    });
  });
}

List<String> _crumbs(BreadcrumbTrail trail) => [
  for (final c in trail.recent) '${c.name} ${c.attributes}',
];
