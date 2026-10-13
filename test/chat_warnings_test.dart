import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/chat_warning_state.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_notification_service.dart';
import 'support/fake_hermes_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatController chat;
  late FakeChatTransport transport;
  late AttentionNotifier attention;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    attention = AttentionNotifier(
      service: FakeNotificationService(),
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    chat.newThread();
    chat.submit('Test warning delivery', const []);
  });
  tearDown(() {
    chat.dispose();
    attention.dispose();
  });

  test(
    'switching profiles clears notices and ignores the old stream',
    () async {
      chat.dispose();
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'shared', title: 'Chat')]),
        )
        ..on(
          'GET',
          '/api/sessions/shared/messages',
          messageListBody('shared', []),
        );
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        attention: attention,
        report: (_) {},
      );
      await chat.loadThreads('one');
      chat.select('shared');
      await pumpEventQueue();
      chat.submit('First profile', const []);
      final oldThread = chat.selectedThread!;
      final oldSend = transport.sends.last;
      oldSend.emit(
        const NoticeShown(
          AgentNotice(text: 'Old warning'),
          runtimeId: 'one-runtime',
        ),
      );
      await pumpEventQueue();
      expect(chat.noticesIn(oldThread), hasLength(1));
      await chat.loadThreads('two');
      chat.select('shared');
      oldSend.emit(
        const NoticeShown(
          AgentNotice(text: 'Late warning'),
          runtimeId: 'one-runtime',
        ),
      );
      await pumpEventQueue();
      expect(chat.noticesIn(oldThread), isEmpty);
      expect(chat.noticesIn(chat.selectedThread!), isEmpty);
    },
  );

  test(
    'warning actions record fixed breadcrumbs without content or identity',
    () async {
      chat.dispose();
      final trail = BreadcrumbTrail();
      chat = ChatController(
        transport: transport,
        attention: attention,
        report: (_) {},
        breadcrumbs: Breadcrumbs.of(trail),
      );
      chat.newThread();
      chat.submit('Private prompt', const []);
      const notice = AgentNotice(text: 'Private warning', key: 'private-key');
      transport.sends.last.emit(
        const NoticeShown(notice, runtimeId: 'private-runtime'),
      );
      await pumpEventQueue();
      chat.warningDetailsOpened();
      chat.dismissNotice(chat.selectedThread!, notice);
      expect(
        trail.recent
            .where((crumb) => crumb.name == 'chat.visibility_action')
            .map((crumb) => crumb.attributes),
        [
          {'feature': 'warnings', 'action': 'details'},
          {'feature': 'warnings', 'action': 'dismiss'},
        ],
      );
    },
  );

  test('a discarded reply connection clears sticky notices', () async {
    transport.sends.last.emit(
      const NoticeShown(AgentNotice(text: 'Pending warning')),
    );
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    expect(chat.noticesIn(thread), hasLength(1));
    transport.sends.last.finish();
    await pumpEventQueue();
    expect(chat.noticesIn(thread), isEmpty);
  });

  test('a normal send takeover retains sticky notices', () async {
    transport.sends.last
      ..emit(const ThreadBound('thread-a'))
      ..emit(
        const NoticeShown(
          AgentNotice(text: 'Sticky warning'),
          runtimeId: 'runtime-a',
        ),
      )
      ..emit(const ReplyCompleted('Done'))
      ..finish();
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    expect(chat.noticesIn(thread), hasLength(1));
    chat.submit('Next turn', const []);
    transport.followUpStreams['thread-a']!.finish();
    await pumpEventQueue();
    expect(chat.noticesIn(thread).single.text, 'Sticky warning');
  });

  const risk = ToolOutputRisk(
    risk: 'secret',
    findings: ['Credential removed'],
    redacted: true,
  );
  test(
    'active warning scope discard rejects a prior pending tool risk',
    () async {
      transport.sends.last
        ..emit(
          const NoticeShown(
            AgentNotice(text: 'Old notice'),
            runtimeId: 'runtime-a',
          ),
        )
        ..emit(const ToolRiskFlagged('reused', risk, runtimeId: 'runtime-a'))
        ..emit(const WarningScopeDiscarded())
        ..emit(
          const ToolStarted(
            id: 'reused',
            name: 'terminal',
            runtimeId: 'runtime-a',
          ),
        );
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      expect(chat.noticesIn(thread), isEmpty);
      expect(thread.messages.last.toolCalls.single.outputRisk, isNull);
    },
  );

  test(
    'new scope risk never attaches to a historical tool with reused IDs',
    () async {
      transport.sends.last
        ..emit(
          const ToolStarted(
            id: 'reused',
            name: 'terminal',
            runtimeId: 'runtime-a',
          ),
        )
        ..emit(const ReplyCompleted('First turn'))
        ..emit(const ThreadBound('thread-a'))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      final previous = thread.messages.last;
      final follow = transport.followUpStreams['thread-a']!;
      follow
        ..emit(const WarningScopeDiscarded())
        ..emit(const ToolRiskFlagged('reused', risk, runtimeId: 'runtime-a'));
      await pumpEventQueue();
      expect(previous.toolCalls.single.outputRisk, isNull);
      follow.emit(
        const ToolStarted(
          id: 'reused',
          name: 'terminal',
          runtimeId: 'runtime-a',
        ),
      );
      await pumpEventQueue();
      expect(previous.toolCalls.single.outputRisk, isNull);
      expect(thread.messages.last.toolCalls.single.outputRisk, same(risk));
    },
  );

  test(
    'standalone idle scope discard notifies the notice presentation',
    () async {
      transport.sends.last
        ..emit(const ThreadBound('thread-a'))
        ..emit(
          const NoticeShown(
            AgentNotice(text: 'Old notice'),
            runtimeId: 'runtime-a',
          ),
        )
        ..emit(const ReplyCompleted('First turn'))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      var changes = 0;
      chat.addListener(() => changes++);
      transport.followUpStreams['thread-a']!.emit(
        const WarningScopeDiscarded(),
      );
      await pumpEventQueue();
      expect(chat.noticesIn(thread), isEmpty);
      expect(changes, greaterThan(0));
    },
  );

  test(
    'idle scope discard clears only discarded notices before new delivery',
    () async {
      transport.sends.last
        ..emit(const ThreadBound('thread-a'))
        ..emit(
          const NoticeShown(
            AgentNotice(text: 'Old notice'),
            runtimeId: 'runtime-a',
          ),
        )
        ..emit(const ReplyCompleted('First turn'))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      final follow = transport.followUpStreams['thread-a']!;
      follow.emit(const ThreadNeedsRefetch());
      await pumpEventQueue();
      expect(chat.noticesIn(thread).single.text, 'Old notice');
      follow
        ..emit(const WarningScopeDiscarded())
        ..emit(
          const NoticeShown(
            AgentNotice(text: 'New notice'),
            runtimeId: 'runtime-a',
          ),
        );
      await pumpEventQueue();
      expect(chat.noticesIn(thread).single.text, 'New notice');
    },
  );

  test(
    'risk before tool start attaches only to matching runtime and tool',
    () async {
      transport.sends.last
        ..emit(const ToolRiskFlagged('tool-a', risk, runtimeId: 'runtime-a'))
        ..emit(
          const ToolStarted(
            id: 'other',
            name: 'terminal',
            runtimeId: 'runtime-a',
          ),
        )
        ..emit(
          const ToolStarted(
            id: 'tool-a',
            name: 'terminal',
            runtimeId: 'runtime-a',
          ),
        );
      await pumpEventQueue();
      final reply = chat.selectedThread!.messages.last;
      expect(reply.toolCalls.first.outputRisk, isNull);
      expect(reply.toolCalls.last.outputRisk, same(risk));
      expect(reply.isPending, isTrue);
    },
  );

  test(
    'notice between turns does not create a reply and clears by key',
    () async {
      transport.sends.last
        ..emit(const ThreadBound('thread-a'))
        ..emit(const ReplyCompleted('Done'))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      final before = thread.messages.length;
      transport.followUpStreams['thread-a']!.emit(
        const NoticeShown(
          AgentNotice(text: 'Credits are low', key: 'credit'),
          runtimeId: 'runtime-a',
        ),
      );
      await pumpEventQueue();
      expect(chat.noticesIn(thread).single.text, 'Credits are low');
      expect(thread.messages, hasLength(before));
      transport.followUpStreams['thread-a']!.emit(
        const NoticeCleared('credit', runtimeId: 'runtime-a'),
      );
      await pumpEventQueue();
      expect(chat.noticesIn(thread), isEmpty);
    },
  );

  test(
    'reused tool id in a new runtime does not alter an earlier tool',
    () async {
      transport.sends.last
        ..emit(
          const ToolStarted(
            id: 'tool-a',
            name: 'terminal',
            runtimeId: 'runtime-a',
          ),
        )
        ..emit(const ToolRiskFlagged('tool-a', risk, runtimeId: 'runtime-b'));
      await pumpEventQueue();
      expect(
        chat.selectedThread!.messages.last.toolCalls.single.outputRisk,
        isNull,
      );
    },
  );

  test(
    'warning logging includes no notice content and cannot break delivery',
    () async {
      final logged = <Map<String, Object>>[];
      chat.dispose();
      chat = ChatController(
        transport: transport,
        attention: attention,
        report: (_) {},
        events: (name, [attributes = const {}]) {
          if (name == 'gateway.visibility_outcome') {
            logged.add(Map.from(attributes));
          }
          throw StateError('Telemetry unavailable');
        },
      );
      chat.newThread();
      chat.submit('Private prompt', const []);
      transport.sends.last.emit(
        const NoticeShown(
          AgentNotice(text: 'Private warning', key: 'private-key'),
        ),
      );
      await pumpEventQueue();
      expect(
        chat.noticesIn(chat.selectedThread!).single.text,
        'Private warning',
      );
      expect(logged, [
        {'feature': 'warnings', 'outcome': 'applied'},
      ]);
    },
  );
}
