import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';
import 'package:hermes_app/src/chat/session_usage/session_usage_card.dart';
import 'package:hermes_app/src/chat/session_usage/session_usage_controller.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_gateway.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late FakeHermesServer server;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['session.resume'] = (params) => {
      'session_id': params['profile'] == 'other' ? 'rt-2' : 'rt-1',
      'stored_session_id': 'stored-1',
      'session_key': 'stored-1',
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'Usage test')]),
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

  test('live session snapshots and final usage update without settling an active turn', () async {
    await chat.loadThreads('work');
    chat.select('stored-1');
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    chat.submit('Test usage', const []);
    await pumpEventQueue();
    gateway.event('session.usage', 'foreign-runtime', {
      'usage': {'total': 999},
    });
    gateway.event('session.usage', 'rt-1', {
      'usage': {'total': 8, 'cost_usd': 0.2},
    });
    gateway.event('session.usage', 'rt-1', {
      'usage': {'total': 8, 'cost_usd': 0.2},
    });
    await pumpEventQueue();
    expect(chat.usageIn(thread)!.snapshot!.total, 8);
    expect(thread.isReplying, isTrue);
    gateway.event('message.complete', 'rt-1', {
      'text': 'Done',
      'status': 'complete',
      'usage': {'total': 9},
    });
    await pumpEventQueue();
    expect(chat.usageIn(thread)!.snapshot!.total, 9);
    expect(chat.usageIn(thread)!.source, UsageSource.completion);
    expect(thread.isReplying, isFalse);
  });

  test(
    'profile replacement rejects a late usage fetch and old ticks',
    () async {
      gateway.silent.add('session.usage');
      await chat.loadThreads('work');
      chat.select('stored-1');
      await pumpEventQueue();
      final oldThread = chat.selectedThread!;
      final oldUsage = chat.usageIn(oldThread)!;
      final fetching = oldUsage.refresh();
      await pumpEventQueue();
      await chat.loadThreads('other');
      chat.select('stored-1');
      await pumpEventQueue();
      gateway.replyTo(
        gateway.requests.firstWhere(
          (request) => request['method'] == 'session.usage',
        ),
        {'total': 99},
      );
      await fetching;
      gateway.event('session.usage', 'rt-1', {
        'usage': {'total': 88},
      });
      await pumpEventQueue();
      expect(oldUsage.bound, isFalse);
      expect(chat.usageIn(chat.selectedThread!)?.snapshot?.total, isNot(99));
      expect(
        gateway.requests
            .where((r) => r['method'] == 'session.usage')
            .first['params'],
        {'session_id': 'rt-1', 'profile': 'work'},
      );
    },
  );

  test(
    'same-runtime send takeover preserves usage scope and known values',
    () async {
      await chat.loadThreads('work');
      chat.select('stored-1');
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      gateway.event('session.usage', 'rt-1', {
        'usage': {'total': 8},
      });
      await pumpEventQueue();
      final existing = chat.usageIn(thread)!;
      chat.submit('Continue same session', const []);
      await pumpEventQueue();
      expect(chat.usageIn(thread), same(existing));
      expect(existing.snapshot!.total, 8);
      gateway.event('message.complete', 'rt-1', {
        'text': 'Done',
        'status': 'complete',
      });
      await pumpEventQueue();
      expect(existing.snapshot!.total, 8);
    },
  );

  test(
    'protected activity suspension clears usage and rejects an awaited result',
    () async {
      chat.dispose();
      final activity = ValueNotifier(true);
      addTearDown(activity.dispose);
      final guarded = SessionChatTransport(() => transport);
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: guarded,
        activity: activity,
        attention: attention,
        report: (_) {},
      );
      gateway.silent.add('session.usage');
      await chat.loadThreads('work');
      chat.select('stored-1');
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      final usage = chat.usageIn(thread)!;
      final fetching = usage.refresh();
      await pumpEventQueue();
      activity.value = false;
      await guarded.suspend();
      gateway.replyTo(
        gateway.requests.firstWhere(
          (request) => request['method'] == 'session.usage',
        ),
        {'total': 100},
      );
      await fetching;
      expect(chat.usageIn(thread), isNull);
      expect(usage.bound, isFalse);
    },
  );

  testWidgets(
    'the owned disclosure starts one optional read only after opening',
    (tester) async {
      gateway.handlers['session.usage'] = (_) => {
        'model': 'reported',
        'total': 11,
        'cost_usd': 0.2,
      };
      await tester.runAsync(() async {
        await chat.loadThreads('work');
        chat.select('stored-1');
        await pumpEventQueue();
      });
      final usage = chat.usageIn(chat.selectedThread!)!;
      expect(gateway.methods, isNot(contains('session.usage')));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SessionUsageCard(controller: usage)),
        ),
      );
      await tester.tap(find.byType(ExpansionTile));
      await tester.runAsync(() async => pumpEventQueue());
      await tester.pumpAndSettle();
      expect(find.textContaining('11 tokens'), findsOneWidget);
      expect(find.text('Cost (USD): 0.2'), findsOneWidget);
      expect(
        gateway.methods.where((method) => method == 'session.usage'),
        hasLength(1),
      );
    },
  );
  test(
    'an unsupported usage read remains optional across another prompt',
    () async {
      gateway.handlers['session.usage'] = (_) =>
          throw const FakeRpcError(-32601);
      await chat.loadThreads('work');
      chat.select('stored-1');
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      final usage = chat.usageIn(thread)!;
      await usage.opened();
      expect(usage.freshness, UsageFreshness.unsupported);
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Done',
        'status': 'complete',
      });
      chat.submit('Still usable', const []);
      await pumpEventQueue();
      await usage.opened();
      expect(thread.messages.last.content, 'Done');
      expect(thread.isReplying, isFalse);
      expect(
        gateway.methods.where((method) => method == 'session.usage'),
        hasLength(1),
      );
    },
  );
}
