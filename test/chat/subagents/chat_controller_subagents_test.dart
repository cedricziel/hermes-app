import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway_connection_transport.dart';
import 'package:hermes_app/src/chat/subagents/agent_detail_host.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/agent_work_result.dart';
import 'package:hermes_app/src/chat/subagents/chat_roster_environment.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_chat_transport.dart';
import '../../support/fake_notification_service.dart';

/// A fake that also tells which connection it holds, as the gateway does.
class ConnectedFake extends FakeChatTransport
    implements GatewayConnectionTransport {
  Object? token = Object();
  final _events = StreamController<GatewayConnectionEvent>.broadcast(
    sync: true,
  );

  @override
  Stream<GatewayConnectionEvent> get connectionEvents => _events.stream;

  @override
  Object? get gatewayConnection => token;

  @override
  bool ownsGatewayConnection(Object connection) => identical(token, connection);

  void replaceConnection() {
    token = Object();
    _events.add(GatewayConnectionEvent.lost(token!));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectedFake transport;
  late AttentionNotifier attention;
  late ChatController chat;
  late ValueNotifier<bool> activity;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = ConnectedFake();
    activity = ValueNotifier(true);
    attention = AttentionNotifier(
      service: FakeNotificationService(),
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      transport: transport,
      activity: activity,
      attention: attention,
      report: (_) {},
    );
  });

  tearDown(() {
    chat.dispose();
    attention.dispose();
  });

  const spawned = SubagentUpdated(Subagent(id: 'a1', goal: 'Audit'));
  const finished = SubagentUpdated(
    Subagent(id: 'a1', goal: 'Audit', status: SubagentStatus.completed),
  );

  Future<ChatThread> delegate() async {
    chat.newThread();
    chat.submit('Launch', const []);
    transport.sends.last
      ..emit(const ThreadBound('s1'))
      ..emit(const ReplyStarted())
      ..emit(spawned);
    await pumpEventQueue();
    return chat.selectedThread!;
  }

  test(
    'frames of a reply, and later follow-ups, feed the thread\'s roster',
    () async {
      final thread = await delegate();
      final roster = chat.subagentsIn(thread)!;
      expect(roster.threadId, 's1');
      expect(roster.row('a1')!.state, AgentState.running);
      transport.sends.last
        ..emit(const ReplyCompleted('Done.'))
        ..finish();
      await pumpEventQueue();
      transport.followUpStreams['s1']!.emit(finished);
      await pumpEventQueue();
      expect(roster.row('a1')!.state, AgentState.finished);
      expect(identical(chat.subagentsIn(thread), roster), isTrue);
    },
  );

  test('a thread that is not stored has no roster', () {
    chat.newThread();
    expect(chat.subagentsIn(chat.selectedThread!), isNull);
  });

  test(
    'reads need the connection, and a new connection starts fresh',
    () async {
      final thread = await delegate();
      final roster = chat.subagentsIn(thread)!;
      transport.agentAnswer = (call) => {
        'subagents': [
          {
            'subagent_id': 'remote',
            'goal': 'From elsewhere',
            'status': 'running',
          },
          {'subagent_id': 'a1', 'goal': 'Audit', 'status': 'running'},
        ],
        'delegations': [],
      };
      final watch = roster.watch();
      await pumpEventQueue();
      expect(roster.row('remote'), isNotNull);
      final reads = transport.agentReads.length;
      transport.replaceConnection();
      await pumpEventQueue();
      expect(transport.agentReads.length, reads + 1);
      watch.close();
    },
  );

  test('the activity gate closing drops every roster', () async {
    final thread = await delegate();
    final roster = chat.subagentsIn(thread)!;
    activity.value = false;
    await pumpEventQueue();
    expect(roster.hasAgents, isFalse);
    expect(chat.subagentsIn(thread), isNull);
  });

  test('removing the thread disposes its roster', () async {
    final thread = await delegate();
    final roster = chat.subagentsIn(thread)!;
    chat.dispose();
    roster.applyFrame(const Subagent(id: 'late', goal: 'x'));
    expect(roster.hasAgents, isFalse);
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
    );
  });

  test('a frame landing during the re-read after found false does not make '
      'a vanished agent look alive', () async {
    final thread = await delegate();
    final roster = chat.subagentsIn(thread)!;
    final host = roster.hostFor('a1');
    final gate = Completer<Map<String, Object?>>();
    transport.agentAnswer = (_) => gate.future;
    roster.watch();
    final reread = host.rereadList();
    await pumpEventQueue();
    // The agent's last progress frame lands while the list read is out.
    transport.sends.last.emit(
      const SubagentUpdated(
        Subagent(id: 'a1', goal: 'Audit', lastTool: 'terminal'),
      ),
    );
    await pumpEventQueue();
    gate.complete({'subagents': [], 'delegations': []});
    final answer = await reread;
    final view = (answer as WorkOk<AgentView?>).value;
    expect(view!.active, isFalse);
  });

  test('a roster follows a rotated stored id with its rows', () async {
    final thread = await delegate();
    final roster = chat.subagentsIn(thread)!;
    transport.sends.last.emit(const SessionInfo(storedSessionId: 's2'));
    await pumpEventQueue();
    expect(thread.id, 's2');
    expect(roster.threadId, 's2');
    expect(identical(chat.subagentsIn(thread), roster), isTrue);
    expect(roster.row('a1'), isNotNull);
  });

  group('environment', () {
    test('App Lock, the background and the connection are what it reports', () {
      final lock = ValueNotifier(false);
      final active = ValueNotifier(true);
      final env = ChatRosterEnvironment(
        transport: transport,
        activity: active,
        covered: () => lock.value,
        lockChanges: lock,
      );
      addTearDown(env.dispose);
      var notified = 0;
      env.addListener(() => notified++);
      expect(env.unlocked, isTrue);
      lock.value = true;
      expect(env.unlocked, isFalse);
      expect(notified, 1);
      lock.value = false;
      expect(env.foreground, isTrue);
      env.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(env.foreground, isFalse);
      env.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(env.foreground, isTrue);
      active.value = false;
      expect(env.foreground, isFalse);
      final before = notified;
      transport.replaceConnection();
      expect(notified, before + 1);
      expect(identical(env.connection, transport.token), isTrue);
    });
  });
}
