import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'a busy iPhone conversation keeps its transcript clear (${dark ? 'dark' : 'light'})',
      (tester) async {
        final shots = ScreenshotRecorder(
          'compact-chat-${dark ? 'dark' : 'light'}',
        );
        await shots.start(tester, phoneSize);
        final transport = FakeChatTransport();
        final server = FakeHermesServer()
          ..on(
            'GET',
            '/api/sessions',
            sessionListBody([sessionRow(id: 'busy', title: 'Sign-in help')]),
          )
          ..on(
            'GET',
            '/api/sessions/busy/messages',
            messageListBody('busy', []),
          );
        await pumpChatScreen(
          tester,
          server: server,
          transport: transport,
          size: phoneSize,
          platform: TargetPlatform.iOS,
          wrap: shots.frame,
          theme: withScreenshotFont(
            dark
                ? buildHermesDarkTheme(platform: TargetPlatform.iOS)
                : buildHermesLightTheme(platform: TargetPlatform.iOS),
          ),
        );
        await openThread(tester, 'Sign-in help');
        await tester.enterText(composerField, 'Check the sign-in status');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Send'));
        await tester.pump();
        final reply = transport.sends.single;
        reply
          ..emit(
            const ReplyDelta(
              'I’m checking the sign-in status. You can keep typing while I work.',
            ),
          )
          ..emit(
            const SessionWaitUpdated(
              'lifecycle',
              'Background Process Finished: check sign-in status',
              runtimeId: 'runtime',
            ),
          );
        await tester.pump();
        await tester.enterText(composerField, 'Done!');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Send'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('1 queued · Done!'), findsOneWidget);
        expect(find.text('Hermes is replying…'), findsNothing);
        expect(
          find.textContaining('Background Process Finished'),
          findsNothing,
        );
        expect(find.byKey(const Key('chat-activity-strip')), findsNothing);
        expect(find.bySemanticsLabel('Stop response'), findsOneWidget);
        expect(tester.getSize(find.byType(ChatComposer)).height, lessThan(210));
        await shots.capture(tester, 'compact');
        await tester.tap(find.text('1 queued · Done!'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byTooltip('Remove from queue'), findsOneWidget);
        await shots.capture(tester, 'queue-expanded');
        await tester.tap(find.text('1 queued · Done!'));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.byKey(const Key('header-activity')));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          find.textContaining('Background Process Finished'),
          findsOneWidget,
        );
        await shots.capture(tester, 'activity');
        reply
          ..emit(const ReplyCompleted('The sign-in is ready.'))
          ..finish();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
