import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/handoff/handoff_activity.dart';
import 'package:hermes_app/src/handoff/handoff_bridge.dart';
import 'package:hermes_app/src/handoff/handoff_controller.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_conversation_window_host.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

class _RecordingBridge extends HandoffBridge {
  _RecordingBridge() : super(enabled: false);
  final activities = <HandoffActivity?>[];
  @override
  Future<void> publish(HandoffActivity? activity) async =>
      activities.add(activity);
}

/// Handoff while conversation windows are open: the key window's chat is
/// the one offered, and a chat handed over that has a window opens there.
void main() {
  late FakeHermesServer server;
  late FakeConversationWindowHost host;
  late ConversationWindows windows;
  late _RecordingBridge bridge;
  late HandoffController handoff;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Trip plan')]),
      );
  });

  Future<void> pump(WidgetTester tester) async {
    bridge = _RecordingBridge();
    handoff = HandoffController(bridge)
      ..configure(
        serverUrl: 'https://hermes.test',
        ready: true,
        unlocked: true,
        initializing: false,
        fixedServer: false,
        userGeneration: 0,
      );
    await pumpChatScreen(
      tester,
      server: server,
      platform: TargetPlatform.macOS,
      providers: [
        ChangeNotifierProvider<HandoffController>.value(value: handoff),
        ChangeNotifierProvider<ConversationWindows?>(
          create: (_) {
            host = FakeConversationWindowHost();
            addTearDown(host.dispose);
            return windows = ConversationWindows(
              host: host,
              store: ConversationWindowStore(SharedPreferencesAsync()),
              connection: () =>
                  (baseUrl: 'https://hermes.test', authRequired: true),
              headers: ({rejected}) async => const {},
            );
          },
        ),
      ],
    );
  }

  testWidgets('the key conversation window offers its chat', (tester) async {
    await pump(tester);
    await windows.open('s1', profile: 'work', title: 'Trip plan');

    await host.call('focused', {'window_id': 'w0', 'focused': true});
    await tester.pumpAndSettle();

    final offered = bridge.activities.last!;
    expect(offered.threadId, 's1');
    expect(offered.profile, 'work');

    host.focusMain();
    await tester.pumpAndSettle();
    expect(bridge.activities.last, isNull);
  });

  testWidgets('a handed-over chat open in a window comes up in that window', (
    tester,
  ) async {
    await pump(tester);
    await windows.open('s1', profile: 'work', title: 'Trip plan');

    handoff.receive(
      const HandoffActivity('https://hermes.test', 'work', 's1').payload,
    );
    await handoff.drive();
    await tester.pumpAndSettle();

    expect(host.focused, ['w0']);
    expect(handoff.pending, isNull);
    expect(handoff.error, isNull);
    expect(server.requestsTo('GET', '/api/sessions/s1'), isEmpty);
  });
}
