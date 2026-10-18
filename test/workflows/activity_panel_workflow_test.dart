import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/widgets/activity_panel.dart';
import 'package:hermes_app/src/chat/chat_session_state.dart';
import 'package:hermes_app/src/chat/memory/memory_activity_card.dart';
import 'package:hermes_app/src/chat/memory/memory_recall.dart';
import 'package:hermes_app/src/chat/chat_warning_state.dart';
import 'package:hermes_app/src/chat/side_results/side_result_card.dart';
import 'package:hermes_app/src/chat/side_results/side_result_state.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_card.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_state.dart';
import 'package:hermes_app/src/chat/widgets/agent_notice_card.dart';
import 'package:hermes_app/src/chat/widgets/session_status_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/inspector_layout.dart';

import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';

TodoPlanState _plan() {
  final scope = TodoScope(
    connection: Object(),
    runtimeId: 'fixture',
    profile: null,
  );
  return TodoPlanState()
    ..adopt(scope)
    ..updated(scope, {
      'revision': 1,
      'todos': [
        {
          'id': 'a',
          'content': "Define the agent's role",
          'status': 'completed',
        },
        {
          'id': 'b',
          'content': 'List the agents it oversees',
          'status': 'completed',
        },
        {
          'id': 'c',
          'content': 'Draft the daily brief',
          'status': 'in_progress',
        },
        {'id': 'd', 'content': 'Schedule the brief', 'status': 'pending'},
      ],
    });
}

ActivityPanel _panel({VoidCallback? onClose}) => ActivityPanel(
  onClose: onClose,
  now: [
    SessionStatusCard(
      state: ChatSessionState()
        ..waits['process'] = 'Waiting for a background process',
    ),
  ],
  plan: TodoPlanCard(state: _plan(), initiallyOpen: true),
  session: const [
    SideResultCard(
      result: SideResult(
        kind: SideResultKind.btw,
        taskId: 'fixture',
        question: 'What does a chief of staff agent do?',
        text: 'It reads what other agents produce and brings you decisions.',
      ),
    ),
    AgentNoticeCard(notice: AgentNotice(text: 'Capabilities refreshed.')),
  ],
);

/// Stands in for the chat beside the inspector or under the sheet.
Widget _chat(BuildContext context) => ColoredBox(
  color: Theme.of(context).scaffoldBackgroundColor,
  child: const Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text('Understanding chief of staff agents'),
    ),
  ),
);

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    ThemeData theme(TargetPlatform platform) => withScreenshotFont(
      dark
          ? buildHermesDarkTheme(platform: platform)
          : buildHermesLightTheme(platform: platform),
    );

    for (final phone in [true, false]) {
      testWidgets(
        'memory recall in ${phone ? 'phone sheet' : 'inspector'} ($mode)',
        (tester) async {
          final shots = ScreenshotRecorder(
            'memory-inspector-${phone ? 'phone' : 'desktop'}-$mode',
          );
          await shots.start(tester, phone ? phoneSize : desktopSize);
          final panel = ActivityPanel(
            session: [
              MemoryActivityCard(
                initiallyOpen: true,
                recalls: [
                  MemoryRecall(
                    summary: 'robot-notes — recalled 5 memories',
                    receivedAt: DateTime(2030, 1, 1, 9, 41),
                  ),
                ],
                reviewNotes: const ['Memory updated'],
              ),
            ],
          );
          await tester.pumpWidget(
            shots.frame(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme(phone ? TargetPlatform.iOS : TargetPlatform.macOS),
                home: Scaffold(
                  body: phone
                      ? Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(height: 520, child: panel),
                        )
                      : InspectorLayout(
                          content: Builder(builder: _chat),
                          shown: true,
                          inspector: panel,
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('NOW'), findsNothing);
          expect(find.text('THIS SESSION'), findsOneWidget);
          expect(
            find.textContaining('did not include the note titles'),
            findsOneWidget,
          );
          await shots.capture(tester, 'memory-expanded');
        },
      );
    }

    testWidgets('chat screen with the activity inspector ($mode)', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('activity-chat-desktop-$mode');
      await shots.start(tester, desktopSize);
      await pumpChatScreen(
        tester,
        size: desktopSize,
        theme: theme(TargetPlatform.linux),
        wrap: shots.frame,
      );
      await openThread(tester, "Summarize last night's run logs");
      await tester.tap(find.byKey(const Key('header-activity')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activity-inspector')), findsOneWidget);
      await shots.capture(tester, 'inspector-open');
    });

    testWidgets('chat screen with the activity sheet ($mode)', (tester) async {
      final shots = ScreenshotRecorder('activity-chat-phone-$mode');
      await shots.start(tester, phoneSize);
      await pumpChatScreen(
        tester,
        size: phoneSize,
        platform: TargetPlatform.iOS,
        theme: theme(TargetPlatform.iOS),
        wrap: shots.frame,
      );
      await openThread(tester, "Summarize last night's run logs");
      await tester.tap(find.byKey(const Key('header-activity')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activity-close')), findsOneWidget);
      await shots.capture(tester, 'sheet-open');
    });

    testWidgets('activity inspector on a desktop window ($mode)', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('activity-panel-desktop-$mode');
      await shots.start(tester, desktopSize);
      await tester.pumpWidget(
        shots.frame(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme(TargetPlatform.macOS),
            home: Scaffold(
              body: Builder(
                builder: (context) => InspectorLayout(
                  content: _chat(context),
                  shown: true,
                  inspector: _panel(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NOW'), findsOneWidget);
      expect(find.text('PLAN'), findsOneWidget);
      expect(find.text('THIS SESSION'), findsOneWidget);
      await shots.capture(tester, 'inspector');
    });

    testWidgets('activity sheet on a phone ($mode)', (tester) async {
      final shots = ScreenshotRecorder('activity-panel-phone-$mode');
      await shots.start(tester, phoneSize);
      await tester.pumpWidget(
        shots.frame(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme(TargetPlatform.iOS),
            home: Scaffold(
              body: Builder(
                builder: (context) => Stack(
                  children: [
                    Positioned.fill(child: _chat(context)),
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0x66000000)),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: phoneSize.height * 0.6,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        clipBehavior: Clip.antiAlias,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: _panel(onClose: () {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activity-close')), findsOneWidget);
      await shots.capture(tester, 'sheet');
    });
  }
}
