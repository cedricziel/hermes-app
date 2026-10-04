import 'package:hermes_app/src/macos/mac_sidebar.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/starter_context_loader.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';

import '../support/cron_fixtures.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/kanban_fixtures.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';
import '../support/pump_chat.dart';

const _longTitle =
    'Why did the nightly backup of the analytics warehouse fail on the '
    'staging cluster after the certificate rotation?';

const _unbroken =
    'https://staging.example.internal/api/v2/jobs/2f9d6c1e-7a4b-4c1f-9e0d-'
    '5b7a1c3e8f42/artifacts/nightly-backup-analytics-warehouse-2026-09-19.tar.zst';

/// A conversation on a phone and on a desktop: reading history, sending a
/// message, and answering what the agent asks along the way.
void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on('GET', '/api/cron/jobs', [
        cronJobRow(
          name: 'Nightly backup',
          lastRunAt: '2026-09-27T03:00:00Z',
          lastStatus: 'error',
        ),
      ])
      ..on('GET', '/api/dashboard/plugins', [
        {'name': 'kanban'},
      ])
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody([
          kanbanTaskRow(
            id: 't1',
            title: 'Rotate the staging certificates',
            status: 'blocked',
          ),
        ]),
      )
      ..on('GET', '/api/skills', [skillRow(name: 'release-notes', usage: 7)])
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(
            id: 's1',
            title: 'Backup failure',
            lastActive: 1780000900,
            pinned: true,
          ),
          sessionRow(id: 's2', title: _longTitle, lastActive: 1780000600),
          sessionRow(id: 's3', title: 'Release notes', lastActive: 1780000100),
          sessionRow(id: 's4', title: null, preview: null),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(
            id: 1,
            role: 'user',
            content: 'Why did the nightly backup fail?',
          ),
          messageRow(
            id: 2,
            role: 'assistant',
            content:
                'I checked the logs. The job died at **02:14** with a '
                'connection reset.\n\n'
                '- The TLS certificate was rotated at 02:10\n'
                '- The backup agent still pinned the old one\n'
                '- Retries all failed with the same error\n\n'
                '```\nERROR  02:14:07  connection reset by peer\n'
                'ERROR  02:14:09  retry 1/3 failed: x509: certificate '
                'signed by unknown authority (possibly because of '
                '"crypto/rsa: verification error")\n```\n\n'
                'Artifact: $_unbroken',
            toolCalls: [
              functionCall('search_logs', '{"query":"02:14","limit":50}'),
              functionCall('read_file', '{"path":"/etc/backup/agent.toml"}'),
            ],
          ),
          messageRow(
            id: 3,
            role: 'user',
            content: 'Can you re-pin the certificate and run it again?',
          ),
        ]),
      )
      ..on('GET', '/api/sessions/s2/messages', messageListBody('s2', []))
      ..on('GET', '/api/sessions/s3/messages', messageListBody('s3', []))
      ..on('GET', '/api/sessions/s4/messages', messageListBody('s4', []))
      ..on('GET', '/api/model/options', {
        'model': 'claude-opus-4',
        'provider': 'anthropic',
        'providers': [
          {
            'slug': 'anthropic',
            'name': 'Anthropic',
            'models': [
              'claude-opus-4',
              'claude-sonnet-4-5',
              'claude-haiku-4-5',
            ],
            'capabilities': {
              'claude-opus-4': {
                'reasoning': true,
                'can_disable_reasoning': true,
              },
              'claude-haiku-4-5': {'reasoning': false},
            },
          },
          {
            'slug': 'openrouter',
            'name': 'OpenRouter',
            'models': ['openai/gpt-5.1', 'meta-llama/llama-4-maverick'],
          },
        ],
      });
  });

  Future<void> pumpChat(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
  }) => pumpScreen(
    tester,
    shots,
    ChatScreen(
      repository: HermesChatRepository(server.client().raw),
      models: HermesModelsRepository(server.client().raw),
      transport: transport,
      starterContext: StarterContextLoader(HermesRepositories(server.client())),
    ),
    size: size,
    brightness: brightness,
  );

  Future<void> openSidebarThread(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('thread-$id')));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(composerField, text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await runFrames(tester);
  }

  /// Feeds [event] to [reply]. Pass `settle: false` when nothing is captured
  /// before the next event, to skip the frame-by-frame wait.
  Future<void> emit(
    WidgetTester tester,
    FakeSend reply,
    ChatEvent event, {
    bool settle = true,
  }) async {
    reply.emit(event);
    await (settle ? runFrames(tester) : tester.pump());
  }

  /// Opens [threadId], sends [text] and starts the reply.
  Future<FakeSend> startReply(
    WidgetTester tester,
    String threadId,
    String text,
  ) async {
    await openSidebar(tester);
    await openSidebarThread(tester, threadId);
    await send(tester, text);
    final reply = transport.sends.single;
    await emit(tester, reply, const ReplyStarted(), settle: false);
    return reply;
  }

  const approval = ApprovalRequest(
    requestId: 'a1',
    command: 'backup-agent pin-cert --from /etc/ssl/certs/staging-2026-09.pem',
    description: 'Replace the pinned certificate the backup agent trusts',
    choices: ['once', 'session', 'always', 'deny'],
  );

  const clarify = ClarifyRequest(
    requestId: 'c1',
    questions: [
      ClarifyQuestion(
        qid: '',
        question: 'Which cluster should the backup run against?',
        choices: ['staging', 'production', 'both of them, one after the other'],
      ),
    ],
  );

  for (final (name, size) in [('phone', phoneSize), ('desktop', desktopSize)]) {
    testWidgets('$name: read history, send, approve, answer', (tester) async {
      final shots = ScreenshotRecorder('chat-$name');
      await pumpChat(tester, shots, size: size);
      await shots.capture(tester, 'welcome');

      await openSidebar(tester);
      await shots.capture(tester, 'thread-list');

      await openSidebarThread(tester, 's1');
      await shots.capture(tester, 'history');

      await tester.tap(find.byKey(const Key('composer-model-pill')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('effort-medium')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'model-picker');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'model-picked');

      await send(tester, 'Go ahead, but only on staging.');
      await shots.capture(tester, 'sent-thinking');
      final reply = transport.sends.single;

      await emit(tester, reply, const ReplyStarted(), settle: false);
      await emit(
        tester,
        reply,
        const ToolStarted(name: 'read_file', summary: '/etc/backup/agent.toml'),
        settle: false,
      );
      await emit(
        tester,
        reply,
        const ReplyDelta('Re-pinning the certificate on staging first. '),
      );
      await shots.capture(tester, 'tool-running');

      await emit(tester, reply, const ApprovalRequested(approval));
      await shots.capture(tester, 'approval-requested');

      await tester.tap(find.text('Allow once'));
      await tester.pump(const Duration(milliseconds: 300));
      await shots.capture(tester, 'approval-answered');

      await emit(tester, reply, const ClarifyRequested(clarify));
      await shots.capture(tester, 'clarify-requested');

      await emit(tester, reply, ReplyCompleted('Done. The backup ran clean.'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'reply-completed');
    });

    testWidgets('$name: delegated subagents run beside the reply', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('chat-$name-subagents');
      await pumpChat(tester, shots, size: size);
      final reply = await startReply(tester, 's1', 'Offload the batch.');
      await emit(
        tester,
        reply,
        const SubagentUpdated(
          Subagent(
            id: 'agent-1',
            goal: 'Review the PR #412 diff',
            status: SubagentStatus.running,
            lastTool: 'terminal',
            lastToolPreview: 'git diff main..pr-412',
            startedAt: null,
          ),
        ),
        settle: false,
      );
      await emit(
        tester,
        reply,
        const SubagentUpdated(
          Subagent(
            id: 'agent-2',
            goal: 'Update the CHANGELOG and docstrings',
            status: SubagentStatus.running,
            startedAt: null,
          ),
        ),
      );
      await tester.pump();
      await shots.capture(tester, 'subagents-running');

      await emit(
        tester,
        reply,
        const SubagentUpdated(
          Subagent(
            id: 'agent-2',
            goal: '',
            status: SubagentStatus.completed,
            summary: 'CHANGELOG entry added; three docstrings rewritten.',
            duration: Duration(seconds: 127),
            toolCount: 5,
          ),
        ),
      );
      await emit(
        tester,
        reply,
        const SubagentUpdated(
          Subagent(
            id: 'agent-3',
            goal: 'Verify the docstring examples compile',
            parentId: 'agent-2',
            depth: 1,
            status: SubagentStatus.running,
          ),
        ),
      );
      await tester.pump();
      await shots.capture(tester, 'subagents-nested');

      await emit(
        tester,
        reply,
        const SubagentUpdated(
          Subagent(
            id: 'agent-1',
            goal: '',
            status: SubagentStatus.completed,
            summary: 'Two comments, both about the retry guard naming.',
            duration: Duration(seconds: 118),
            toolCount: 9,
          ),
        ),
      );
      await emit(
        tester,
        reply,
        const SubagentUpdated(
          Subagent(
            id: 'agent-3',
            goal: '',
            status: SubagentStatus.failed,
            summary: 'dart pad is not installed on the runner.',
            duration: Duration(seconds: 41),
          ),
        ),
      );
      await emit(tester, reply, const ReplyCompleted('Batch wrapped up.'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'subagents-done');
    });

    testWidgets('$name: a reply that fails', (tester) async {
      final shots = ScreenshotRecorder('chat-$name-failure');
      await pumpChat(tester, shots, size: size);
      final reply = await startReply(tester, 's3', 'Draft the release notes.');
      await emit(
        tester,
        reply,
        const ReplyCompleted(
          'The model is overloaded. Try again.',
          failed: true,
        ),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'failed');
    });

    testWidgets('$name: a reply cut off halfway', (tester) async {
      final shots = ScreenshotRecorder('chat-$name-cut-off');
      await pumpChat(tester, shots, size: size);
      final reply = await startReply(tester, 's3', 'Draft the release notes.');
      await emit(
        tester,
        reply,
        const ReplyDelta(
          'Here is a first draft:\n\n- **Chat:** replies keep their text '
          'when the connection drops\n- **Kanban:** faster board loads\n\n'
          'Shall I add the',
        ),
      );
      await emit(tester, reply, const ReplyCompleted('', failed: true));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'cut-off');
    });

    for (final brightness in Brightness.values) {
      testWidgets('$name: queue prompts while replying (${brightness.name})', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('chat-$name-queue-${brightness.name}');
        await pumpChat(tester, shots, size: size, brightness: brightness);
        final reply = await startReply(tester, 's1', 'Go ahead.');
        await emit(
          tester,
          reply,
          const ReplyDelta('Re-pinning the certificate on staging first. '),
        );
        await send(tester, 'Then run the backup on production too.');
        await send(tester, 'And post the result in #ops.');
        await shots.capture(tester, 'queued');

        await emit(
          tester,
          reply,
          const ReplyCompleted('', stopped: true),
          settle: false,
        );
        reply.finish();
        await runFrames(tester);
        await shots.capture(tester, 'paused');

        await tester.tap(find.text('Send now'));
        await runFrames(tester);
        await shots.capture(tester, 'sent-next');
      });
    }

    testWidgets('$name: dark theme', (tester) async {
      final shots = ScreenshotRecorder('chat-$name-dark');
      await pumpChat(tester, shots, size: size, brightness: Brightness.dark);
      await shots.capture(tester, 'welcome');
      await openSidebar(tester);
      await shots.capture(tester, 'thread-list');
      final reply = await startReply(tester, 's1', 'Go ahead.');
      await emit(tester, reply, const ApprovalRequested(approval));
      await shots.capture(tester, 'approval-requested');
      await emit(tester, reply, const ClarifyRequested(clarify));
      await shots.capture(tester, 'clarify-requested');
    });
  }

  testWidgets('thread actions on a desktop', (tester) async {
    final shots = ScreenshotRecorder('chat-desktop-actions');
    await pumpChat(tester, shots, size: desktopSize);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('thread-s2')),
        matching: find.byTooltip('Chat actions'),
      ),
    );
    await tester.pumpAndSettle();
    await shots.capture(tester, 'menu');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'rename');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.byTooltip('Account'),
      ),
    );
    await tester.pumpAndSettle();
    await shots.capture(tester, 'account-menu');
  });

  testWidgets('search the chats on a desktop', (tester) async {
    server.on('GET', '/api/sessions/search', {
      'results': [
        {
          'session_id': 's2',
          'title': 'Nightly backup',
          'snippet': 'why did the >>>backup<<< fail after the rotation',
          'session_started': 1780000000,
        },
      ],
    });
    final shots = ScreenshotRecorder('chat-desktop-search');
    await pumpChat(tester, shots, size: desktopSize);
    await tester.enterText(
      find.byKey(const Key('thread-search-field')),
      'backup',
    );
    await tester.pump(ThreadSearch.defaultDebounce);
    await tester.pumpAndSettle();
    await shots.capture(tester, 'results');
  });

  testWidgets('the Mac sidebar and toolbar search', (tester) async {
    server.on('GET', '/api/sessions/search', {
      'results': [
        {
          'session_id': 's3',
          'title': 'Release notes',
          'snippet': 'the >>>release<<< goes out on Friday',
          'session_started': 1780000000,
        },
      ],
    });
    for (final (name, width) in [
      ('large', 1160.0),
      ('medium', 900.0),
      ('compact', 680.0),
    ]) {
      final shots = ScreenshotRecorder('chat-mac-$name');
      await pumpScreen(
        tester,
        shots,
        MacSidebarScope(
          child: ChatScreen(
            repository: HermesChatRepository(server.client().raw),
            models: HermesModelsRepository(server.client().raw),
            transport: transport,
          ),
        ),
        size: Size(width, 760),
        platform: TargetPlatform.macOS,
      );
      await shots.capture(tester, 'sidebar');
      if (name == 'compact') {
        await tester.tap(find.byKey(const Key('mac-sidebar-toggle')));
        await tester.pumpAndSettle();
        await shots.capture(tester, 'sidebar-overlay');
        continue;
      }
      await tester.tap(
        find.byKey(const ValueKey('thread-s3')),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'context-menu');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      if (name == 'medium') {
        await tester.tap(find.byKey(const Key('toolbar-search')));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byKey(const Key('toolbar-search-field')),
        'release',
      );
      await tester.pump(ThreadSearch.defaultDebounce);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'search-results');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
