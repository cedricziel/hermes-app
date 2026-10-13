import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late List<Map<String, Object>> events;
  late bool telemetryFails;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    gateway = FakeGateway()
      ..stampSeq = true
      ..resumeResult = {'session_id': 'rt-1', 'session_key': 'stored-1'};
    transport = HermesGatewayTransport(
      connect: gateway.connect,
      sleep: (_) async {},
    );
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    events = [];
    telemetryFails = false;
    chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
      events: (name, [attributes = const {}]) {
        if (telemetryFails) throw StateError('Synthetic telemetry failure');
        if (name == 'gateway.visibility_outcome' &&
            attributes['feature'] == 'moa') {
          events.add(Map.of(attributes));
        }
      },
    );
    chat.newThread();
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    await transport.close();
  });
  Future<void> begin(void Function(FakeGateway, String) turn) async {
    final delivered = Completer<void>();
    gateway.turn = (server, session) {
      turn(server, session);
      delivered.complete();
    };
    chat.submit('Synthetic prompt', const []);
    await delivered.future.timeout(const Duration(seconds: 5));
    await pumpEventQueue();
  }

  test('actual foreground progress stays reference material and settles with main reply', () async {
    await begin((server, session) {
      server.event('message.start', session);
      server.event('moa.progress', session, {
        'label': 'Advisor',
        'refs_done': 1,
        'refs_total': 2,
      });
      server.event('moa.reference', session, {
        'label': 'Advisor',
        'text': 'Private reference',
        'index': 0,
      });
    });
    final thread = chat.selectedThread!;
    final card = chat.moaIn(thread).single;
    expect(card.live, true);
    expect(card.done, 1);
    expect(card.references.single.text, 'Private reference');
    expect(thread.messages.last.content, isNot(contains('Private reference')));
    final runtime = transport
        .ownedSessionFor(thread.id, profile: chat.profile)!
        .runtimeId;
    gateway.event('message.complete', runtime, {
      'text': 'Main answer',
      'status': 'complete',
    });
    await pumpEventQueue();
    expect(chat.moaIn(thread).single.live, false);
    expect(
      chat.moaIn(thread).single.references.single.text,
      'Private reference',
    );
    expect(thread.messages.last.content, 'Main answer');
    expect(
      events.every(
        (event) => event.keys.every({'feature', 'outcome', 'count'}.contains),
      ),
      true,
    );
    expect(events.toString(), isNot(contains('Private reference')));
  });
  test('late progress after settlement never reopens a card', () async {
    await begin((server, session) {
      server.event('message.start', session);
      server.event('moa.phase', session, {'phase': 'aggregator'});
      server.event('message.complete', session, {
        'text': 'Done',
        'status': 'complete',
      });
      server.event('moa.progress', session, {
        'label': 'Late',
        'refs_done': 1,
        'refs_total': 2,
      });
    });
    final cards = chat.moaIn(chat.selectedThread!);
    expect(cards, hasLength(1));
    expect(cards.single.live, false);
    expect(cards.single.phase, 'aggregator');
    expect(cards.single.done, isNull);
  });
  test(
    'progress after a turn with no advisor events cannot manufacture a card',
    () async {
      await begin((server, session) {
        server.event('message.start', session);
        server.event('message.complete', session, {
          'text': 'Done',
          'status': 'complete',
        });
        server.event('moa.aggregating', session, {
          'aggregator': 'Late aggregator',
        });
      });
      expect(chat.moaIn(chat.selectedThread!), isEmpty);
    },
  );
  test('malformed optional progress and failing telemetry preserve the main answer', () async {
    await begin((server, session) {
      server.event('message.start', session);
      server.event('moa.reference', session, {'label': 'Advisor', 'text': []});
      telemetryFails = true;
      server.event('moa.aggregating', session, {'aggregator': 'Reported'});
      server.event('message.complete', session, {
        'text': 'Main answer',
        'status': 'complete',
      });
    });
    final thread = chat.selectedThread!;
    expect(thread.messages.last.content, 'Main answer');
    expect(chat.moaDetailsOpened, returnsNormally);
    expect(chat.moaIn(thread).single.live, false);
    expect(chat.moaIn(thread).single.references, isEmpty);
  });
  test('real socket replacement uses existing recovery and marks missing references unavailable', () async {
    await begin((server, session) {
      server.event('message.start', session);
      server.event('moa.reference', session, {
        'label': 'Advisor',
        'text': 'Before disconnect',
      });
    });
    final thread = chat.selectedThread!;
    expect(chat.moaIn(thread).single.references, hasLength(1));
    final resumes = gateway.methods
        .where((method) => method == 'session.resume')
        .length;
    gateway.resumeResult = {
      'session_id': 'rt-1',
      'stored_session_id': 'stored-1',
      'running': true,
      'inflight': {'assistant': ''},
    };
    gateway.drop();
    await pumpEventQueue();
    expect(chat.moaIn(thread), isEmpty);
    expect(
      gateway.methods.where((method) => method == 'session.resume'),
      hasLength(resumes + 1),
    );
    gateway.event('moa.progress', 'rt-1', {
      'label': 'Advisor',
      'refs_done': 1,
      'refs_total': 2,
    });
    await pumpEventQueue();
    final cards = chat.moaIn(thread);
    expect(cards, hasLength(1));
    expect(cards.single.referencesAvailable, false);
    expect(cards.single.references, isEmpty);
    expect(
      gateway.methods.where((method) => method == 'session.resume'),
      hasLength(resumes + 1),
    );
    expect(
      gateway.methods.where((method) => method == 'prompt.submit'),
      hasLength(1),
    );
  });
  test('same advisor labels from later actual turns remain separate', () async {
    await begin((server, session) {
      server.event('message.start', session);
      server.event('moa.reference', session, {
        'label': 'Same',
        'text': 'First turn',
      });
      server.event('message.complete', session, {
        'text': 'Done',
        'status': 'complete',
      });
    });
    await begin((server, session) {
      server.event('message.start', session);
      server.event('moa.reference', session, {
        'label': 'Same',
        'text': 'Second turn',
      });
    });
    final cards = chat.moaIn(chat.selectedThread!);
    expect(cards.map((card) => card.references.single.text), [
      'First turn',
      'Second turn',
    ]);
    expect(cards.first.turn, isNot(same(cards.last.turn)));
    expect(cards.first.live, false);
    expect(cards.last.live, true);
  });
}
