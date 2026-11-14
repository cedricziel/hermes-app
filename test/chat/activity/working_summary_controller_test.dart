import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/working_summary.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_gateway.dart';
import '../../support/fake_hermes_server.dart';

/// `ChatController.workingSummaryIn` against the real gateway transport and a
/// scripted gateway: what each frame does to the summary.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': 'stored-1',
      'session_key': 'stored-1',
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'Working')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', []),
      );
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      report: (_) {},
    );
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    await transport.close();
  });

  Future<void> open() async {
    await chat.loadThreads('work');
    chat.select('stored-1');
    await pumpEventQueue();
    chat.submit('Start', const []);
    await pumpEventQueue();
  }

  Future<void> emit(String type, Map<String, Object?> payload) async {
    gateway.event(type, 'rt-1', payload);
    await pumpEventQueue();
  }

  WorkingSummary? summary() => chat.workingSummaryIn(chat.selectedThread!);

  test('nothing working yields null', () async {
    await open();
    expect(summary(), isNull);
  });

  test('a memory recall is the sentence until it clears', () async {
    await open();
    await emit('status.update', {
      'kind': 'lifecycle',
      'text': '🧠 robot-notes — recalled 5 memories',
    });
    expect(summary()!.sentence.kind, WorkingSentenceKind.status);
    expect(summary()!.sentence.text, contains('recalled 5 memories'));
    // The recall is not a wait: the panel keeps listing it as before.
    expect(chat.sessionStateIn(chat.selectedThread!)!.waits, isEmpty);

    await emit('status.update', {'kind': 'lifecycle', 'text': ''});
    expect(summary(), isNull);
  });

  test('a wait is the sentence; a process after it is newer; closing '
      'the processes brings the wait back', () async {
    await open();
    await emit('status.update', {
      'kind': 'process',
      'text': 'Waiting for background process',
    });
    expect(summary()!.sentence.text, 'Waiting for background process');
    await emit('agent.terminal.output', {'process_id': 'a', 'chunk': 'x'});
    await emit('agent.terminal.output', {'process_id': 'b', 'chunk': 'y'});
    expect(summary()!.sentence.kind, WorkingSentenceKind.processes);
    expect(summary()!.sentence.count, 2);

    await emit('terminal.close', {'process_id': 'a'});
    expect(summary()!.sentence.count, 1);
    await emit('terminal.close', {'process_id': 'b'});
    expect(summary()!.sentence.text, 'Waiting for background process');
  });

  test('goal, loop and heartbeat sentences come from active sections only, '
      'and a repeated snapshot is not newer', () async {
    await open();
    Map<String, Object?> control(String revision, {String heartbeat = 'a'}) => {
      'control': {
        'revision': revision,
        'goal': {'title': 'Ship the weekly digest', 'status': 'active'},
        'loop': {'prompt': 'Old loop', 'status': 'paused'},
        'heartbeat': {'prompt': heartbeat, 'status': 'active'},
      },
    };
    await emit('session.control.update', control('1', heartbeat: 'Ping'));
    expect(summary()!.sentence.text, 'Ping');
    await emit('status.update', {'kind': 'status', 'text': 'Thinking hard'});
    expect(summary()!.sentence.text, 'Thinking hard');
    // A tick: new revision, same texts.
    await emit('session.control.update', control('2', heartbeat: 'Ping'));
    expect(summary()!.sentence.text, 'Thinking hard');
    await emit('status.update', {'kind': 'status', 'text': ''});
    expect(summary()!.sentence.text, 'Ping');
  });

  test('mixture-of-agents: asking, references counter and combining', () async {
    await open();
    await emit('moa.progress', {
      'label': 'Advisor',
      'refs_done': 1,
      'refs_total': 3,
    });
    var s = summary()!;
    expect(s.sentence.kind, WorkingSentenceKind.askingModels);
    expect(s.sentence.count, 3);
    // The sentence already says it, so no references counter.
    expect(s.counters, isEmpty);
    await emit('moa.aggregating', {'aggregator': 'Reporter'});
    s = summary()!;
    expect(s.sentence.kind, WorkingSentenceKind.combiningAnswers);
  });

  test('a plan: open task reads as the plan, with its counter; all done '
      'drops it', () async {
    await open();
    await emit('todo.updated', {
      'revision': 1,
      'todos': [
        {'id': 'a', 'content': 'Draft', 'status': 'completed'},
        {'id': 'b', 'content': 'Review', 'status': 'in_progress'},
        {'id': 'c', 'content': 'Ship', 'status': 'pending'},
      ],
    });
    var s = summary()!;
    expect(s.sentence.kind, WorkingSentenceKind.plan);
    expect(s.counters.single.value, 1);
    expect(s.counters.single.total, 3);
    await emit('todo.updated', {
      'revision': 2,
      'todos': [
        {'id': 'a', 'content': 'Draft', 'status': 'completed'},
        {'id': 'b', 'content': 'Review', 'status': 'cancelled'},
      ],
    });
    expect(summary(), isNull);
  });

  test('a plan counter rides beside a process sentence', () async {
    await open();
    await emit('todo.updated', {
      'revision': 1,
      'todos': [
        {'id': 'a', 'content': 'Draft', 'status': 'completed'},
        {'id': 'b', 'content': 'Review', 'status': 'pending'},
      ],
    });
    await emit('status.update', {'kind': 'status', 'text': 'Recalled 2 notes'});
    final s = summary()!;
    expect(s.sentence.text, 'Recalled 2 notes');
    expect(s.counters.single.kind, WorkingCounterKind.plan);
  });

  test('restoring while the resume loads, not after', () async {
    await open();
    await emit('session.resume_progress', {
      'phase': 'history',
      'status': 'loading',
    });
    expect(summary()!.sentence.kind, WorkingSentenceKind.restoring);
    await emit('session.resume_progress', {
      'phase': 'history',
      'status': 'complete',
    });
    expect(summary(), isNull);
  });
}
