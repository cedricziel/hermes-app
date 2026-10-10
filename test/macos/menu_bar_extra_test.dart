import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
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
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_menu_bar_tray.dart';
import '../support/recorded_events.dart';

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
  late bool confirmed;
  late MenuBarExtra extra;

  setUp(() {
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
    confirmed = true;
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
    extra = MenuBarExtra(
      tray: tray,
      settings: settings,
      link: link,
      showMainWindow: () async => calls.add('show main'),
      focusWindow: (threadId, profile) async {
        if (!windows.contains(threadId)) return false;
        calls.add('focus $threadId');
        return true;
      },
      confirmAlways: () async => confirmed,
      quit: () async => calls.add('quit'),
      breadcrumbs: Breadcrumbs.of(trail),
      events: () => events.call,
    );
    addTearDown(() {
      extra.dispose();
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
      confirmed = false;

      await tray.pick('Always allow');

      expect(calls, ['show main']);
      expect(transport.approvalAnswers, isEmpty);

      confirmed = true;
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
}

List<String> _crumbs(BreadcrumbTrail trail) => [
  for (final c in trail.recent) '${c.name} ${c.attributes}',
];
