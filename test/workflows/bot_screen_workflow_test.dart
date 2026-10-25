import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../../widgetbook/bot_screen_fixture.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';
import '../bot_screen/bot_screen_repository_test.dart' show statusJson;

/// The Bot screen card in the chat's Activity panel, on a Mac-sized window
/// and as a phone sheet: what the agent's desktop shows, and the card of a
/// chat that used the screen while it is off.
void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final phone in [false, true]) {
      final size = phone ? phoneSize : desktopSize;
      final platform = phone ? TargetPlatform.iOS : TargetPlatform.linux;
      final device = phone ? 'phone' : 'desktop';

      Future<void> run(
        WidgetTester tester, {
        required String flow,
        required bool running,
        required bool usedScreen,
        required Future<void> Function(ScreenshotRecorder shots) check,
      }) async {
        final shots = ScreenshotRecorder('$flow-$device-$mode');
        await shots.start(tester, size);
        final gateway = FakeGateway()..activeSessions = {};
        gateway.handlers['display.status'] = (_) =>
            statusJson(running: running);
        gateway.handlers['display.start'] = (_) => statusJson();
        gateway.handlers['display.thumbnail'] = (_) => {
          'data_url':
              'data:image/png;base64,${base64Encode(botScreenFixturePng())}',
        };
        gateway.handlers['session.resume'] = (params) => {
          'session_id': 'rt-1',
          'stored_session_id': params['session_id'],
          'session_key': params['session_id'],
        };
        final transport = HermesGatewayTransport(connect: gateway.connect);
        final server = FakeHermesServer()
          ..on(
            'GET',
            '/api/sessions',
            sessionListBody([
              sessionRow(id: 'stored-1', title: 'Book a table'),
            ]),
          )
          ..on(
            'GET',
            '/api/sessions/stored-1/messages',
            messageListBody('stored-1', [
              messageRow(id: 1, role: 'user', content: 'Book a table for two'),
              messageRow(
                id: 2,
                role: 'assistant',
                content: 'I opened the booking page.',
                toolCalls: usedScreen
                    ? [functionCall('computer_use', '{"action":"screenshot"}')]
                    : null,
              ),
            ]),
          );
        await pumpChatScreen(
          tester,
          server: server,
          transport: transport,
          size: size,
          platform: platform,
          theme: withScreenshotFont(
            dark
                ? buildHermesDarkTheme(platform: platform)
                : buildHermesLightTheme(platform: platform),
          ),
          wrap: shots.frame,
        );
        await openThread(tester, 'Book a table');
        await tester.tap(find.byKey(const Key('header-activity')));
        await tester.pump(const Duration(milliseconds: 500));
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump();
        }
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await check(shots);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(transport.close);
        await tester.pump(const Duration(seconds: 1));
      }

      testWidgets('the running screen in the activity panel ($device, $mode)', (
        tester,
      ) async {
        await run(
          tester,
          flow: 'bot-screen-running',
          running: true,
          usedScreen: false,
          check: (shots) async {
            expect(find.byType(BotScreenCard), findsOneWidget);
            expect(find.text('Hermes is in control'), findsOneWidget);
            expect(find.byType(Image), findsWidgets);
            await shots.capture(tester, 'card');
          },
        );
      });

      testWidgets('a stopped screen in the activity panel ($device, $mode)', (
        tester,
      ) async {
        await run(
          tester,
          flow: 'bot-screen-off',
          running: false,
          usedScreen: true,
          check: (shots) async {
            expect(find.text('Start Screen'), findsOneWidget);
            await shots.capture(tester, 'card');
          },
        );
      });
    }
  }
}
