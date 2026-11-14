import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_gateway.dart';
import '../../support/fake_hermes_server.dart';

// Invented programs and output only.
const _command = 'npm run dev -- --port 4173';
const _secretCommand = 'deploy --token=SECRET-TOKEN-123';

/// The Activity panel's program cards, bound to `process.list` and
/// `process.kill` through the real gateway transport and chat controller.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late ChatController chat;
  late AttentionNotifier attention;
  late BreadcrumbTrail trail;
  late List<(String, Map<String, Object?>)> events;

  /// What `process.list` answers, by program id.
  late Map<String, Map<String, Object?>> programs;

  /// How the panel is shown: 'writable', 'readOnly' or 'hidden'.
  late ValueNotifier<String> panel;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    trail = BreadcrumbTrail(capacity: 200);
    events = [];
    programs = {};
    panel = ValueNotifier('writable');
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['session.resume'] = (params) => {
      'session_id': 'rt-1',
      'stored_session_id': 'stored-1',
      'session_key': 'stored-1',
    };
    gateway.handlers['process.list'] = (_) => {
      'processes': programs.values.toList(),
    };
    gateway.handlers['process.kill'] = (params) {
      final id = params['process_id']! as String;
      programs[id] = {
        ...programs[id]!,
        'status': 'exited',
        'exit_code': -15,
        'completion_reason': 'killed',
      };
      return {
        'status': 'killed',
        'exit_code': -15,
        'completion_reason': 'killed',
        'output': 'listening on 4173\n',
      };
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'First')]),
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
      breadcrumbs: Breadcrumbs.of(trail),
      events: (name, [attributes = const {}]) =>
          events.add((name, Map.of(attributes))),
    );
  });

  tearDown(() async {
    panel.dispose();
    chat.dispose();
    attention.dispose();
    await transport.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 2; i++) {
      await tester.pump();
      await tester.runAsync(pumpEventQueue);
    }
    await tester.pump();
  }

  /// Opens the chat, starts program [id] with a frame and lists it running
  /// (unless [listed] is false).
  Future<void> arrange(
    WidgetTester tester, {
    String id = 'proc_dev',
    String command = _command,
    bool listed = true,
    bool readOnly = false,
  }) async {
    await tester.runAsync(() async {
      await chat.loadThreads('work');
      chat.select('stored-1');
      await pumpEventQueue();
      if (listed) {
        programs[id] = {
          'session_id': id,
          'command': command,
          'status': 'running',
          'uptime_seconds': 42,
        };
      }
      gateway.event('agent.terminal.output', 'rt-1', {
        'process_id': id,
        'chunk': 'listening on 4173\n',
      });
      await pumpEventQueue();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: Listenable.merge([chat, panel]),
            builder: (context, _) => SizedBox(
              width: 380,
              child: panel.value == 'hidden'
                  ? const SizedBox.shrink()
                  : BoundActivityPanel(
                      chat: chat,
                      thread: chat.selectedThread,
                      readOnly: readOnly || panel.value == 'readOnly',
                    ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    // Open the card, where its output and Stop are.
    await tester.tap(find.byType(ProcessOutputCard));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }

  List<Map<String, Object?>> calls(String method) => [
    for (final request in gateway.requests)
      if (request['method'] == method)
        (request['params'] as Map).cast<String, Object?>(),
  ];

  Finder dialogText(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  Finder stopButton() =>
      find.widgetWithText(DestructiveTintButton, 'Stop program');

  Future<void> pressStop(WidgetTester tester) async {
    final label = find.descendant(
      of: stopButton(),
      matching: find.text('Stop program'),
    );
    await tester.ensureVisible(label);
    await tester.pump();
    await tester.tap(label);
    await settle(tester);
  }

  /// Lets the roster's 5 s program read land.
  Future<void> nextRead(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(pumpEventQueue);
  }

  testWidgets('a listed running program shows its command, Running and '
      'Stop program', (tester) async {
    await arrange(tester);
    expect(calls('process.list'), isNotEmpty);
    expect(find.text(unbreakableHyphens(_command)), findsOneWidget);
    expect(find.textContaining('Running'), findsOneWidget);
    expect(stopButton(), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a card the list never named keeps today\'s wording and has '
      'no Stop', (tester) async {
    await arrange(tester, listed: false);
    expect(find.text('Process proc_dev · Output received'), findsOneWidget);
    expect(stopButton(), findsNothing);
    await finish(tester);
  });

  testWidgets('Stop asks first; Cancel sends nothing', (tester) async {
    await arrange(tester);
    await pressStop(tester);
    expect(dialogText('Stop this program?'), findsOneWidget);
    expect(calls('process.kill'), isEmpty);
    await tester.tap(dialogText('Cancel'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls('process.kill'), isEmpty);
    expect(stopButton(), findsOneWidget);
    await finish(tester);
  });

  testWidgets('Confirm sends exactly one process.kill for that program, '
      'and shows Stopping… while it is in flight', (tester) async {
    await arrange(tester);
    gateway.silent.add('process.kill');
    await pressStop(tester);
    await tester.tap(dialogText('Stop program'));
    await settle(tester);
    expect(find.text('Stopping…'), findsOneWidget);
    // A second press while it is in flight does nothing.
    await tester.tap(find.text('Stopping…'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    final sent = calls('process.kill');
    expect(sent, hasLength(1));
    expect(sent.single['process_id'], 'proc_dev');
    expect(sent.single['session_id'], 'rt-1');
    // Let the unanswered call time out and its check end.
    await tester.pump(const Duration(seconds: 11));
    await settle(tester);
    await tester.pump(const Duration(seconds: 11));
    await settle(tester);
    expect(calls('process.kill'), hasLength(1));
    await finish(tester);
  });

  testWidgets('a killed answer reads Stopped and Stop goes', (tester) async {
    await arrange(tester);
    await pressStop(tester);
    await tester.tap(dialogText('Stop program'));
    await settle(tester);
    expect(calls('process.kill'), hasLength(1));
    expect(find.text('Stopped'), findsWidgets);
    expect(stopButton(), findsNothing);
    expect(find.textContaining('Running'), findsNothing);
    await finish(tester);
  });

  testWidgets('a lost answer re-reads, says it couldn\'t confirm, and offers '
      'Stop again behind a new confirmation; one kill in all', (tester) async {
    await arrange(tester);
    gateway.silent.add('process.kill');
    await pressStop(tester);
    await tester.tap(dialogText('Stop program'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 11));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text("Couldn't confirm the stop."), findsOneWidget);
    expect(find.text('It may still be running.'), findsOneWidget);
    expect(stopButton(), findsOneWidget);
    await pressStop(tester);
    expect(dialogText('Stop this program?'), findsOneWidget);
    await tester.tap(dialogText('Cancel'));
    await settle(tester);
    expect(calls('process.kill'), hasLength(1));
    await finish(tester);
  });

  testWidgets('the program exiting closes the confirmation with no kill', (
    tester,
  ) async {
    await arrange(tester);
    await pressStop(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    programs['proc_dev'] = {
      ...programs['proc_dev']!,
      'status': 'exited',
      'exit_code': 0,
    };
    await nextRead(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls('process.kill'), isEmpty);
    expect(find.text('Exited with code 0 · 42s'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a server without process.kill removes Stop after one sentence', (
    tester,
  ) async {
    gateway.handlers['process.kill'] = (_) =>
        throw const FakeRpcError(-32601, 'unknown method');
    await arrange(tester);
    await pressStop(tester);
    await tester.tap(dialogText('Stop program'));
    await settle(tester);
    expect(find.text("This server can't stop programs."), findsOneWidget);
    expect(stopButton(), findsNothing);
    await finish(tester);
  });

  testWidgets('a read-only panel sends nothing and shows no Stop', (
    tester,
  ) async {
    await arrange(tester, readOnly: true);
    await tester.pump(const Duration(seconds: 12));
    await settle(tester);
    expect(stopButton(), findsNothing);
    expect(calls('process.list'), isEmpty);
    expect(calls('process.kill'), isEmpty);
    await finish(tester);
  });

  testWidgets('a program the list named runs on, and the same chat drawn '
      'read-only offers no Stop and sends nothing', (tester) async {
    await arrange(tester);
    expect(find.text(unbreakableHyphens(_command)), findsOneWidget);
    expect(stopButton(), findsOneWidget, reason: 'writable: Stop is there');
    final lists = calls('process.list').length;

    panel.value = 'readOnly';
    await settle(tester);
    await tester.tap(find.byType(ProcessOutputCard));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text(unbreakableHyphens(_command)),
      findsOneWidget,
      reason: 'still named',
    );
    expect(find.textContaining('Running'), findsOneWidget);
    expect(stopButton(), findsNothing);
    expect(
      tester.widget<ProcessOutputCard>(find.byType(ProcessOutputCard)).onStop,
      isNull,
    );
    await tester.pump(const Duration(seconds: 12));
    await settle(tester);
    expect(calls('process.list'), hasLength(lists), reason: 'no reads');
    expect(calls('process.kill'), isEmpty);
    await finish(tester);
  });

  testWidgets('closing the panel while the confirmation is open closes it '
      'with no kill', (tester) async {
    await arrange(tester);
    await pressStop(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    panel.value = 'hidden';
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls('process.kill'), isEmpty);
    await finish(tester);
  });

  testWidgets('breadcrumbs and events carry no command, output or id', (
    tester,
  ) async {
    await arrange(tester, id: 'proc-SECRET-id', command: _secretCommand);
    await pressStop(tester);
    await tester.tap(dialogText('Stop program'));
    await settle(tester);
    final stops = [
      for (final (name, attributes) in events)
        if (name == 'process.stop') attributes,
    ];
    expect(stops, [
      {'outcome': 'killed'},
    ]);
    final pressed = trail.recent.where((c) => c.name == 'process.stop.pressed');
    expect(pressed, hasLength(1));
    expect(pressed.single.attributes, isEmpty);
    final seen = [
      for (final (name, attributes) in events) '$name $attributes',
      for (final crumb in trail.recent) '${crumb.name} ${crumb.attributes}',
    ].join('\n');
    for (final secret in ['SECRET', 'deploy', 'listening', '4173']) {
      expect(seen, isNot(contains(secret)), reason: secret);
    }
    await finish(tester);
  });
}
