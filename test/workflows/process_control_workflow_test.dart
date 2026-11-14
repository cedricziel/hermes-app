import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/find_app_icon.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

// Invented program and output.
const _command = 'npm run dev -- --host 127.0.0.1 --port 5173';
const _output =
    '> web@0.4.2 dev\n'
    '> vite --host 127.0.0.1 --port 5173\n'
    '\n'
    '  VITE v5.2.8  ready in 412 ms\n'
    '  -> Local:   http://127.0.0.1:5173/\n';

/// A transport that holds the chat's session, as the gateway does once a
/// reply attached it, so program frames reach the chat's cards.
class _OwnedTransport extends FakeChatTransport
    implements OwnedSessionTransport {
  final binding = OwnedSessionBinding(
    connection: Object(),
    runtimeId: 'rt-1',
    profile: null,
  );
  final _changes = StreamController<OwnedSessionChange>.broadcast(sync: true);

  @override
  Stream<OwnedSessionChange> get ownedSessions => _changes.stream;

  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      threadId == 's1' ? binding : null;

  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async => throw StateError('not read here');

  @override
  Future<void> close() async {
    await _changes.close();
    await super.close();
  }
}

/// A background program in the Activity panel on a phone and on a Mac: a
/// frame starts it, the program list names it, and Stop program stops it
/// after a confirmation.
void main() {
  late FakeHermesServer server;
  late _OwnedTransport transport;

  /// What the fake `process.list` answers.
  late Map<String, Map<String, Object?>> programs;

  setUp(() {
    programs = {};
    transport = _OwnedTransport()
      ..agentAnswer = (call) {
        switch (call.method) {
          case 'process.list':
            return {'processes': programs.values.toList()};
          case 'process.kill':
            final id = call.params['process_id']! as String;
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
            };
          case 'subagent.list':
            return {'subagents': <Object?>[], 'delegations': <Object?>[]};
        }
        return <String, Object?>{};
      };
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Web preview', lastActive: 1780000900),
        ]),
      )
      ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []));
  });

  tearDown(() => transport.close());

  Finder inPanel(Finder finder) =>
      find.descendant(of: find.byType(BoundActivityPanel), matching: finder);

  Finder inDialog(String text) => find.descendant(
    of: find.byType(AppAlertDialog),
    matching: find.text(text),
  );

  Finder stopButton() => find.descendant(
    of: find.byType(DestructiveTintButton),
    matching: find.text('Stop program'),
  );

  List<FakeAgentCall> kills() => [
    for (final call in transport.agentActions)
      if (call.method == 'process.kill') call,
  ];

  /// Settles a dialog or a disclosure's animation before a capture.
  Future<void> settleMotion(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

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

  for (final (name, size, platform, dark) in [
    ('phone', phoneSize, TargetPlatform.iOS, false),
    ('phone-android', phoneSize, TargetPlatform.android, false),
    ('desktop', desktopSize, TargetPlatform.macOS, false),
    ('desktop', desktopSize, TargetPlatform.macOS, true),
  ]) {
    final phone = name.startsWith('phone');
    final mode = dark ? 'dark' : 'light';
    platformTest(
      '$name ($mode): a program is named by the list and stopped',
      platform,
      (tester) async {
        final shots = ScreenshotRecorder('process-control-$name-$mode');
        await pumpScreen(
          tester,
          shots,
          ChatScreen(
            repository: HermesChatRepository(server.client().raw),
            transport: transport,
          ),
          size: size,
          brightness: dark ? Brightness.dark : Brightness.light,
          platform: platform,
        );
        if (find.byKey(const ValueKey('thread-s1')).evaluate().isEmpty) {
          await openSidebar(tester);
        }
        await tester.tap(find.byKey(const ValueKey('thread-s1')).first);
        await tester.pumpAndSettle();
        await tester.enterText(composerField, 'Start the web preview.');
        await tester.pump();
        await tester.tap(findAppIcon(AppIcons.sendArrow));
        await runFrames(tester);
        final reply = transport.sends.single;
        reply.emit(const ReplyStarted());
        await tester.pump();

        // The agent starts the dev server: its output arrives as a frame,
        // and the program list names it.
        programs['proc_web'] = {
          'session_id': 'proc_web',
          'command': _command,
          'status': 'running',
          'uptime_seconds': 18,
          'output_tail': _output,
        };
        reply.emit(
          ProcessOutputReceived(
            const ProcessOutputUpdate('proc_web', chunk: _output),
            runtimeId: transport.binding.runtimeId,
            connection: transport.binding.connection,
          ),
        );
        await runFrames(tester);

        await tester.tap(
          phone
              ? find.byKey(const Key('header-activity'))
              : find.byTooltip('Show Inspector ⌥⌘I'),
        );
        await runFrames(tester);
        expect(find.byType(BoundActivityPanel), findsOneWidget);
        expect(
          transport.agentReads.where((c) => c.method == 'process.list'),
          isNotEmpty,
        );
        expect(inPanel(find.text(_command)), findsOneWidget);
        expect(inPanel(find.textContaining('Running')), findsOneWidget);

        await tester.tap(inPanel(find.byType(ProcessOutputCard)));
        await runFrames(tester);
        await settleMotion(tester);
        // The card from its command down to Stop program, all in view: the
        // sheet scrolls to the card's top when Stop alone would cut it.
        await tester.ensureVisible(stopButton());
        await settleMotion(tester);
        await tester.ensureVisible(inPanel(find.text(_command)));
        await settleMotion(tester);
        expect(stopButton(), findsOneWidget);
        final screen = Offset.zero & size;
        final header = tester.getRect(
          find
              .descendant(
                of: find.byType(BoundActivityPanel),
                matching: find.text('Activity'),
              )
              .first,
        );
        final command = tester.getRect(inPanel(find.text(_command)));
        expect(command.top, greaterThanOrEqualTo(header.bottom));
        expect(
          screen.contains(tester.getRect(stopButton()).bottomRight),
          isTrue,
        );
        await shots.capture(tester, 'program-running');

        await tester.tap(stopButton());
        await settleMotion(tester);
        expect(inDialog('Stop this program?'), findsOneWidget);
        expect(kills(), isEmpty, reason: 'only asked');
        await shots.capture(tester, 'stop-confirmation');

        await tester.tap(inDialog('Stop program'));
        await runFrames(tester);
        await settleMotion(tester);
        expect(kills(), hasLength(1));
        expect(kills().single.params['process_id'], 'proc_web');
        expect(kills().single.threadId, 's1');
        expect(inPanel(find.text('Stopped')), findsWidgets);
        expect(stopButton(), findsNothing);
        await shots.capture(tester, 'stopped');

        reply.emit(const ReplyCompleted('The preview is stopped.'));
        await runFrames(tester);
        reply.finish();
        await runFrames(tester);
      },
    );
  }
}
