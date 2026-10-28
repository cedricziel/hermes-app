import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_preview.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../../widgetbook/bot_screen_fixture.dart';
import '../bot_screen/bot_screen_repository_test.dart' show statusJson;
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';

/// The Bot screen's still preview in the transcript while a reply drives the
/// screen: under a single call's card, under a folded group's header, and the
/// Activity panel a tap opens.
void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final phone in [false, true]) {
      final size = phone ? phoneSize : desktopSize;
      final platform = phone ? TargetPlatform.iOS : TargetPlatform.linux;
      final device = phone ? 'phone' : 'desktop';

      testWidgets('the preview in the transcript ($device, $mode)', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('bot-screen-preview-$device-$mode');
        await shots.start(tester, size);
        final gateway = FakeGateway()..activeSessions = {};
        gateway.handlers['display.status'] = (_) => statusJson();
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
              messageRow(id: 1, role: 'user', content: 'Hello'),
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

        Future<void> settle() async {
          for (var i = 0; i < 3; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 40)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        void emit(String type, [Map<String, Object?> payload = const {}]) =>
            gateway.event(type, gateway.lastSessionId, payload);

        Map<String, Object?> call(String id, String context) => {
          'tool_id': id,
          'name': 'computer_use',
          'context': context,
          'args': {'action': context},
        };

        await tester.enterText(composerField, 'Book a table for two');
        await tester.pump();
        await tester.tap(find.byTooltip('Send'));
        await tester.pump();
        await settle();
        emit('message.start');
        emit('tool.start', call('c1', 'screenshot'));
        await settle();

        expect(find.byType(BotScreenPreview), findsOneWidget);
        expect(find.text('Live'), findsOneWidget);
        await shots.capture(tester, 'single-call');

        emit('tool.complete', {
          'tool_id': 'c1',
          'name': 'computer_use',
          'result': {'ok': true},
          'duration_s': 0.4,
        });
        emit('tool.start', call('c2', 'click'));
        await settle();

        expect(find.byType(BotScreenPreview), findsOneWidget);
        await shots.capture(tester, 'folded-group');

        await tester.tap(find.byType(BotScreenPreview));
        await tester.pump(const Duration(milliseconds: 500));
        await settle();

        expect(find.byType(BotScreenCard), findsOneWidget);
        await shots.capture(tester, 'panel-opened');

        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(transport.close);
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
