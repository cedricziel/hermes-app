import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_detail_view.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_note_field.dart';
import 'package:hermes_app/src/chat/widgets/subagent_card.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/find_app_icon.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

const _audit =
    'Audit the dependency tree for packages with known vulnerabilities';
const _plan = 'Draft the upgrade plan for the flagged packages';
const _note = 'Only check the Go modules';

const _planOutput =
    '10:02:21 tool    | read_file package.json\n'
    '10:02:23 agent   | Listing the direct dependencies by risk.';

const _auditOutput =
    '10:02:07 tool    | read_file package-lock.json\n'
    '10:02:09 tool    | web_search known advisories for lodash 4.17.15\n'
    '10:02:15 agent   | Found three direct dependencies with open advisories.';

/// The Activity panel's agents on a phone and on a Mac: two agents run beside
/// a reply, one is stopped after a confirmation, the other is sent a note and
/// finishes while its detail is open.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  /// The agents the fake `subagent.list` says run.
  late Map<String, Map<String, Object?>> running;

  setUp(() {
    running = {};
    transport = FakeChatTransport()
      ..agentAnswer = (call) => switch (call.method) {
        'subagent.list' => {
          'subagents': running.values.toList(),
          'delegations': <Object?>[],
        },
        'subagent.tail' => {
          'available': true,
          'text': call.params['subagent_id'] == 'agent-1'
              ? _auditOutput
              : _planOutput,
          'truncated': false,
        },
        'subagent.interrupt' => {'found': true},
        'subagent.steer' => {'status': 'queued'},
        _ => <String, Object?>{},
      };
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(
            id: 's1',
            title: 'Dependency audit',
            lastActive: 1780000900,
          ),
        ]),
      )
      ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []));
  });

  Future<void> pumpChat(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    required TargetPlatform platform,
    required Brightness brightness,
  }) => pumpScreen(
    tester,
    shots,
    ChatScreen(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
    ),
    size: size,
    brightness: brightness,
    platform: platform,
  );

  /// Opens the stored chat and sends the prompt that starts the reply.
  Future<FakeSend> startReply(WidgetTester tester) async {
    if (find.byKey(const ValueKey('thread-s1')).evaluate().isEmpty) {
      await openSidebar(tester);
    }
    await tester.tap(find.byKey(const ValueKey('thread-s1')).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      composerField,
      'Check our dependencies for known vulnerabilities.',
    );
    await tester.pump();
    await tester.tap(findAppIcon(AppIcons.sendArrow));
    await runFrames(tester);
    final reply = transport.sends.single;
    reply.emit(const ReplyStarted());
    await tester.pump();
    return reply;
  }

  Future<void> startAgents(WidgetTester tester, FakeSend reply) async {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    running['agent-1'] = {
      'subagent_id': 'agent-1',
      'goal': _audit,
      'status': 'running',
      'started_at': now - 20,
      'tool_count': 3,
      'last_tool': 'web_search',
      'accepting_steer': true,
    };
    running['agent-2'] = {
      'subagent_id': 'agent-2',
      'goal': _plan,
      'status': 'running',
      'started_at': now - 8,
      'tool_count': 1,
      'last_tool': 'read_file',
      'accepting_steer': true,
    };
    reply.emit(
      SubagentUpdated(
        Subagent(
          id: 'agent-1',
          goal: _audit,
          status: SubagentStatus.running,
          lastTool: 'web_search',
          lastToolPreview: 'known advisories for lodash 4.17.15',
          toolCount: 3,
          startedAt: DateTime.now().subtract(const Duration(seconds: 20)),
        ),
      ),
    );
    await tester.pump();
    reply.emit(
      SubagentUpdated(
        Subagent(
          id: 'agent-2',
          goal: _plan,
          index: 1,
          count: 2,
          status: SubagentStatus.running,
          lastTool: 'read_file',
          lastToolPreview: 'package.json',
          toolCount: 1,
          startedAt: DateTime.now().subtract(const Duration(seconds: 8)),
        ),
      ),
    );
    await runFrames(tester);
  }

  Future<void> finishAgent(
    WidgetTester tester,
    FakeSend reply,
    String id,
    String goal,
    SubagentStatus status, {
    String? summary,
  }) async {
    running.remove(id);
    reply.emit(
      SubagentUpdated(
        Subagent(
          id: id,
          goal: goal,
          status: status,
          summary: summary,
          duration: const Duration(seconds: 95),
          toolCount: 4,
        ),
      ),
    );
    await runFrames(tester);
  }

  Finder inPanel(Finder finder) =>
      find.descendant(of: find.byType(BoundActivityPanel), matching: finder);

  Finder inTranscriptCard(Finder finder) =>
      find.descendant(of: find.byType(SubagentGroupCard), matching: finder);

  Finder inDialog(String text) => find.descendant(
    of: find.byType(AppAlertDialog),
    matching: find.text(text),
  );

  Finder noteField() => find.descendant(
    of: find.byType(AgentNoteField),
    matching: find.byType(EditableText),
  );

  List<FakeAgentCall> calls(String method) => [
    for (final call in transport.agentActions)
      if (call.method == method) call,
  ];

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await runFrames(tester);
  }

  /// Back from an agent's detail: the Back button on a phone, Escape on a
  /// Mac.
  Future<void> leaveDetail(WidgetTester tester, {required bool phone}) async {
    if (phone) {
      await tester.tap(
        find.descendant(
          of: find.byType(AgentDetailView),
          matching: find.text('Activity'),
        ),
      );
    } else {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    }
    await runFrames(tester);
  }

  /// A widget test that runs as [platform] for the framework too, so a click
  /// outside the composer takes its focus away as it does on a Mac.
  void platformTest(
    String name,
    TargetPlatform platform,
    Future<void> Function(WidgetTester) body,
  ) => testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  Future<void> openActivity(WidgetTester tester, {required bool phone}) async {
    await tester.tap(
      phone
          ? find.byKey(const Key('header-activity'))
          : find.byTooltip('Show Inspector ⌥⌘I'),
    );
    await runFrames(tester);
  }

  /// The detail of [id]: opened from the panel's row, or from the
  /// transcript's card.
  Future<void> openAgentFromPanel(WidgetTester tester, String goal) async {
    await tester.tap(inPanel(find.text(goal)));
    await runFrames(tester);
  }

  for (final (name, size, platform) in [
    ('phone', phoneSize, TargetPlatform.iOS),
    ('desktop', desktopSize, TargetPlatform.macOS),
  ]) {
    final phone = name == 'phone';
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      platformTest(
        '$name ($mode): stop one agent, send a note to the other, '
        'watch one finish',
        platform,
        (tester) async {
          final shots = ScreenshotRecorder('subagent-control-$name-$mode');
          await pumpChat(
            tester,
            shots,
            size: size,
            platform: platform,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          final reply = await startReply(tester);
          await startAgents(tester, reply);
          expect(inTranscriptCard(find.text(_audit)), findsOneWidget);
          await shots.capture(tester, 'transcript-two-agents');

          // The transcript's row opens the panel at that agent.
          await tester.tap(inTranscriptCard(find.text(_audit)));
          await runFrames(tester);
          expect(find.byType(BoundActivityPanel), findsOneWidget);
          expect(find.text('Recent output'), findsOneWidget);
          expect(inPanel(find.text(_audit)), findsOneWidget);
          if (phone) {
            // A detail needs the room: the sheet grows to its full height.
            expect(
              tester.getSize(find.byType(BoundActivityPanel)).height,
              greaterThan(phoneSize.height * 0.85),
            );
          }
          await shots.capture(tester, 'opened-from-transcript');

          // Escape (or Back) returns to the list, which stays open.
          await leaveDetail(tester, phone: phone);
          expect(find.text('Recent output'), findsNothing);
          expect(find.byType(BoundActivityPanel), findsOneWidget);
          expect(inPanel(find.text('NOW')), findsOneWidget);
          expect(inPanel(find.text(_audit)), findsOneWidget);
          expect(inPanel(find.text(_plan)), findsOneWidget);
          await shots.capture(tester, 'activity-agents');

          // Open one agent and stop it, after a confirmation.
          await openAgentFromPanel(tester, _audit);
          expect(find.text('Recent output'), findsOneWidget);
          expect(find.textContaining('known advisories'), findsWidgets);
          await shots.capture(tester, 'agent-detail');

          await tapText(tester, 'Stop agent');
          expect(inDialog('Stop this agent?'), findsOneWidget);
          expect(calls('subagent.interrupt'), isEmpty);
          await shots.capture(tester, 'stop-confirmation');

          await tester.tap(inDialog('Stop agent'));
          await runFrames(tester);
          expect(calls('subagent.interrupt'), hasLength(1));
          expect(
            calls('subagent.interrupt').single.params['subagent_id'],
            'agent-1',
          );
          expect(calls('subagent.interrupt').single.threadId, 's1');
          expect(find.text('Stopping…'), findsOneWidget);
          await shots.capture(tester, 'stopping');

          await finishAgent(
            tester,
            reply,
            'agent-1',
            _audit,
            SubagentStatus.interrupted,
          );
          expect(find.text('This agent was stopped.'), findsOneWidget);
          expect(find.text('Stop agent'), findsNothing);
          await shots.capture(tester, 'stopped');

          // Back to the list, then a note to the other agent.
          await leaveDetail(tester, phone: phone);
          expect(inPanel(find.textContaining('Stopped')), findsOneWidget);
          await shots.capture(tester, 'list-one-stopped');

          await openAgentFromPanel(tester, _plan);
          await tester.ensureVisible(noteField());
          await tester.enterText(noteField(), _note);
          await tester.pump();
          await shots.capture(tester, 'note-typed');
          expect(
            calls('subagent.steer'),
            isEmpty,
            reason: 'typing sends nothing',
          );

          await tapText(tester, 'Send to agent');
          expect(calls('subagent.steer'), hasLength(1));
          expect(calls('subagent.steer').single.params['text'], _note);
          expect(
            calls('subagent.steer').single.params['subagent_id'],
            'agent-2',
          );
          expect(transport.sends, hasLength(1), reason: 'the chat got nothing');
          expect(find.text('Sent.'), findsOneWidget);
          expect(find.text('Your notes'), findsOneWidget);
          await shots.capture(tester, 'note-sent');

          // The agent finishes while its detail is open.
          await finishAgent(
            tester,
            reply,
            'agent-2',
            _plan,
            SubagentStatus.completed,
            summary: 'Upgrade order: lodash first, then the two build tools.',
          );
          expect(find.text('Finished'), findsWidgets);
          expect(
            find.text(
              'This agent has finished. Stop and notes no longer apply.',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining('Upgrade order: lodash first'),
            findsWidgets,
          );
          expect(find.text('Stop agent'), findsNothing);
          expect(find.text('Send to agent'), findsNothing);
          await shots.capture(tester, 'finished-while-open');

          reply.emit(const ReplyCompleted('Both agents reported.'));
          await runFrames(tester);
          reply.finish();
          await runFrames(tester);
        },
      );
    }
  }

  // Where the inspector overlays the chat, Escape goes back from the detail
  // first and closes the inspector only from the list.
  platformTest(
    'a narrow Mac window: Escape goes back before the inspector '
    'closes',
    TargetPlatform.macOS,
    (tester) async {
      final shots = ScreenshotRecorder('subagent-control-desktop-narrow');
      await pumpChat(
        tester,
        shots,
        size: const Size(940, 800),
        platform: TargetPlatform.macOS,
        brightness: Brightness.light,
      );
      final reply = await startReply(tester);
      await startAgents(tester, reply);
      await openActivity(tester, phone: false);
      expect(find.byKey(const Key('inspector-barrier')), findsOneWidget);
      await openAgentFromPanel(tester, _audit);
      expect(find.text('Recent output'), findsOneWidget);
      await shots.capture(tester, 'overlay-detail');

      await leaveDetail(tester, phone: false);
      expect(find.text('Recent output'), findsNothing);
      expect(
        find.byType(BoundActivityPanel),
        findsOneWidget,
        reason: 'the first Escape only leaves the detail',
      );
      expect(inPanel(find.text(_audit)), findsOneWidget);

      await leaveDetail(tester, phone: false);
      expect(find.byType(BoundActivityPanel), findsNothing);

      reply.emit(const ReplyCompleted('Both agents reported.'));
      await runFrames(tester);
      reply.finish();
      await runFrames(tester);
    },
  );

  platformTest(
    'a phone sheet grows when a row opens a detail',
    TargetPlatform.iOS,
    (tester) async {
      final shots = ScreenshotRecorder('subagent-control-phone-sheet');
      await pumpChat(
        tester,
        shots,
        size: phoneSize,
        platform: TargetPlatform.iOS,
        brightness: Brightness.light,
      );
      final reply = await startReply(tester);
      await startAgents(tester, reply);
      await openActivity(tester, phone: true);
      final before = tester.getSize(find.byType(BoundActivityPanel)).height;
      expect(before, lessThan(phoneSize.height * 0.7));
      await openAgentFromPanel(tester, _audit);
      expect(
        tester.getSize(find.byType(BoundActivityPanel)).height,
        greaterThan(phoneSize.height * 0.85),
      );
      reply.emit(const ReplyCompleted('Both agents reported.'));
      await runFrames(tester);
      reply.finish();
      await runFrames(tester);
    },
  );
}
