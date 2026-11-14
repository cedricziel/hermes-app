import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/process_card_mapper.dart';
import 'package:hermes_app/src/chat/subagents/process_models.dart';
import 'package:hermes_app/src/chat/subagents/process_stop_controller.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import 'subagents/process_fixtures.dart';

/// The program list and Stop through the real gateway transport, the chat
/// controller's cards and the roster's reads.
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
    gateway.handlers['subagent.list'] = (_) => {
      'subagents': [],
      'delegations': [],
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'Programs')]),
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
  }

  void output(String process, String chunk) => gateway.event(
    'agent.terminal.output',
    'rt-1',
    {'process_id': process, 'chunk': chunk},
  );

  test(
    'a shown panel lists the session\'s programs into their cards',
    () async {
      await open();
      final thread = chat.selectedThread!;
      output('proc_ab12', 'from frames');
      await pumpEventQueue();
      gateway.handlers['process.list'] = (_) => processListAnswer;
      final roster = chat.subagentsIn(thread)!;
      final watch = roster.watch();
      await pumpEventQueue();
      final list = gateway.requests.where(
        (request) => request['method'] == 'process.list',
      );
      expect(list, hasLength(1));
      expect((list.single['params'] as Map)['session_id'], 'rt-1');
      final cards = chat.processOutputsIn(thread)!;
      final card = cards.card('proc_ab12')!;
      expect(card.text, 'from frames');
      expect(processCardInfo(card)!.command, 'npm test');
      expect(processCardInfo(card)!.status, ProcessCardStatus.running);
      // Exited programs without a card were not added.
      expect(cards.cards.map((c) => c.processId), ['proc_ab12']);
      watch.close();
    },
  );

  test('Stop program sends one process.kill and the card reads Stopped; '
      'process.stop is never sent', () async {
    await open();
    final thread = chat.selectedThread!;
    output('proc_ab12', 'from frames');
    await pumpEventQueue();
    gateway.handlers['process.list'] = (_) => processListAnswer;
    gateway.handlers['process.kill'] = (_) => killKilled;
    final roster = chat.subagentsIn(thread)!;
    final watch = roster.watch();
    await pumpEventQueue();
    final stop = ProcessStopController(
      key: ProcessKey(
        threadId: thread.id,
        profile: 'work',
        connection: roster.connection!,
        processId: 'proc_ab12',
      ),
      repository: roster.repository,
      host: roster.programHostFor('proc_ab12')!,
    );
    expect(stop.canStop, isTrue);
    stop.startStop();
    await stop.confirmStop();
    expect(stop.phase, ProcessStopPhase.killed);
    final card = chat.processOutputsIn(thread)!.card('proc_ab12')!;
    expect(processCardInfo(card)!.status, ProcessCardStatus.stopped);
    expect(card.text, 'from frames', reason: 'kill output not appended');
    final methods = gateway.requests.map((r) => r['method']).toList();
    expect(methods.where((m) => m == 'process.kill'), hasLength(1));
    expect(methods, isNot(contains('process.stop')));
    stop.dispose();
    watch.close();
  });

  test(
    'an older gateway without process.list leaves the cards as today',
    () async {
      await open();
      final thread = chat.selectedThread!;
      output('proc_ab12', 'from frames');
      await pumpEventQueue();
      gateway.unknownMethods.add('process.list');
      final roster = chat.subagentsIn(thread)!;
      final watch = roster.watch();
      await pumpEventQueue();
      final card = chat.processOutputsIn(thread)!.card('proc_ab12')!;
      expect(processCardInfo(card), isNull);
      final stop = ProcessStopController(
        key: ProcessKey(
          threadId: thread.id,
          profile: 'work',
          connection: roster.connection!,
          processId: 'proc_ab12',
        ),
        repository: roster.repository,
        host: roster.programHostFor('proc_ab12')!,
      );
      expect(stop.canStop, isFalse);
      stop.dispose();
      watch.close();
    },
  );
}
