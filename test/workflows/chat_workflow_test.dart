import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

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
      ..on('GET', '/api/sessions/s4/messages', messageListBody('s4', []));
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
      transport: transport,
    ),
    size: size,
    brightness: brightness,
  );

  Future<void> openSidebarThread(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('thread-$id')));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(EditableText), text);
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
}
