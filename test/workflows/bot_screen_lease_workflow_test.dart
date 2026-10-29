import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_card.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart';
import 'package:hermes_app/src/bot_screen/widgets/takeover_confirmation.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import '../../widgetbook/bot_screen_fixture.dart';
import '../support/fake_display_server.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_rfb_server.dart';
import '../support/pump_chat.dart';
import '../support/screenshot_recorder.dart';

/// Who holds the bot's screen: the viewer while this device is in control and
/// hands back, and the lease nobody here holds, which the card and the viewer
/// hand back to Hermes after asking.
void main() {
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
        required Future<void> Function(
          ScreenshotRecorder shots,
          FakeDisplayServer display,
          FakeDisplayChannel Function() channel,
        )
        body,
      }) async {
        final shots = ScreenshotRecorder('$flow-$device-$mode');
        await shots.start(tester, size);
        final gateway = FakeGateway()..activeSessions = {};
        var connects = 0;
        final display = FakeDisplayServer(gateway, connection: () => connects);
        gateway.handlers['display.thumbnail'] = (_) => {
          'data_url':
              'data:image/png;base64,${base64Encode(botScreenFixturePng())}',
        };
        gateway.handlers['session.resume'] = (params) => {
          'session_id': 'rt-1',
          'stored_session_id': params['session_id'],
          'session_key': params['session_id'],
        };
        final transport = HermesGatewayTransport(
          connect: () {
            connects++;
            return gateway.connect();
          },
        );
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
        late FakeDisplayChannel channel;
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
              channel = display.openStream(ticket),
        );
        await openThread(tester, 'Book a table');
        await tester.tap(find.byKey(const Key('header-activity')));
        await tester.pump(const Duration(milliseconds: 500));
        await _settle(tester);
        await tester.pumpAndSettle();
        await body(shots, display, () => channel);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(transport.close);
        await tester.pump(const Duration(seconds: 1));
      }

      Future<void> serve(
        WidgetTester tester,
        FakeDisplayChannel channel,
      ) async {
        for (final part in rfbHandshake(320, 200)) {
          channel.serverSend(part);
          await _settle(tester);
        }
        channel.serverSend(desktop(320, 200));
        await _settle(tester);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      }

      testWidgets('taking over and using the screen ($device, $mode)', (
        tester,
      ) async {
        await run(
          tester,
          flow: 'bot-screen-takeover',
          body: (shots, display, channel) async {
            await tester.tap(find.byTooltip('Enlarge screen'));
            await _settle(tester);
            await tester.pump(const Duration(milliseconds: 500));
            await serve(tester, channel());
            expect(find.text('Take over'), findsOneWidget);
            await shots.capture(tester, 'watching');

            await tester.tap(find.text('Take over'));
            await tester.pumpAndSettle();
            expect(find.text('Take over the screen?'), findsOneWidget);
            await shots.capture(tester, 'question');

            await tester.tap(
              find.descendant(
                of: find.byType(TakeoverConfirmation),
                matching: find.text('Take over'),
              ),
            );
            await tester.pumpAndSettle();
            await _settle(tester);
            expect(find.text("You're in control"), findsWidgets);
            expect(display.holder, 'human');
            await shots.capture(tester, 'in-control');

            if (phone) {
              await tester.tap(find.byTooltip('Keyboard'));
              await tester.pump();
              tester.testTextInput.enterText('\u200b481');
              await tester.pump();
              await tester.ensureVisible(find.byTooltip('Use Trackpad mode'));
              await tester.tap(find.byTooltip('Use Trackpad mode'));
              await tester.pump();
              await shots.capture(tester, 'trackpad');
            }

            await tester.tap(find.text('Hand Back'));
            await _settle(tester);
            expect(display.holder, 'agent');
            await shots.capture(tester, 'handed-back');
          },
        );
      });

      testWidgets('in control, then handing back ($device, $mode)', (
        tester,
      ) async {
        await run(
          tester,
          flow: 'bot-screen-lease-in-control',
          body: (shots, display, channel) async {
            await tester.tap(find.byTooltip('Enlarge screen'));
            await _settle(tester);
            await serve(tester, channel());
            display.takeBy(display.mintedIds.single);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(seconds: 4));
            await _settle(tester);

            expect(find.text("You're in control"), findsWidgets);
            await shots.capture(tester, 'in-control');

            await tester.tap(find.text('Hand Back'));
            await _settle(tester);
            await tester.pump(const Duration(milliseconds: 100));

            expect(find.text('Hermes is in control'), findsWidgets);
            expect(display.holder, 'agent');
            await shots.capture(tester, 'handed-back');
          },
        );
      });

      testWidgets('a lease nobody here holds goes back to Hermes ($device, '
          '$mode)', (tester) async {
        await run(
          tester,
          flow: 'bot-screen-lease-force',
          body: (shots, display, channel) async {
            display.takeBy('held-before-the-app-restarted');
            await tester.pump(const Duration(seconds: 4));
            await _settle(tester);

            expect(find.text('Hand back to Hermes'), findsOneWidget);
            await shots.capture(tester, 'card');

            await tester.tap(find.text('Hand back to Hermes'));
            await tester.pumpAndSettle();
            expect(find.text('Hand control back to Hermes?'), findsOneWidget);
            await shots.capture(tester, 'confirm');
            await tester.tap(find.widgetWithText(AppDialogAction, 'Hand Back'));
            await tester.pumpAndSettle();
            await _settle(tester);

            expect(display.holder, 'agent');
            expect(find.byType(BotScreenCard), findsOneWidget);
            expect(find.text('Hand back to Hermes'), findsNothing);
            await shots.capture(tester, 'handed-back');

            await tester.tap(find.byTooltip('Enlarge screen'));
            await _settle(tester);
            await serve(tester, channel());
            expect(find.byType(BotScreenViewerView), findsOneWidget);
            await shots.capture(tester, 'viewer');
          },
        );
      });
    }
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
