import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/viewer/bot_screen_viewer.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../../widgetbook/bot_screen_fixture.dart';
import '../bot_screen/bot_screen_repository_test.dart' show statusJson;
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_rfb_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';

/// The live viewer opened from the Bot screen card: as a full-window layer on
/// a Mac-sized window and as a full-screen page on a phone, live and with the
/// screen stopped.
void main() {
  /// An invented desktop in RFB Raw rectangles: a wallpaper, a window with a
  /// title bar and a few lines, and a panel.
  Uint8List desktop(int w, int h) => rfbUpdate([
    rfbRawRect(0, 0, w, h, [0x22, 0x40, 0x90]),
    rfbRawRect(w ~/ 8, h ~/ 8, w * 3 ~/ 4, h * 3 ~/ 4, [0xf2, 0xe9, 0xe4]),
    rfbRawRect(w ~/ 8, h ~/ 8, w * 3 ~/ 4, h ~/ 12, [0x4a, 0x4e, 0x69]),
    for (var i = 0; i < 6; i++)
      rfbRawRect(w ~/ 6, h ~/ 3 + i * (h ~/ 12), w ~/ 2, h ~/ 40, [
        0x9a,
        0x8c,
        0x98,
      ]),
    rfbRawRect(0, h - h ~/ 14, w, h ~/ 14, [0x2b, 0x2d, 0x42]),
  ]);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    for (final phone in [false, true]) {
      final size = phone ? phoneSize : desktopSize;
      final platform = phone ? TargetPlatform.iOS : TargetPlatform.linux;
      final device = phone ? 'phone' : 'desktop';

      Future<void> run(
        WidgetTester tester, {
        required String flow,
        required bool stopsOnObserve,
        required Future<void> Function(
          ScreenshotRecorder shots,
          FakeDisplayChannel? channel,
        )
        check,
      }) async {
        final shots = ScreenshotRecorder('$flow-$device-$mode');
        await shots.start(tester, size);
        var stopped = false;
        FakeDisplayChannel? channel;
        final gateway = FakeGateway()..activeSessions = {};
        gateway.handlers['display.status'] = (_) =>
            statusJson(running: !stopped);
        gateway.handlers['display.thumbnail'] = (_) => {
          'data_url':
              'data:image/png;base64,${base64Encode(botScreenFixturePng())}',
        };
        gateway.handlers['display.start'] = (_) {
          stopped = false;
          return statusJson();
        };
        gateway.handlers['display.observe'] = (_) {
          if (stopsOnObserve) {
            stopped = true;
            throw const FakeRpcError(5300, 'not running');
          }
          return {
            'ticket': 'ticket',
            'path': '/api/display/ws',
            'viewer_id': 'viewer',
            ...statusJson(),
          };
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
          displaySocketOpener: (path, ticket) async =>
              channel = FakeDisplayChannel(),
        );
        await openThread(tester, 'Book a table');
        await tester.tap(find.byKey(const Key('header-activity')));
        await tester.pump(const Duration(milliseconds: 500));
        Future<void> settle() async {
          for (var i = 0; i < 4; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 40)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Enlarge screen'));
        await settle();
        await check(shots, channel);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(transport.close);
        await tester.pump(const Duration(seconds: 1));
      }

      testWidgets('watching the screen live ($device, $mode)', (tester) async {
        await run(
          tester,
          flow: 'bot-screen-viewer-live',
          stopsOnObserve: false,
          check: (shots, channel) async {
            for (final part in rfbHandshake(320, 200)) {
              channel!.serverSend(part);
              await settle(tester);
            }
            channel!.serverSend(desktop(320, 200));
            await settle(tester);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 200)),
            );
            await tester.pump(const Duration(milliseconds: 100));
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              find.descendant(
                of: find.byType(FramebufferPicture),
                matching: find.byType(RawImage),
              ),
              findsOneWidget,
            );
            await shots.capture(tester, 'live');
            if (!phone) {
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pump(const Duration(milliseconds: 100));
              expect(find.byType(BotScreenViewer), findsNothing);
              expect(find.byType(BotScreenCard), findsOneWidget);
            }
          },
        );
      });

      testWidgets('the screen stopped while opening it ($device, $mode)', (
        tester,
      ) async {
        await run(
          tester,
          flow: 'bot-screen-viewer-off',
          stopsOnObserve: true,
          check: (shots, channel) async {
            expect(find.text('The screen is off'), findsOneWidget);
            expect(find.text('Start Screen'), findsWidgets);
            await shots.capture(tester, 'off');
          },
        );
      });
    }
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}
