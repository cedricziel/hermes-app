import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_chat_transport.dart';
import 'support/pump_chat.dart';

void main() {
  testWidgets('coming back from sleep checks the chat connection', (
    tester,
  ) async {
    final transport = FakeChatTransport();
    await pumpChatScreen(tester, transport: transport);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();

    expect(transport.connectionChecks, 1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('going to the background alone checks nothing', (tester) async {
    final transport = FakeChatTransport();
    await pumpChatScreen(tester, transport: transport);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();

    expect(transport.connectionChecks, 0);
    await tester.pump(const Duration(seconds: 5));
  });
}
