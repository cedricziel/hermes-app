import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';
import 'package:hermes_app/src/chat/subagents/subagent_roster.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_gateway.dart';
import '../../support/fake_hermes_server.dart';
import 'process_fixtures.dart';

/// The agent roster and the background-program roster of a chat through the
/// real gateway transport: what sign-out, a profile switch and the retirement
/// of the session clear, and that an answer arriving after the clear changes
/// nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late FakeHermesServer server;

  const lateAgent = {
    'subagents': [
      {'subagent_id': 'sa-late', 'goal': 'Late goal', 'status': 'running'},
    ],
    'delegations': [],
  };

  ChatController chatOver(
    ChatTransport over, {
    ValueListenable<bool>? activity,
  }) => ChatController(
    repository: HermesChatRepository(server.client().raw),
    transport: over,
    activity: activity,
    attention: attention,
    report: (_) {},
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['session.resume'] = (params) => {
      'session_id': params['profile'] == 'other' ? 'rt-2' : 'rt-1',
      'stored_session_id': 'stored-1',
      'session_key': 'stored-1',
    };
    gateway.handlers['subagent.list'] = (_) => {
      'subagents': [],
      'delegations': [],
    };
    gateway.handlers['process.list'] = (_) => {'processes': []};
    transport = HermesGatewayTransport(connect: gateway.connect);
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'Agents')]),
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
    chat = chatOver(transport);
  });

  tearDown(() async {
    chat.dispose();
    attention.dispose();
    await transport.close();
  });

  Future<void> open(ChatController controller) async {
    await controller.loadThreads('work');
    controller.select('stored-1');
    await pumpEventQueue();
  }

  /// A chat with one agent from a frame and one program card, watched so
  /// that both lists are being read.
  Future<({SubagentRoster roster, RosterWatch watch})> populated(
    ChatController controller,
  ) async {
    await open(controller);
    final thread = controller.selectedThread!;
    gateway.event('subagent.start', 'rt-1', {
      'subagent_id': 'sa-1',
      'goal': 'Audit',
    });
    gateway.event('agent.terminal.output', 'rt-1', {
      'process_id': 'proc_ab12',
      'chunk': 'from frames',
    });
    await pumpEventQueue();
    final roster = controller.subagentsIn(thread)!;
    expect(roster.row('sa-1'), isNotNull);
    expect(controller.processOutputsIn(thread)!.cards, hasLength(1));
    return (roster: roster, watch: roster.watch());
  }

  /// Leaves the next list reads unanswered; returns the requests they make.
  Future<List<Map<String, Object?>>> holdReads(SubagentRoster roster) async {
    gateway.silent.addAll({'subagent.list', 'process.list'});
    final before = gateway.requests.length;
    roster.markAttached();
    await pumpEventQueue();
    final held = [
      for (final request in gateway.requests.skip(before))
        if (request['method'] == 'subagent.list' ||
            request['method'] == 'process.list')
          request,
    ];
    expect(held.map((request) => request['method']).toSet(), {
      'subagent.list',
      'process.list',
    }, reason: 'both reads are out before the clear');
    return held;
  }

  void answerLate(List<Map<String, Object?>> held) {
    for (final request in held) {
      switch (request['method']) {
        case 'subagent.list':
          gateway.replyTo(request, lateAgent);
        case 'process.list':
          gateway.replyTo(request, processListAnswer);
      }
    }
  }

  group('profile switch', () {
    test('clears both rosters and drops answers that arrive after', () async {
      final (:roster, :watch) = await populated(chat);
      final oldCards = chat.processOutputsIn(chat.selectedThread!)!;
      final held = await holdReads(roster);
      await chat.loadThreads('other');
      expect(roster.hasAgents, isFalse);
      expect(oldCards.cards, isEmpty);
      answerLate(held);
      await pumpEventQueue();
      expect(roster.row('sa-late'), isNull);
      expect(roster.hasAgents, isFalse);
      expect(oldCards.cards, isEmpty);
      chat.select('stored-1');
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      final fresh = chat.subagentsIn(thread)!;
      expect(identical(fresh, roster), isFalse);
      expect(fresh.row('sa-late'), isNull);
      expect(fresh.row('sa-1'), isNull);
      expect(chat.processOutputsIn(thread)?.cards ?? [], isEmpty);
      watch.close();
    });
  });

  group('sign-out', () {
    test('disposing the controller clears both rosters and a late answer '
        'changes nothing', () async {
      final (:roster, :watch) = await populated(chat);
      final cards = chat.processOutputsIn(chat.selectedThread!)!;
      final held = await holdReads(roster);
      chat.dispose();
      expect(roster.hasAgents, isFalse);
      expect(cards.cards, isEmpty);
      answerLate(held);
      await pumpEventQueue();
      expect(roster.hasAgents, isFalse);
      expect(cards.cards, isEmpty);
      watch.close();
      chat = chatOver(transport);
    });

    test('the activity gate closing clears both rosters and drops late '
        'answers', () async {
      chat.dispose();
      final activity = ValueNotifier(true);
      addTearDown(activity.dispose);
      final guarded = SessionChatTransport(() => transport);
      chat = chatOver(guarded, activity: activity);
      final (:roster, :watch) = await populated(chat);
      final thread = chat.selectedThread!;
      final cards = chat.processOutputsIn(thread)!;
      final held = await holdReads(roster);
      activity.value = false;
      await guarded.suspend();
      expect(roster.hasAgents, isFalse);
      expect(cards.cards, isEmpty);
      expect(chat.subagentsIn(thread), isNull);
      answerLate(held);
      await pumpEventQueue();
      expect(roster.hasAgents, isFalse);
      expect(cards.cards, isEmpty);
      watch.close();
    });
  });

  group('retirement', () {
    test(
      'a reclaimed session clears both rosters and drops late answers',
      () async {
        final (:roster, :watch) = await populated(chat);
        final cards = chat.processOutputsIn(chat.selectedThread!)!;
        final held = await holdReads(roster);
        gateway.event('session.reclaimed', '', {
          'session_id': 'rt-1',
          'stored_session_id': 'stored-1',
          'reason': 'Another client',
        });
        await pumpEventQueue();
        expect(cards.cards, isEmpty, reason: 'program cards released');
        expect(roster.hasAgents, isFalse, reason: 'agent rows released');
        answerLate(held);
        await pumpEventQueue();
        expect(roster.row('sa-late'), isNull);
        expect(roster.hasAgents, isFalse);
        expect(cards.cards, isEmpty);
        final fresh = chat.subagentsIn(chat.selectedThread!);
        expect(fresh?.row('sa-late'), isNull);
        expect(fresh?.row('sa-1'), isNull);
        watch.close();
      },
    );
  });

  group('owned sessions stream', () {
    test('closing it clears both rosters', () async {
      final (:roster, :watch) = await populated(chat);
      final cards = chat.processOutputsIn(chat.selectedThread!)!;
      await transport.close();
      await pumpEventQueue();
      expect(roster.hasAgents, isFalse);
      expect(cards.cards, isEmpty);
      watch.close();
    });
  });
}
