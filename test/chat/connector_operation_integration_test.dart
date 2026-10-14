import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_app/src/chat/connector_operation_state.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_state.dart';
import 'package:hermes_app/src/chat/side_results/side_result_state.dart';
import 'package:hermes_app/src/chat/session_usage/usage_snapshot.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/connector_operation_card.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/chat_with_activity.dart';
import '../support/fake_gateway.dart';
import '../support/fake_attachment_source.dart';
import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import '../support/fake_chat_transport.dart';
import 'connector_fixtures.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late FakeHermesServer server;
  late DateTime now;
  late _ReenteringTracer tracer;
  final opened = <Uri>[];
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    opened.clear();
    now = DateTime.utc(2030);
    tracer = _ReenteringTracer();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['connection.respond'] = (_) => {
      'status': 'ok',
      'settled': false,
    };
    gateway.handlers['session.resume'] = (params) => {
      'session_id': params['profile'] == 'other' ? 'rt-2' : 'rt-1',
      'stored_session_id': 'stored-1',
      'session_key': 'stored-1',
    };
    transport = HermesGatewayTransport(
      connect: gateway.connect,
      telemetry: gatewayTracer(tracer),
    );
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'stored-1', title: 'Connector operation test'),
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
      now: () => now,
      connectorBrowser: (uri) async {
        opened.add(uri);
        return true;
      },
    );
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    await transport.close();
  });

  Future<void> open([String? profile = 'work']) async {
    await chat.loadThreads(profile);
    chat.select('stored-1');
    await pumpEventQueue();
  }

  void request({String runtime = 'rt-1', int seq = 1}) => gateway.event(
    'connection.request',
    runtime,
    {...connectionRequestFixture, 'seq': seq},
  );
  void update({String runtime = 'rt-1', int seq = 4, bool settled = false}) =>
      gateway.event('connection.update', runtime, {
        ...connectionUpdateFixture,
        'seq': seq,
        'settled': settled,
        'owner': {'type': 'session', 'session_id': runtime},
      });

  for (final replacement in ['snapshot', 'metadata', 'deadline', 'responder']) {
    test(
      'same-binding $replacement change during request instrumentation prevents mutation bytes',
      () async {
        await open();
        final thread = chat.selectedThread!;
        if (replacement == 'metadata') {
          update();
        } else {
          request();
        }
        await pumpEventQueue();
        final controller = chat.connectorOperationsIn(thread)!;
        final operation = controller.operations.single;
        final binding = transport.ownedSessionFor(thread.id, profile: 'work')!;
        tracer.beforeResponse = () {
          if (replacement == 'snapshot') {
            controller.accept(
              ConnectorOperationSnapshot.fromUpdate({
                ...connectionUpdateFixture,
                'owner': {'type': 'session', 'session_id': binding.runtimeId},
                'seq': operation.seq + 1,
                'targets': [
                  {
                    'name': 'synthetic-connector',
                    'kind': 'connector',
                    'action': 'authorize',
                    'state': 'connected',
                    'resolved': true,
                  },
                ],
              })!,
              attachment: binding,
            );
          } else if (replacement == 'metadata') {
            controller.accept(
              ConnectorOperationSnapshot.fromRequest(
                connectionRequestFixture,
                runtimeId: binding.runtimeId,
              )!,
              attachment: binding,
            );
          } else if (replacement == 'deadline') {
            now = operation.deadlineAt;
          } else {
            controller.bind(binding, profile: 'work');
          }
        };
        await controller.skip(
          operation,
          'synthetic-connector',
          attachment: binding,
        );
        expect(tracer.invoked, isTrue);
        expect(gateway.methods, isNot(contains('connection.respond')));
        expect(controller.errorFor(operation.key), isNull);
        expect(transport.ownedSessionFor(thread.id, profile: 'work'), binding);
      },
    );
  }
  test('a response admitted before expiry still accepts authoritative late settlement', () async {
    await open();
    final thread = chat.selectedThread!;
    request();
    await pumpEventQueue();
    final controller = chat.connectorOperationsIn(thread)!;
    final operation = controller.operations.single;
    final binding = transport.ownedSessionFor(thread.id, profile: 'work')!;
    gateway.silent.add('connection.respond');
    final pending = controller.skip(
      operation,
      'synthetic-connector',
      attachment: binding,
    );
    await pumpEventQueue();
    expect(gateway.methods, contains('connection.respond'));
    now = operation.deadlineAt;
    gateway.replyTo(gateway.requestOf('connection.respond'), {
      'status': 'ok',
      'settled': true,
    });
    await pending;
    expect(controller.operations.single.settled, isTrue);
    expect(controller.errorFor(operation.key), isNull);
  });
  test('actual session requests offer scoped responses without settling the main turn', () async {
    await open();
    final thread = chat.selectedThread!;
    chat.submit('Foreground', const []);
    await pumpEventQueue();
    request();
    update();
    await pumpEventQueue();
    final module = chat.connectorOperationsIn(thread);
    expect(
      module?.operations.map((operation) => operation.seq).toList() ?? [],
      [4],
    );
    final operation = module!.operations.single;
    final binding = transport.ownedSessionFor(thread.id, profile: 'work')!;
    expect(module.canRespond(operation.key), isTrue);
    await module.skip(operation, 'synthetic-connector', attachment: binding);
    expect(gateway.requestOf('connection.respond')['params'], {
      'owner': {'type': 'session', 'session_id': 'rt-1'},
      'op_id': 'synthetic-operation',
      'profile': 'work',
      'result': {
        'targets': [
          {'name': 'synthetic-connector', 'status': 'skipped'},
        ],
      },
    });
    expect(module.operations.single.targets.single.state, 'initiated');
    expect(thread.isReplying, isTrue);
    expect(thread.messages.last.content, isEmpty);
    gateway.event('message.complete', 'rt-1', {
      'text': 'Main answer',
      'status': 'complete',
    });
    await pumpEventQueue();
    expect(thread.messages.last.content, 'Main answer');
  });

  test('update-before-request preserves sequence and browser return has no invented connection success', () async {
    await open();
    final thread = chat.selectedThread!;
    update();
    request();
    await pumpEventQueue();
    final module = chat.connectorOperationsIn(thread)!;
    final operation = module.operations.single;
    final binding = transport.ownedSessionFor(thread.id, profile: 'work')!;
    expect(operation.seq, 4);
    await module.openTarget(
      operation,
      'synthetic-connector',
      attachment: binding,
    );
    expect(opened.single.host, 'connect.invalid');
    expect(module.operations.single.targets.single.state, 'initiated');
    expect(module.operations.single.settled, isFalse);
    expect(thread.isReplying, isFalse);
    expect(gateway.methods, isNot(contains('connection.respond')));
  });

  test('missing profile authority keeps an owned runtime read-only without URL or response', () async {
    await open(null);
    final thread = chat.selectedThread!;
    request();
    await pumpEventQueue();
    final module = chat.connectorOperationsIn(thread)!;
    final operation = module.operations.single;
    final binding = transport.ownedSessionFor(thread.id)!;
    expect(module.canRespond(operation.key), isFalse);
    expect(operation.targets.single.connectUrl, isNull);
    await module.openTarget(
      operation,
      'synthetic-connector',
      attachment: binding,
    );
    await module.continueOperation(operation, attachment: binding);
    expect(opened, isEmpty);
    expect(gateway.methods, isNot(contains('connection.respond')));
  });

  test('global account broadcasts stay read-only connection activity outside conversation ownership', () async {
    await open();
    final thread = chat.selectedThread!;
    gateway.event('connection.update', '', {
      ...connectionUpdateFixture,
      'owner': {'type': 'account'},
    });
    await pumpEventQueue();
    final module = chat.connectionOperations;
    expect(
      module?.operations.map((operation) => operation.owner.type).toList() ??
          [],
      ['account'],
    );
    final operation = module!.operations.single;
    expect(operation.targets.single.connectUrl, isNull);
    expect(module.canRespond(operation.key), isFalse);
    expect(module.canOpen(operation.key, 'synthetic-connector'), isFalse);
    expect(chat.connectorOperationsIn(thread)?.operations ?? [], isEmpty);
    expect(thread.isReplying, isFalse);
    expect(opened, isEmpty);
    expect(gateway.methods, isNot(contains('connection.respond')));
    gateway.drop();
    await pumpEventQueue();
    expect(module.operations, isEmpty);
    expect(chat.connectionOperations, isNull);
  });

  test(
    'profile replacement drops old card callbacks and late RPC outcomes',
    () async {
      gateway.silent.add('connection.respond');
      await open();
      final thread = chat.selectedThread!;
      request();
      await pumpEventQueue();
      final old = chat.connectorOperationsIn(thread)!;
      final operation = old.operations.single;
      final binding = transport.ownedSessionFor(thread.id, profile: 'work')!;
      final answering = old.continueOperation(operation, attachment: binding);
      await pumpEventQueue();
      await open('other');
      request(runtime: 'rt-2');
      await pumpEventQueue();
      gateway.replyTo(gateway.requestOf('connection.respond'), {
        'status': 'ok',
        'settled': true,
      });
      await answering;
      await old.skip(operation, 'synthetic-connector', attachment: binding);
      expect(old.operations, isEmpty);
      expect(
        chat
            .connectorOperationsIn(chat.selectedThread!)!
            .operations
            .single
            .settled,
        isFalse,
      );
      expect(
        gateway.methods.where((method) => method == 'connection.respond'),
        hasLength(1),
      );
    },
  );

  test('activity retirement during pending notification prevents actual RPC dispatch', () async {
    chat.dispose();
    final activity = ValueNotifier(true);
    addTearDown(activity.dispose);
    final guarded = SessionChatTransport(() => transport);
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: guarded,
      attention: attention,
      activity: activity,
      report: (_) {},
      now: () => now,
      connectorBrowser: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    await open();
    final thread = chat.selectedThread!;
    request();
    await pumpEventQueue();
    final module = chat.connectorOperationsIn(thread)!;
    final operation = module.operations.single;
    final binding = guarded.ownedSessionFor(thread.id, profile: 'work')!;
    var retired = false;
    chat.addListener(() {
      if (!retired && module.pendingFor(operation.key)) {
        retired = true;
        activity.value = false;
      }
    });
    await module.continueOperation(operation, attachment: binding);
    expect(retired, isTrue);
    expect(gateway.methods, isNot(contains('connection.respond')));
    expect(module.operations, isEmpty);
    expect(chat.connectorOperationsIn(thread), isNull);
  });

  test('reclaim retires operation actions and newer foreign frames cannot restore authority', () async {
    await open();
    final thread = chat.selectedThread!;
    request();
    await pumpEventQueue();
    final module = chat.connectorOperationsIn(thread)!;
    gateway.event('session.reclaimed', '', {
      'session_id': 'rt-1',
      'stored_session_id': 'stored-1',
      'reason': 'Another client',
    });
    await pumpEventQueue();
    update(seq: 10);
    await pumpEventQueue();
    expect(module.operations, isEmpty);
    expect(chat.connectorOperationsIn(thread), isNull);
    expect(gateway.methods, isNot(contains('connection.respond')));
  });

  test(
    'reached deadlines disable real actions without inventing settlement',
    () async {
      chat.dispose();
      var now = DateTime.utc(2030);
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        attention: attention,
        report: (_) {},
        now: () => now,
        connectorBrowser: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await open();
      final thread = chat.selectedThread!;
      request();
      await pumpEventQueue();
      final module = chat.connectorOperationsIn(thread)!;
      final operation = module.operations.single;
      final binding = transport.ownedSessionFor(thread.id, profile: 'work')!;
      now = now.add(const Duration(minutes: 2));
      expect(module.awaitingFinalStatus(operation.key), isTrue);
      await module.openTarget(
        operation,
        'synthetic-connector',
        attachment: binding,
      );
      await module.continueOperation(operation, attachment: binding);
      expect(module.operations.single.settled, isFalse);
      expect(module.operations.single.settledBy, isNull);
      expect(opened, isEmpty);
      expect(gateway.methods, isNot(contains('connection.respond')));
    },
  );

  test('physical socket replacement clears old operation callbacks before runtime reuse', () async {
    await open();
    final thread = chat.selectedThread!;
    request();
    await pumpEventQueue();
    final old = chat.connectorOperationsIn(thread)!;
    final operation = old.operations.single;
    final binding = transport.ownedSessionFor(thread.id, profile: 'work')!;
    gateway.drop();
    await pumpEventQueue();
    expect(old.operations, isEmpty);
    expect(chat.connectorOperationsIn(thread), isNull);
    chat.submit('Reconnect through normal send', const []);
    await pumpEventQueue();
    request();
    await pumpEventQueue();
    final current = chat.connectorOperationsIn(thread)!;
    expect(
      transport.ownedSessionFor(thread.id, profile: 'work')!.connection,
      isNot(same(binding.connection)),
    );
    await old.skip(operation, 'synthetic-connector', attachment: binding);
    expect(current.operations.single.settled, isFalse);
    expect(gateway.methods, isNot(contains('connection.respond')));
    gateway.event('message.complete', 'rt-1', {
      'text': 'Main',
      'status': 'complete',
    });
    await pumpEventQueue();
  });

  test('connector restoration notifications cannot expose previous Todo Side Process or usage ownership', () async {
    chat.dispose();
    final owned = _OwnedSource();
    addTearDown(owned.close);
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: owned,
      attention: attention,
      report: (_) {},
      now: () => now,
    );
    await open();
    final thread = chat.selectedThread!;
    final binding = owned.binding;
    final stream = owned.followUpStreams['stored-1']!;
    stream.emit(
      SessionUsageUpdated(
        const UsageSnapshot(total: 7),
        runtimeId: binding.runtimeId,
        connection: binding.connection,
      ),
    );
    stream.emit(
      SideResultReceived(
        const SideResult(
          kind: SideResultKind.background,
          taskId: 'old',
          text: 'Old side',
        ),
        runtimeId: binding.runtimeId,
        connection: binding.connection,
      ),
    );
    stream.emit(
      ProcessOutputReceived(
        const ProcessOutputUpdate('old-process', chunk: 'Old process'),
        runtimeId: binding.runtimeId,
        connection: binding.connection,
      ),
    );
    stream.emit(
      TodoUpdated(
        const TodoSnapshot(6, [
          TodoEntry(id: 'old', content: 'Old todo', status: TodoStatus.pending),
        ]),
        runtimeId: binding.runtimeId,
        connection: binding.connection,
      ),
    );
    stream.emit(
      ConnectorOperationReceived(
        ConnectorOperationSnapshot.fromRequest(
          connectionRequestFixture,
          runtimeId: binding.runtimeId,
        )!,
        runtimeId: binding.runtimeId,
        connection: binding.connection,
      ),
    );
    await pumpEventQueue();
    expect(chat.usageIn(thread)!.snapshot!.total, 7);
    expect(
      chat.todoPlanIn(thread)!.snapshot!.entries.single!.content,
      'Old todo',
    );
    expect(chat.sideResultsIn(thread)!.results.single.text, 'Old side');
    expect(chat.processOutputsIn(thread)!.cards.single.text, 'Old process');
    final next = OwnedSessionBinding(
      connection: Object(),
      runtimeId: 'next-runtime',
      profile: 'work',
    );
    var restorationObserved = false;
    final observed = <String>[];
    chat.addListener(() {
      if (owned.binding != next) return;
      restorationObserved =
          restorationObserved ||
          (chat
                  .connectorOperationsIn(thread)
                  ?.operations
                  .any((operation) => operation.opId == 'next-operation') ??
              false);
      final total = chat.usageIn(thread)?.snapshot?.total;
      if (total != null) observed.add('usage:$total');
      observed.addAll(
        chat
                .todoPlanIn(thread)
                ?.snapshot
                ?.entries
                .map((entry) => entry?.content ?? '') ??
            const [],
      );
      observed.addAll(
        chat.sideResultsIn(thread)?.results.map((card) => card.text) ??
            const [],
      );
      observed.addAll(
        chat.processOutputsIn(thread)?.cards.map((card) => card.text) ??
            const [],
      );
    });
    owned.replace(
      next,
      ConnectorOperationSnapshot.fromRequest({
        ...connectionRequestFixture,
        'op_id': 'next-operation',
      }, runtimeId: next.runtimeId)!,
    );
    await pumpEventQueue();
    expect(restorationObserved, isTrue);
    expect(observed, isNot(contains('usage:7')));
    expect(observed, isNot(contains('Old todo')));
    expect(observed, isNot(contains('Old side')));
    expect(observed, isNot(contains('Old process')));
  });
  testWidgets('the actionable connector card stays usable in a short chat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await open();
      gateway.event('connection.request', 'rt-1', {
        ...connectionRequestFixture,
        'targets': [
          {
            'name': 'synthetic-connector',
            'kind': 'connector',
            'action': 'authorize',
            'state': 'initiated',
            'instructions': List.filled(
              200,
              'Synthetic instructions',
            ).join('\n'),
          },
        ],
      });
      gateway.event('connection.update', '', {
        ...connectionUpdateFixture,
        'owner': {'type': 'account'},
      });
      gateway.event('session.usage', 'rt-1', {
        'usage': {'total': 7},
      });
      gateway.event('todo.updated', 'rt-1', {
        'revision': 1,
        'todos': [
          {'id': 'task', 'content': 'Current todo', 'status': 'pending'},
        ],
      });
      gateway.event('background.complete', 'rt-1', {
        'task_id': 'side',
        'text': 'Current side',
      });
      await pumpEventQueue();
    });
    final composer = TextEditingController(),
        focus = FocusNode(),
        latest = LatestReply();
    addTearDown(composer.dispose);
    addTearDown(focus.dispose);
    addTearDown(latest.dispose);
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
    // The account-wide operation is reference activity, in the panel.
    expect(find.byType(ConnectorOperationCard), findsOneWidget);
    final scoped = find.byType(ConnectorOperationCard);
    final disclosure = find.descendant(
      of: scoped,
      matching: find.byType(ExpansionTile),
    );
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await tester.pumpAndSettle();
    final continueAction = find.text('Continue');
    await tester.ensureVisible(continueAction);
    await tester.pumpAndSettle();
    expect(continueAction.hitTestable(), findsOneWidget);
    expect(tester.getSize(find.byType(Chat)).height, greaterThan(150));
    expect(tester.takeException(), isNull);
    expect(gateway.methods, isNot(contains('connection.respond')));
  });
  testWidgets(
    'real chat labels account connection activity and renders no authority-guessing controls',
    (tester) async {
      await tester.runAsync(() async {
        await open();
        gateway.event('connection.update', '', {
          ...connectionUpdateFixture,
          'owner': {'type': 'account'},
        });
        await pumpEventQueue();
      });
      final composer = TextEditingController();
      final focus = FocusNode();
      final latest = LatestReply();
      addTearDown(composer.dispose);
      addTearDown(focus.dispose);
      addTearDown(latest.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: chatWithActivity(
              chat,
              boundChatThreadView(
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
        ),
      );
      expect(find.text('Connection activity'), findsOneWidget);
      expect(find.byType(ConnectorOperationCard), findsOneWidget);
      await tester.tap(find.byType(ConnectorOperationCard));
      await tester.pumpAndSettle();
      expect(find.text('Read-only operation.'), findsOneWidget);
      expect(find.textContaining('connect.invalid'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Open connection'), findsNothing);
    },
  );
}

class _ReenteringTracer extends RecordingTracer {
  void Function()? beforeResponse;
  bool invoked = false;
  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    SpanContext? parentContext,
    List<SpanLink> links = const [],
  }) {
    if (name == 'connection.respond send' && beforeResponse != null) {
      invoked = true;
      beforeResponse!();
    }
    return super.startSpan(
      name,
      kind: kind,
      attributes: attributes,
      parentContext: parentContext,
      links: links,
    );
  }
}

class _OwnedSource extends FakeChatTransport implements OwnedSessionTransport {
  OwnedSessionBinding binding = OwnedSessionBinding(
    connection: Object(),
    runtimeId: 'same-runtime',
    profile: 'work',
  );
  final changes = StreamController<OwnedSessionChange>.broadcast(sync: true);
  @override
  Stream<OwnedSessionChange> get ownedSessions => changes.stream;
  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      threadId == 'stored-1' && profile == binding.profile ? binding : null;
  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async => {'total': 0};
  void replace(OwnedSessionBinding next, ConnectorOperationSnapshot pending) {
    binding = next;
    changes.add(
      OwnedSessionChange(
        'stored-1',
        next,
        resumeSnapshot: {'pending_connection': pending},
      ),
    );
  }

  @override
  Future<void> close() async {
    await changes.close();
    await super.close();
  }
}
