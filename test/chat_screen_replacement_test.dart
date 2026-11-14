import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/handoff/handoff_activity.dart';
import 'package:hermes_app/src/handoff/handoff_bridge.dart';
import 'package:hermes_app/src/handoff/handoff_controller.dart';
import 'package:provider/provider.dart';

import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// A keyed child that is swapped builds its replacement before the old one is
/// disposed, so a dispose must not clear what the new screen set on an object
/// that outlives both.
void main() {
  testWidgets('a replaced chat screen leaves the Handoff restore bound', (
    tester,
  ) async {
    final handoff = HandoffController(HandoffBridge(enabled: false))
      ..configure(
        serverUrl: 'https://hermes.test',
        ready: true,
        unlocked: true,
        initializing: false,
        fixedServer: false,
        userGeneration: 0,
      );
    addTearDown(handoff.dispose);
    final server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]));

    Future<void> pump(int generation) => pumpChatScreen(
      tester,
      server: server,
      providers: [
        ChangeNotifierProvider<HandoffController>.value(value: handoff),
      ],
      settle: false,
      wrap: (app) => KeyedSubtree(key: ValueKey(generation), child: app),
    );

    await pump(1);
    await tester.pump(const Duration(milliseconds: 200));
    await pump(2);
    await tester.pump(const Duration(milliseconds: 200));
    handoff.receive(
      const HandoffActivity('https://hermes.test', 'work', 's1').payload,
    );
    await tester.runAsync(handoff.drive);

    expect(
      handoff.pending == null || handoff.error != null,
      isTrue,
      reason: 'the new screen restored the activity',
    );
  });
}
