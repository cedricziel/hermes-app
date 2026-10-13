import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_gateway.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_attachment_source.dart';
import '../support/fake_hermes_server.dart';

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
        sessionListBody([
          sessionRow(id: 'stored-1', title: 'Process output test'),
        ]),
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

  void output(String process, String chunk, {String runtime = 'rt-1'}) =>
      gateway.event('agent.terminal.output', runtime, {
        'process_id': process,
        'chunk': chunk,
      });

  test('process output during a main turn stays grouped without changing its prose or settlement', () async {
    await open();
    final thread = chat.selectedThread!;
    chat.submit('Foreground', const []);
    await pumpEventQueue();
    output('one', 'first');
    output('two', 'other');
    output('one', ' second');
    output('one', 'foreign', runtime: 'foreign');
    gateway.event('terminal.close', 'rt-1', {'process_id': 'one'});
    await pumpEventQueue();
    expect(
      chat.processOutputsIn(thread)?.cards.map((card) => card.text).toList() ??
          [],
      ['first second', 'other'],
    );
    expect(chat.processOutputsIn(thread)!.cards.first.closed, isTrue);
    expect(thread.isReplying, isTrue);
    expect(thread.messages.last.content, isEmpty);
    gateway.event('message.complete', 'rt-1', {
      'text': 'Main answer',
      'status': 'complete',
    });
    await pumpEventQueue();
    expect(thread.messages.last.content, 'Main answer');
    expect(thread.isReplying, isFalse);
  });

  test('close before idle output preserves Closed without opening or dispatching a main turn', () async {
    await open();
    final thread = chat.selectedThread!;
    final messages = thread.messages.length;
    final submits = gateway.methods
        .where((method) => method == 'prompt.submit')
        .length;
    gateway.event('terminal.close', 'rt-1', {'process_id': 'worker'});
    output('worker', 'late output');
    await pumpEventQueue();
    final state = chat.processOutputsIn(thread)!;
    expect(state.cards.single.closed, isTrue);
    expect(state.cards.single.text, 'late output');
    expect(thread.messages, hasLength(messages));
    expect(thread.isReplying, isFalse);
    expect(
      gateway.methods.where((method) => method == 'prompt.submit'),
      hasLength(submits),
    );
    chat.submit('Same owned runtime', const []);
    await pumpEventQueue();
    expect(chat.processOutputsIn(thread), same(state));
    expect(state.cards.single.text, 'late output');
    gateway.event('message.complete', 'rt-1', {
      'text': 'Main',
      'status': 'complete',
    });
    await pumpEventQueue();
  });

  test(
    'live process buffers obey UTF8 bounds and prefer closed-card eviction',
    () async {
      await open();
      final thread = chat.selectedThread!;
      output('long', '${'😀' * 18000}tail!');
      await pumpEventQueue();
      final state = chat.processOutputsIn(thread)!;
      expect(
        utf8.encode(state.cards.single.text).length,
        lessThanOrEqualTo(64 * 1024),
      );
      expect(state.cards.single.text, endsWith('tail!'));
      expect(state.cards.single.text, isNot(contains('\uFFFD')));
      expect(state.cards.single.omitted, isTrue);
      for (var index = 0; index < 15; index++) {
        output('$index', 'Output $index');
      }
      gateway.event('terminal.close', 'rt-1', {'process_id': '7'});
      output('next', 'New output');
      await pumpEventQueue();
      expect(state.cards, hasLength(16));
      expect(state.cards.any((card) => card.processId == '7'), isFalse);
      expect(state.cards.first.processId, 'long');
      expect(state.omittedCards, isTrue);
    },
  );

  test('profile replacement and reclaim release buffers and reject old runtime chunks', () async {
    await open();
    final oldThread = chat.selectedThread!;
    output('worker', 'Old profile');
    await pumpEventQueue();
    final old = chat.processOutputsIn(oldThread)!;
    await chat.loadThreads('other');
    chat.select('stored-1');
    await pumpEventQueue();
    output('worker', 'Late old');
    output('worker', 'Current profile', runtime: 'rt-2');
    await pumpEventQueue();
    final current = chat.selectedThread!;
    expect(old.cards, isEmpty);
    expect(
      chat.processOutputsIn(current)!.cards.single.text,
      'Current profile',
    );
    gateway.event('session.reclaimed', '', {
      'session_id': 'rt-2',
      'stored_session_id': 'stored-1',
      'reason': 'Another client',
    });
    await pumpEventQueue();
    expect(chat.processOutputsIn(current), isNull);
    output('worker', 'Late reclaimed', runtime: 'rt-2');
    await pumpEventQueue();
    expect(chat.processOutputsIn(current), isNull);
  });

  test('activity suspension releases process buffers', () async {
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
    await open();
    final thread = chat.selectedThread!;
    output('worker', 'Sensitive synthetic output');
    await pumpEventQueue();
    final state = chat.processOutputsIn(thread)!;
    activity.value = false;
    await guarded.suspend();
    output('worker', 'Late output');
    await pumpEventQueue();
    expect(state.cards, isEmpty);
    expect(chat.processOutputsIn(thread), isNull);
  });

  test('same-runtime chunks from an old physical client cannot enter current buffers', () async {
    chat.dispose();
    final owned = _OwnedTransport();
    addTearDown(owned.close);
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: owned,
      attention: attention,
      report: (_) {},
    );
    await open();
    final thread = chat.selectedThread!;
    final old = owned.binding!;
    final follow = owned.followUpStreams['stored-1']!;
    follow.emit(
      ProcessOutputReceived(
        const ProcessOutputUpdate('worker', chunk: 'Old'),
        runtimeId: old.runtimeId,
        connection: old.connection,
      ),
    );
    await pumpEventQueue();
    final oldState = chat.processOutputsIn(thread)!;
    owned.replace();
    await pumpEventQueue();
    expect(oldState.cards, isEmpty);
    final current = owned.binding!;
    follow.emit(
      ProcessOutputReceived(
        const ProcessOutputUpdate('worker', chunk: 'Current'),
        runtimeId: current.runtimeId,
        connection: current.connection,
      ),
    );
    follow.emit(
      ProcessOutputReceived(
        const ProcessOutputUpdate('worker', chunk: 'Stale queued chunk'),
        runtimeId: old.runtimeId,
        connection: old.connection,
      ),
    );
    await pumpEventQueue();
    expect(chat.processOutputsIn(thread)!.cards.single.text, 'Current');
    owned.lose();
    await pumpEventQueue();
    expect(chat.processOutputsIn(thread), isNull);
  });

  test(
    'replacement ownership retires old buffers before notifying listeners',
    () async {
      chat.dispose();
      final owned = _OwnedTransport();
      addTearDown(owned.close);
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: owned,
        attention: attention,
        report: (_) {},
      );
      await open();
      final thread = chat.selectedThread!;
      final binding = owned.binding!;
      owned.followUpStreams['stored-1']!.emit(
        ProcessOutputReceived(
          const ProcessOutputUpdate('worker', chunk: 'Old owner output'),
          runtimeId: binding.runtimeId,
          connection: binding.connection,
        ),
      );
      await pumpEventQueue();
      final observed = <String>[];
      chat.addListener(() {
        observed.addAll(
          chat.processOutputsIn(thread)?.cards.map((card) => card.text) ??
              const [],
        );
      });
      owned.replace();
      await pumpEventQueue();
      expect(observed, isNot(contains('Old owner output')));
    },
  );

  test(
    'binding notification retirement prevents process buffer application',
    () async {
      chat.dispose();
      final activity = ValueNotifier(true);
      final owned = _OwnedTransport();
      final applied = <Map<String, Object>>[];
      addTearDown(activity.dispose);
      addTearDown(owned.close);
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: owned,
        activity: activity,
        attention: attention,
        report: (_) {},
        events: (name, [attributes = const {}]) {
          applied.add(Map.of(attributes));
        },
      );
      await open();
      var retire = true;
      chat.addListener(() {
        if (!retire) return;
        retire = false;
        activity.value = false;
      });
      owned.binding = OwnedSessionBinding(
        connection: Object(),
        runtimeId: 'same-runtime',
        profile: 'work',
      );
      final binding = owned.binding!;
      owned.followUpStreams['stored-1']!.emit(
        ProcessOutputReceived(
          const ProcessOutputUpdate('worker', chunk: 'Retired output'),
          runtimeId: binding.runtimeId,
          connection: binding.connection,
        ),
      );
      await pumpEventQueue();
      expect(activity.value, isFalse);
      expect(applied, isEmpty);
    },
  );

  test(
    'process outcome telemetry stays coarse and cannot break output handling',
    () async {
      chat.dispose();
      final seen = <Map<String, Object>>[];
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        attention: attention,
        report: (_) {},
        events: (name, [attributes = const {}]) {
          if (attributes['feature'] == 'process_output') {
            seen.add(Map.of(attributes));
          }
          throw StateError('Telemetry unavailable');
        },
      );
      await open();
      output('private-process', 'Private output with https://example.invalid');
      await pumpEventQueue();
      expect(
        chat.processOutputsIn(chat.selectedThread!)!.cards.single.text,
        'Private output with https://example.invalid',
      );
      expect(seen, [
        {'feature': 'process_output', 'outcome': 'applied', 'count': 1},
      ]);
    },
  );

  testWidgets(
    'expanded long process output in chat keeps the transcript usable and footer visible',
    (tester) async {
      await tester.runAsync(() async {
        await open();
        output('long', List.filled(4000, 'Reported output line').join('\n'));
        for (var index = 0; index < 15; index++) {
          output('$index', 'Output $index');
        }
        gateway.event('terminal.close', 'rt-1', {'process_id': '7'});
        output('next', 'New output');
        await pumpEventQueue();
      });
      final composer = TextEditingController();
      final focus = FocusNode();
      final latest = LatestReply();
      addTearDown(composer.dispose);
      addTearDown(focus.dispose);
      addTearDown(latest.dispose);
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: boundChatThreadView(
              chat: chat,
              thread: chat.selectedThread,
              composerController: composer,
              composerFocus: focus,
              attachments: const [],
              attachmentSource: FakeAttachmentSource(),
              onAddAttachments: (_) {},
              onRemoveAttachment: (_) {},
              onSend: (_) {},
              latestReply: latest,
            ),
          ),
        ),
      );
      expect(find.byType(ProcessOutputCard), findsNWidgets(16));
      await tester.tap(find.textContaining('Process long'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Chat)).height, greaterThan(200));
      expect(
        tester.getSize(find.byType(ProcessOutputCard).first).height,
        lessThanOrEqualTo(320),
      );
      expect(find.text('Earlier output omitted.'), findsOneWidget);
      final footer = find.text('Earlier process cards omitted.');
      await tester.scrollUntilVisible(
        footer,
        180,
        scrollable: find
            .ancestor(of: footer, matching: find.byType(Scrollable))
            .first,
      );
      expect(footer.hitTestable(), findsOneWidget);
      expect(tester.getSize(find.byType(Chat)).height, greaterThan(200));
      expect(find.textContaining('Success'), findsNothing);
    },
  );
}

class _OwnedTransport extends FakeChatTransport
    implements OwnedSessionTransport {
  OwnedSessionBinding? binding = OwnedSessionBinding(
    connection: Object(),
    runtimeId: 'same-runtime',
    profile: 'work',
  );
  final _changes = StreamController<OwnedSessionChange>.broadcast(sync: true);
  @override
  Stream<OwnedSessionChange> get ownedSessions => _changes.stream;
  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      threadId == 'stored-1' && binding?.profile == profile ? binding : null;
  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async => throw const FakeRpcError(-32601);
  void replace() {
    binding = OwnedSessionBinding(
      connection: Object(),
      runtimeId: 'same-runtime',
      profile: 'work',
    );
    _changes.add(OwnedSessionChange('stored-1', binding!));
  }

  void lose() {
    final old = binding!;
    binding = null;
    _changes.add(OwnedSessionChange('stored-1', old, connected: false));
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await super.close();
  }
}
