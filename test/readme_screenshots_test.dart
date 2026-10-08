import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/local_dashboard.dart';
import 'support/memory_token_store.dart';
import 'support/screenshot_recorder.dart';
import 'support/workflow_app.dart';

/// Renders the README screenshots from the demo chats in
/// `scripts/demo_sessions.json`, the same ones `scripts/seed_demo_sessions.py`
/// puts into a real dashboard. With `README_SCREENSHOTS=1` the raw images land
/// in `build/screenshots/<device>-<appearance>/`, where
/// `scripts/finish_screenshots.py --readme-only` picks them up; without it the
/// test only checks that every screen still renders.
final _write = Platform.environment['README_SCREENSHOTS'] == '1';

const _openedChat = 'demo-backup-failure';

final _starterPrompt = find.textContaining(
  "Pick up 'Why did last night's backup fail?'",
  findRichText: true,
);

class _Device {
  const _Device(this.name, this.platform, this.size, this.pixelRatio);

  final String name;
  final TargetPlatform platform;
  final Size size;
  final double pixelRatio;

  bool get wide => size.width >= 900;
}

const _devices = [
  _Device('iphone', TargetPlatform.iOS, Size(440, 956), 3),
  _Device('ipad', TargetPlatform.iOS, Size(1032, 1376), 2),
  _Device('mac', TargetPlatform.macOS, Size(1440, 900), 2),
];

Map<String, Object?> _demoRoutes() {
  final demo = jsonDecode(
    File('scripts/demo_sessions.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final now = DateTime.now().millisecondsSinceEpoch / 1000;
  final rows = <Map<String, Object?>>[];
  final routes = <String, Object?>{
    '/api/status': {'auth_required': false, 'version': '0.14.0'},
  };
  for (final session
      in (demo['sessions']! as List).cast<Map<String, Object?>>()) {
    final id = session['id']! as String;
    final messages = (session['messages']! as List)
        .cast<Map<String, Object?>>();
    final last = now - (session['age_seconds']! as num);
    final first = last - 300 * messages.length;
    rows.add(
      sessionRow(
        id: id,
        title: session['title']! as String,
        startedAt: first,
        lastActive: last,
        pinned: session['pinned']! as bool,
      ),
    );
    routes['/api/sessions/$id/messages'] = messageListBody(id, [
      for (final (index, message) in messages.indexed)
        messageRow(
          id: index + 1,
          role: message['role']! as String,
          content: message['content'],
          timestamp:
              first +
              (last - first) * index / (messages.length - 1).clamp(1, 99),
          toolCalls: [
            for (final call
                in ((message['tool_calls'] as List?) ?? const [])
                    .cast<Map<String, Object?>>())
              functionCall(
                call['name']! as String,
                jsonEncode(call['arguments']),
              ),
          ],
        ),
    ]);
  }
  routes['/api/sessions'] = sessionListBody(rows);
  return routes;
}

/// Where the throwaway server's address is drawn, in image pixels, as
/// `left,top,right,bottom;...`, for the finish step to erase.
String _addressBoxes(WidgetTester tester, String address) {
  final ratio = tester.view.devicePixelRatio;
  return find
      .textContaining(address)
      .evaluate()
      .map((element) {
        final box = element.renderObject! as RenderBox;
        final rect = (box.localToGlobal(Offset.zero) & box.size).inflate(4);
        return [
          rect.left,
          rect.top,
          rect.right,
          rect.bottom,
        ].map((value) => (value * ratio).round()).join(',');
      })
      .join(';');
}

void main() {
  late LocalDashboard dashboard;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    dashboard = await LocalDashboard.start(_demoRoutes());
  });

  tearDown(() => dashboard.close());

  for (final device in _devices) {
    for (final brightness in Brightness.values) {
      final light = brightness == Brightness.light;
      testWidgets('${device.name} ${brightness.name}', (tester) async {
        debugDefaultTargetPlatformOverride = device.platform;
        try {
          final shots = ScreenshotRecorder('readme-${device.name}');
          final auth = AuthController(
            tokenStore: MemoryTokenStore(),
            devServerUrl: dashboard.url,
          );
          await pumpWorkflowApp(
            tester,
            shots,
            auth: auth,
            size: device.size,
            pixelRatio: device.pixelRatio,
            platform: device.platform,
            brightness: brightness,
          );
          await tester.runAsync(auth.bootstrap);
          final chat = find.byKey(const ValueKey('thread-$_openedChat'));
          // Opening the drawer settles the fake clock far enough to time the
          // pending requests out, so wait for the chats first.
          await pumpUntilFound(tester, _starterPrompt);
          if (!device.wide) await openSidebar(tester);
          await pumpUntilFound(tester, chat);

          Uint8List? previous;
          Future<void> shot(String name) async {
            await _settle(tester);
            final png = await shots.render(
              tester,
              pixelRatio: device.pixelRatio,
            );
            final width = ByteData.sublistView(png).getUint32(16);
            final height = ByteData.sublistView(png).getUint32(20);
            expect(
              Size(width.toDouble(), height.toDouble()),
              device.size * device.pixelRatio,
              reason: '$name raw size',
            );
            expect(
              previous != null && listEquals(previous, png),
              isFalse,
              reason: '$name looks like the screen before it',
            );
            previous = png;
            if (!_write) return;
            final file = File(
              'build/screenshots/${device.name}-${brightness.name}/$name.png',
            );
            final erase = _addressBoxes(
              tester,
              Uri.parse(dashboard.url).authority,
            );
            await tester.runAsync(() async {
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png);
              await File(file.path.replaceFirst('.png', '.erase'))
                  .writeAsString(erase);
            });
          }

          await tester.tap(chat);
          await _settle(tester);
          await pumpUntilFound(
            tester,
            find.textContaining(
              'Done. The timer now fires',
              findRichText: true,
            ),
          );
          await _settle(tester);
          await shot('chat');

          if (light) {
            if (!device.wide) {
              await openSidebar(tester);
              await shot('threads');
            }

            final macNewChat = find.byKey(const Key('toolbar-new-chat'));
            await tester.tap(
              macNewChat.evaluate().isEmpty
                  ? find.text('New chat')
                  : macNewChat,
            );
            await _settle(tester);
            expect(_starterPrompt, findsOneWidget);
            await shot('welcome');
          }
          await letSocketsIdle(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
