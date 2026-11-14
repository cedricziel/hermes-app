import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/subagents/activity_selection.dart';
import 'package:hermes_app/src/chat/subagents/agent_models.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_note_field.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_row.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_attachment_source.dart';
import '../../support/fake_gateway.dart';
import '../../support/fake_hermes_server.dart';

const _audit =
    'Audit the dependency tree for packages with known vulnerabilities';
const _plan = 'Draft the upgrade plan for the flagged packages';

/// A widget test that, once its body is done, lets the panel's reads land, so
/// no request is left in flight.
void panelTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      await tester.pump();
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late _TestAppLock lock;
  late ValueNotifier<bool> activity;
  late ActivitySelection selection;
  late TextEditingController composer;
  late BreadcrumbTrail trail;
  late List<(String, Map<String, Object?>)> events;

  /// What `subagent.list` answers: the agents the server says run.
  late Map<String, Map<String, Object?>> listed;

  /// What `subagent.tail` answers, by agent.
  late Map<String, String> outputs;
  late ValueNotifier<bool> panelShown;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    lock = _TestAppLock();
    activity = ValueNotifier(true);
    selection = ActivitySelection();
    composer = TextEditingController();
    panelShown = ValueNotifier(true);
    trail = BreadcrumbTrail(capacity: 200);
    events = [];
    listed = {};
    outputs = {};
    gateway = FakeGateway();
    gateway.activeSessions = {};
    gateway.handlers['session.resume'] = (params) => {
      'session_id': params['session_id'] == 'stored-2' ? 'rt-2' : 'rt-1',
      'stored_session_id': params['session_id'],
      'session_key': params['session_id'],
    };
    gateway.handlers['subagent.list'] = (_) => {
      'subagents': listed.values.toList(),
      'delegations': <Object?>[],
    };
    gateway.handlers['subagent.tail'] = (params) => {
      'available': true,
      'text': outputs[params['subagent_id']] ?? '',
      'truncated': false,
    };
    gateway.handlers['subagent.interrupt'] = (_) => {'found': true};
    gateway.handlers['subagent.steer'] = (_) => {'status': 'queued'};
    transport = HermesGatewayTransport(connect: gateway.connect);
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'stored-1', title: 'First'),
          sessionRow(id: 'stored-2', title: 'Second'),
        ]),
      );
    for (final id in ['stored-1', 'stored-2']) {
      server.on('GET', '/api/sessions/$id/messages', messageListBody(id, []));
    }
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      activity: activity,
      appLock: lock,
      attention: attention,
      report: (_) {},
      breadcrumbs: Breadcrumbs.of(trail),
      events: (name, [attributes = const {}]) =>
          events.add((name, Map.of(attributes))),
    );
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    await transport.close();
    lock.dispose();
    activity.dispose();
    selection.dispose();
    composer.dispose();
    panelShown.dispose();
  });

  Future<void> open(String id) async {
    if (chat.threads.isEmpty) await chat.loadThreads('work');
    chat.select(id);
    await pumpEventQueue();
  }

  /// Starts agent [id] as a reply's frame does, and lists it as running.
  void startAgent(
    String id,
    String goal, {
    String? parent,
    int toolCount = 0,
    String? tool,
    String? preview,
    bool acceptingSteer = true,
    int? startedAgo,
  }) {
    listed[id] = {
      'subagent_id': id,
      'goal': goal,
      'status': 'running',
      'started_at':
          DateTime.now().millisecondsSinceEpoch / 1000 - (startedAgo ?? 3),
      'tool_count': toolCount,
      'accepting_steer': acceptingSteer,
      'last_tool': ?tool,
      'parent_id': ?parent,
    };
    gateway.event('subagent.start', 'rt-1', {
      'subagent_id': id,
      'goal': goal,
      'task_count': 2,
      'parent_id': ?parent,
    });
    if (tool != null) {
      gateway.event('subagent.tool', 'rt-1', {
        'subagent_id': id,
        'goal': goal,
        'tool_name': tool,
        'tool_preview': preview ?? '',
        'tool_count': toolCount,
      });
    }
  }

  void endAgent(
    String id,
    String goal, {
    String status = 'completed',
    String? summary,
    int seconds = 95,
    int tools = 4,
  }) {
    listed.remove(id);
    gateway.event('subagent.complete', 'rt-1', {
      'subagent_id': id,
      'goal': goal,
      'status': status,
      'summary': ?summary,
      'duration_seconds': seconds,
      'tool_count': tools,
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.pump();
      await tester.runAsync(pumpEventQueue);
    }
    await tester.pump();
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    bool readOnly = false,
    bool withSelection = true,
  }) async {
    final focus = FocusNode();
    final latest = LatestReply();
    addTearDown(focus.dispose);
    addTearDown(latest.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge([chat, panelShown]),
            builder: (context, _) => Row(
              children: [
                Expanded(
                  key: const Key('strip-side'),
                  child: boundChatThreadView(
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
                    welcome: false,
                  ),
                ),
                if (panelShown.value)
                  SizedBox(
                    width: 380,
                    child: BoundActivityPanel(
                      chat: chat,
                      thread: chat.selectedThread,
                      selection: withSelection ? selection : null,
                      readOnly: readOnly,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  List<Map<String, Object?>> calls(String method) => [
    for (final request in gateway.requests)
      if (request['method'] == method)
        (request['params'] as Map).cast<String, Object?>(),
  ];

  AgentKey keyOf(String id) =>
      agentKeyOf(chat.subagentsIn(chat.selectedThread!)!, id);

  Finder dialogText(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  Finder inPanel(Finder finder) =>
      find.descendant(of: find.byType(BoundActivityPanel), matching: finder);

  Finder noteField() => find.descendant(
    of: find.byType(AgentNoteField),
    matching: find.byType(TextField),
  );

  /// The list's scroll position, read even while a detail covers it.
  double listOffset(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('activity-panel'), skipOffstage: false),
              matching: find.byType(Scrollable),
              skipOffstage: false,
            )
            .first,
      )
      .position
      .pixels;

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await settle(tester);
  }

  /// Opens one agent's detail as a tap on its row does.
  Future<void> openDetail(WidgetTester tester, String id) async {
    selection.select(keyOf(id));
    await settle(tester);
  }

  group('the list', () {
    panelTest('two running agents show under Now and one moves to This '
        'session as Finished', (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent(
          'a1',
          _audit,
          toolCount: 2,
          tool: 'read_file',
          preview: 'package-lock.json',
        );
        startAgent('a2', _plan, startedAgo: 1);
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      expect(inPanel(find.text('NOW')), findsOneWidget);
      expect(inPanel(find.textContaining('Finished')), findsNothing);
      expect(inPanel(find.text(_audit)), findsOneWidget);
      expect(inPanel(find.text(_plan)), findsOneWidget);
      expect(inPanel(find.textContaining('Running')), findsNWidgets(2));
      expect(
        inPanel(find.textContaining('read_file')),
        findsOneWidget,
        reason: 'the running agent shows what it is doing',
      );

      await tester.runAsync(() async {
        endAgent('a1', _audit, summary: 'Three packages need an update.');
        await pumpEventQueue();
      });
      await settle(tester);
      expect(inPanel(find.text('THIS SESSION')), findsOneWidget);
      expect(inPanel(find.textContaining('Running')), findsOneWidget);
      expect(inPanel(find.textContaining('Finished')), findsOneWidget);
      final nowTitle = tester.getTopLeft(inPanel(find.text('NOW'))).dy;
      final planRow = tester.getTopLeft(inPanel(find.text(_plan))).dy;
      final sessionTitle = tester
          .getTopLeft(inPanel(find.text('THIS SESSION')))
          .dy;
      final auditRow = tester.getTopLeft(inPanel(find.text(_audit))).dy;
      expect(nowTitle, lessThan(planRow));
      expect(planRow, lessThan(sessionTitle));
      expect(sessionTitle, lessThan(auditRow));
    });

    panelTest('23 ended agents show the 20 newest and say 3 are not shown', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await open('stored-1');
        for (var i = 1; i <= 23; i++) {
          startAgent('e$i', 'Task $i');
          endAgent('e$i', 'Task $i', seconds: i);
        }
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      expect(inPanel(find.byType(AgentRow)), findsNWidgets(20));
      expect(inPanel(find.text('3 earlier agents not shown')), findsOneWidget);
      expect(inPanel(find.text('Task 3')), findsNothing);
      expect(inPanel(find.text('Task 4')), findsOneWidget);
      expect(inPanel(find.text('Task 23')), findsOneWidget);
    });

    panelTest('a nested agent is drawn indented under its parent', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit);
        startAgent('a2', _plan, parent: 'a1', startedAgo: 1);
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      final parent = tester.getTopLeft(inPanel(find.text(_audit))).dx;
      final child = tester.getTopLeft(inPanel(find.text(_plan))).dx;
      expect(child, greaterThan(parent));
    });
  });

  group('the detail', () {
    panelTest('a tap on a row opens it in place of the sections, Back and '
        'Escape return to the list at its scroll offset', (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit, tool: 'read_file');
        for (var i = 1; i <= 23; i++) {
          startAgent('e$i', 'Task $i');
          endAgent('e$i', 'Task $i', seconds: i);
        }
        outputs['a1'] = '10:02:11 tool    | read_file package-lock.json';
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      await tester.drag(
        find.byKey(const Key('activity-panel')),
        const Offset(0, -500),
      );
      await tester.pump();
      final scrolled = listOffset(tester);
      expect(scrolled, greaterThan(100));

      final rows = find.byType(AgentRow);
      Finder? visibleRow;
      for (var i = 0; i < rows.evaluate().length; i++) {
        final dy = tester.getCenter(rows.at(i)).dy;
        if (dy > 200 && dy < 450) {
          visibleRow = rows.at(i);
          break;
        }
      }
      expect(visibleRow, isNotNull, reason: 'a row is on screen');
      await tester.tap(visibleRow!);
      await settle(tester);

      expect(selection.key, isNotNull);
      expect(find.text('Recent output'), findsOneWidget);
      expect(
        find.byKey(const Key('activity-panel')),
        findsNothing,
        reason: 'the sections are covered while the detail is open',
      );
      expect(find.byTooltip('Back to Activity'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to Activity'));
      await settle(tester);
      expect(selection.key, isNull);
      expect(find.byKey(const Key('activity-panel')), findsOneWidget);
      expect(find.text('Recent output'), findsNothing);
      expect(listOffset(tester), scrolled);

      // Escape goes back too, and keeps the offset.
      await tester.tap(visibleRow);
      await settle(tester);
      expect(selection.key, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(selection.key, isNull);
      expect(listOffset(tester), scrolled);
    });

    panelTest('selection of another chat or profile is not shown and is '
        'cleared', (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit);
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      final roster = chat.subagentsIn(chat.selectedThread!)!;
      AgentKey foreign({String? thread, String? profile}) => AgentKey(
        threadId: thread ?? roster.threadId,
        profile: profile ?? roster.profile,
        connection: roster.connection ?? roster,
        subagentId: 'a1',
      );

      selection.select(foreign(thread: 'stored-2'));
      await settle(tester);
      expect(find.text('Recent output'), findsNothing);
      expect(find.byKey(const Key('activity-panel')), findsOneWidget);
      expect(selection.key, isNull);

      selection.select(foreign(profile: 'another-profile'));
      await settle(tester);
      expect(find.text('Recent output'), findsNothing);
      expect(find.byKey(const Key('activity-panel')), findsOneWidget);
      expect(selection.key, isNull);
    });

    panelTest('the output is read while the detail is open', (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit, tool: 'read_file');
        outputs['a1'] = '10:02:11 tool    | read_file package-lock.json';
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      await openDetail(tester, 'a1');
      expect(calls('subagent.tail'), isNotEmpty);
      expect(calls('subagent.tail').first['subagent_id'], 'a1');
      expect(calls('subagent.tail').first['session_id'], 'rt-1');
      expect(find.textContaining('package-lock.json'), findsWidgets);
    });

    panelTest('closing the detail drops the typed note', (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit);
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      await openDetail(tester, 'a1');
      await tester.ensureVisible(noteField());
      await tester.enterText(noteField(), 'Only check the Go modules');
      await tester.pump();
      expect(
        tester.widget<TextField>(noteField()).controller!.text,
        'Only check the Go modules',
      );
      await tester.tap(find.byTooltip('Back to Activity'));
      await settle(tester);
      await openDetail(tester, 'a1');
      await tester.ensureVisible(noteField());
      expect(tester.widget<TextField>(noteField()).controller!.text, isEmpty);
      expect(calls('subagent.steer'), isEmpty);
    });
  });

  group('stop', () {
    Future<void> arrange(WidgetTester tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit, tool: 'read_file');
        startAgent('a2', _plan, startedAgo: 1);
        outputs['a1'] = '10:02:11 tool    | read_file package-lock.json';
        await pumpEventQueue();
      });
      await pumpPanel(tester);
    }

    panelTest('from the detail asks first; Cancel sends nothing', (
      tester,
    ) async {
      await arrange(tester);
      await openDetail(tester, 'a1');
      await tapText(tester, 'Stop agent');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(dialogText('Stop this agent?'), findsOneWidget);
      final message = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data ?? '')
          .firstWhere((text) => text.startsWith(_audit));
      expect(message, contains('A tool that is running may be cut off.'));
      expect(message, contains('Programs it started keep running.'));
      expect(calls('subagent.interrupt'), isEmpty, reason: 'only asked');

      await tester.tap(dialogText('Cancel'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls('subagent.interrupt'), isEmpty);
      expect(find.text('Stop agent'), findsOneWidget);
      expect(find.text('Stopping…'), findsNothing);
    });

    panelTest('confirming sends exactly one interrupt for that agent and '
        'that runtime session', (tester) async {
      await arrange(tester);
      await openDetail(tester, 'a1');
      await tapText(tester, 'Stop agent');
      expect(calls('subagent.interrupt'), isEmpty);
      await tester.tap(dialogText('Stop agent'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);

      final sent = calls('subagent.interrupt');
      expect(sent, hasLength(1));
      expect(sent.single['subagent_id'], 'a1');
      expect(sent.single['session_id'], 'rt-1');
      expect(find.text('Stopping…'), findsOneWidget);
      expect(find.text('A tool that is running may be cut off.'), findsOne);
      expect(find.text('Stop agent'), findsNothing);

      await tester.runAsync(() async {
        endAgent('a1', _audit, status: 'interrupted');
        await pumpEventQueue();
      });
      await settle(tester);
      expect(find.textContaining('Stopped'), findsWidgets);
      expect(find.text('This agent was stopped.'), findsOneWidget);
      expect(calls('subagent.interrupt'), hasLength(1));
    });

    panelTest('the confirmation stays bound to its agent when the list '
        'reorders', (tester) async {
      await arrange(tester);
      await openDetail(tester, 'a1');
      await tapText(tester, 'Stop agent');
      await tester.runAsync(() async {
        startAgent('a0', 'Another agent that started earlier', startedAgo: 900);
        await pumpEventQueue();
      });
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(dialogText('Stop agent'));
      await settle(tester);
      final sent = calls('subagent.interrupt');
      expect(sent, hasLength(1));
      expect(sent.single['subagent_id'], 'a1');
    });

    panelTest('"Stop agent" from a row opens the same confirmation and '
        'sends nothing unless confirmed', (tester) async {
      await arrange(tester);
      selection.select(keyOf('a1'), stop: true);
      await settle(tester);
      expect(dialogText('Stop this agent?'), findsOneWidget);
      expect(calls('subagent.interrupt'), isEmpty);
      await tester.tap(dialogText('Cancel'));
      await settle(tester);
      expect(calls('subagent.interrupt'), isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    });

    panelTest('"Stop agent" from a row sends one interrupt once confirmed', (
      tester,
    ) async {
      await arrange(tester);
      selection.select(keyOf('a2'), stop: true);
      await settle(tester);
      await tester.tap(dialogText('Stop agent'));
      await settle(tester);
      final sent = calls('subagent.interrupt');
      expect(sent, hasLength(1));
      expect(sent.single['subagent_id'], 'a2');
      expect(sent.single['session_id'], 'rt-1');
    });

    panelTest('the confirmation closes with "That agent has ended." when '
        'the agent completes first, and nothing is sent', (tester) async {
      await arrange(tester);
      selection.select(keyOf('a1'), stop: true);
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.runAsync(() async {
        endAgent('a1', _audit, summary: 'Three packages need an update.');
        await pumpEventQueue();
      });
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('That agent has ended.'), findsOneWidget);
      expect(calls('subagent.interrupt'), isEmpty);
      expect(find.text('Stop agent'), findsNothing);
    });
    panelTest('an unconfirmed stop says so, offers Stop agent again and '
        'resends nothing', (tester) async {
      await arrange(tester);
      var listFails = false;
      gateway.handlers['subagent.interrupt'] = (_) {
        listFails = true;
        return {'found': false};
      };
      final answerList = gateway.handlers['subagent.list']!;
      gateway.handlers['subagent.list'] = (params) {
        if (listFails) throw const FakeRpcError(5000, 'read failed');
        return answerList(params);
      };
      await openDetail(tester, 'a1');
      await tapText(tester, 'Stop agent');
      await tester.tap(dialogText('Stop agent'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);

      expect(find.text("Couldn't confirm the stop."), findsOneWidget);
      expect(find.text('It may still be running.'), findsOneWidget);
      expect(find.text('Stop agent'), findsOneWidget);
      expect(find.text('Stopping…'), findsNothing);
      expect(calls('subagent.interrupt'), hasLength(1));

      await tapText(tester, 'Stop agent');
      expect(dialogText('Stop this agent?'), findsOneWidget);
      expect(
        calls('subagent.interrupt'),
        hasLength(1),
        reason: 'a second Stop asks again before anything is sent',
      );
      await tester.tap(dialogText('Cancel'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls('subagent.interrupt'), hasLength(1));
    });
  });

  group('notes', () {
    panelTest('a note is sent only on Send to agent, trimmed, once, and '
        'never touches the composer or the chat', (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit);
        await pumpEventQueue();
      });
      composer.text = 'a draft for the chat';
      await pumpPanel(tester);
      await openDetail(tester, 'a1');
      await tester.ensureVisible(noteField());
      await tester.enterText(noteField(), '  Only check the Go modules  \n');
      await tester.pump();
      await settle(tester);
      expect(calls('subagent.steer'), isEmpty, reason: 'typing sends nothing');

      await tapText(tester, 'Send to agent');
      final sent = calls('subagent.steer');
      expect(sent, hasLength(1));
      expect(sent.single['text'], 'Only check the Go modules');
      expect(sent.single['subagent_id'], 'a1');
      expect(sent.single['session_id'], 'rt-1');
      expect(find.text('Sent.'), findsOneWidget);
      expect(find.text('Your notes'), findsOneWidget);
      expect(find.text('Only check the Go modules'), findsOneWidget);
      expect(tester.widget<TextField>(noteField()).controller!.text, isEmpty);

      expect(composer.text, 'a draft for the chat');
      expect(gateway.methods, isNot(contains('prompt.submit')));
      expect(chat.selectedThread!.messages, isEmpty);
    });

    panelTest('a note frozen by an accepted stop shows Not sent, Copy puts it '
        'on the clipboard and sends nothing', (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit);
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      await openDetail(tester, 'a1');
      await tester.ensureVisible(noteField());
      await tester.enterText(noteField(), 'Check the lockfile first');
      await tester.pump();
      await tapText(tester, 'Send to agent');
      expect(calls('subagent.steer'), hasLength(1));

      await tester.ensureVisible(noteField());
      await tester.enterText(noteField(), 'Only check the Go modules');
      await tester.pump();
      await tapText(tester, 'Stop agent');
      await tester.tap(dialogText('Stop agent'));
      await settle(tester);
      expect(calls('subagent.interrupt'), hasLength(1));

      expect(find.text('Not sent'), findsOneWidget);
      expect(find.text('Only check the Go modules'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Send to agent'), findsNothing);

      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tapText(tester, 'Copy');
      expect(copied, ['Only check the Go modules']);
      expect(calls('subagent.steer'), hasLength(1), reason: 'nothing resent');
      expect(calls('subagent.interrupt'), hasLength(1));
    });
  });

  group('reads', () {
    panelTest('the list is read only while the panel is shown', (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit);
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      final first = calls('subagent.list').length;
      expect(first, greaterThan(0));

      await tester.pump(const Duration(seconds: 5));
      await settle(tester);
      expect(
        calls('subagent.list').length,
        greaterThan(first),
        reason: 'a running agent is read again every 5 seconds',
      );

      panelShown.value = false;
      await settle(tester);
      expect(find.byType(BoundActivityPanel), findsNothing);
      final hidden = calls('subagent.list').length;
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 5));
        await tester.runAsync(pumpEventQueue);
      }
      expect(calls('subagent.list').length, hidden);

      panelShown.value = true;
      await settle(tester);
      expect(calls('subagent.list').length, greaterThan(hidden));
    });
  });

  group('review fixes', () {
    Future<void> arrangeOne(WidgetTester tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit, tool: 'read_file');
        outputs['a1'] = '10:02:11 tool    | read_file package-lock.json';
        await pumpEventQueue();
      });
      await pumpPanel(tester);
    }

    panelTest('a detail torn down closes the open stop confirmation and '
        'sends nothing', (tester) async {
      await arrangeOne(tester);
      await openDetail(tester, 'a1');
      await tapText(tester, 'Stop agent');
      expect(find.byType(AlertDialog), findsOneWidget);

      panelShown.value = false;
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls('subagent.interrupt'), isEmpty);
    });

    panelTest('Escape in the note field with text only leaves the field', (
      tester,
    ) async {
      await arrangeOne(tester);
      await openDetail(tester, 'a1');
      await tester.ensureVisible(noteField());
      await tester.tap(noteField());
      await tester.enterText(noteField(), 'Only check the Go modules');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(AgentNoteField), findsOneWidget, reason: 'still open');
      expect(
        tester.widget<TextField>(noteField()).controller!.text,
        'Only check the Go modules',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(AgentNoteField), findsNothing);
    });

    panelTest('an agent that ends while Stopping leaves no banner under '
        'Stopped', (tester) async {
      await arrangeOne(tester);
      await openDetail(tester, 'a1');
      await tapText(tester, 'Stop agent');
      await tester.tap(dialogText('Stop agent'));
      await settle(tester);
      expect(find.text('Stopping…'), findsOneWidget);

      await tester.runAsync(() async {
        endAgent('a1', _audit, status: 'interrupted');
        await pumpEventQueue();
      });
      await settle(tester);
      expect(find.text('This agent was stopped.'), findsOneWidget);
      expect(find.text('Stopping…'), findsNothing);
      expect(find.textContaining('may be cut off'), findsNothing);
    });
  });

  group('a conversation window (readOnly)', () {
    panelTest(
      'sends no agent call and offers no note or output, even with a detail open',
      (tester) async {
        await tester.runAsync(() async {
          await open('stored-1');
          startAgent('a1', _audit, tool: 'read_file');
          await pumpEventQueue();
        });
        await pumpPanel(tester, readOnly: true);
        expect(inPanel(find.text(_audit)), findsOneWidget);
        expect(
          tester.widget<AgentRow>(find.byType(AgentRow)).onStop,
          isNull,
          reason: 'no Stop on a row',
        );

        await openDetail(tester, 'a1');
        expect(
          find.text('Agent'),
          findsOneWidget,
          reason: 'the detail is open',
        );
        expect(find.text(_audit), findsOneWidget);
        expect(find.textContaining('Running'), findsWidgets);
        expect(find.byType(AgentNoteField), findsNothing);
        expect(find.text('Send to agent'), findsNothing);
        expect(find.text('Redirect this agent'), findsNothing);
        expect(find.text('Recent output'), findsNothing);
        expect(find.text('Last output'), findsNothing);

        // A request to stop opens nothing either.
        selection.clear();
        await settle(tester);
        selection.select(keyOf('a1'), stop: true);
        await settle(tester);
        await tester.pump(const Duration(seconds: 30));
        await settle(tester);
        expect(find.byType(AlertDialog), findsNothing);

        for (final method in [
          'subagent.list',
          'subagent.tail',
          'subagent.interrupt',
          'subagent.steer',
        ]) {
          expect(calls(method), isEmpty, reason: method);
        }
      },
    );
  });

  group('a conversation window', () {
    // The spec says a conversation window shows no Stop.
    panelTest('a readOnly detail shows no Stop agent button', (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit);
        await pumpEventQueue();
      });
      await pumpPanel(tester, readOnly: true);
      await openDetail(tester, 'a1');
      expect(find.text('Stop agent'), findsNothing);
      expect(find.text('Programs it started keep running.'), findsNothing);
    });
  });

  group('telemetry', () {
    panelTest('the detail records exactly its fixed breadcrumbs and outcomes', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit, tool: 'read_file');
        outputs['a1'] = '10:02:11 tool | read_file package-lock.json';
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      selection.select(keyOf('a1'), source: 'transcript');
      await settle(tester);
      await tester.ensureVisible(noteField());
      await tester.enterText(noteField(), 'Only check the Go modules');
      await tester.pump();
      await tapText(tester, 'Send to agent');
      await tapText(tester, 'Stop agent');
      await tester.tap(dialogText('Stop agent'));
      await settle(tester);
      await tester.tap(find.byTooltip('Back to Activity'));
      await settle(tester);

      final crumbs = [
        for (final crumb in trail.recent)
          if (crumb.name.startsWith('subagent.'))
            '${crumb.name} ${crumb.attributes}',
      ];
      expect(crumbs, [
        'subagent.detail.opened {source: transcript}',
        'subagent.redirect.sent {}',
        'subagent.stop.pressed {}',
        'subagent.stop.confirmed {}',
        'subagent.detail.closed {}',
      ]);
      expect(
        [
          for (final (name, attributes) in events)
            if (name.startsWith('subagent.')) '$name $attributes',
        ],
        [
          'subagent.redirect {outcome: queued}',
          'subagent.stop {outcome: stopped}',
        ],
      );
      // Events carry only a fixed outcome word.
      const outcomes = {
        'queued',
        'rejected',
        'unconfirmed',
        'error',
        'missed',
        'stopped',
        'already_ended',
        'not_controllable',
      };
      for (final (name, attributes) in events) {
        if (!name.startsWith('subagent.')) continue;
        expect(attributes.keys.toSet().difference({'outcome'}), isEmpty);
        if (attributes.containsKey('outcome')) {
          expect(outcomes, contains(attributes['outcome']), reason: name);
        }
      }
    });

    panelTest('a panel row opens with the source panel', (tester) async {
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent('a1', _audit);
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      await openDetail(tester, 'a1');
      final opened = [
        for (final crumb in trail.recent)
          if (crumb.name == 'subagent.detail.opened') crumb.attributes,
      ];
      expect(opened, [
        {'source': 'panel'},
      ]);
    });
  });

  group('privacy', () {
    panelTest('goals, notes, output and summaries reach no breadcrumb or '
        'app event', (tester) async {
      const goal = 'Audit SECRET-GOAL-7731 tokens';
      await tester.runAsync(() async {
        await open('stored-1');
        startAgent(
          'agent-secret-id',
          goal,
          tool: 'read_file',
          preview: 'SECRET-PREVIEW-1188',
        );
        outputs['agent-secret-id'] = '10:02:11 tool | SECRET-OUTPUT-4410';
        await pumpEventQueue();
      });
      await pumpPanel(tester);
      await openDetail(tester, 'agent-secret-id');
      await tester.ensureVisible(noteField());
      await tester.enterText(noteField(), 'SECRET-NOTE-9082');
      await tester.pump();
      await tapText(tester, 'Send to agent');
      await tapText(tester, 'Stop agent');
      await tester.tap(dialogText('Stop agent'));
      await settle(tester);
      await tester.runAsync(() async {
        endAgent(
          'agent-secret-id',
          goal,
          status: 'interrupted',
          summary: 'SECRET-SUMMARY-5521',
        );
        await pumpEventQueue();
      });
      await settle(tester);
      await tester.tap(find.byTooltip('Back to Activity'));
      await settle(tester);

      final crumbs = [for (final crumb in trail.recent) crumb.name];
      expect(
        crumbs,
        containsAll([
          'subagent.detail.opened',
          'subagent.detail.closed',
          'subagent.stop.pressed',
          'subagent.stop.confirmed',
          'subagent.redirect.sent',
        ]),
      );
      expect([
        for (final (name, _) in events) name,
      ], containsAll(['subagent.stop', 'subagent.redirect']));
      final seen = [
        for (final (name, attributes) in events) '$name $attributes',
        for (final crumb in trail.recent) '${crumb.name} ${crumb.attributes}',
      ].join('\n');
      for (final secret in [
        'SECRET',
        'agent-secret-id',
        'Audit',
        'read_file',
        'Go modules',
      ]) {
        expect(seen, isNot(contains(secret)), reason: secret);
      }
    });
  });
}

class _TestAppLock extends AppLockController {
  @override
  bool get covered => false;
}
