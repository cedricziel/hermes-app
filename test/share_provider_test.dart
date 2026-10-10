import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/share_provider.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_share_inbox.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  /// Mounts the provider the way `main.dart` does, under a screen (the setup
  /// screen, before sign-in) that never reads it.
  Future<FakeShareInbox> pumpApp(
    WidgetTester tester, {
    List<SharedItem> initial = const [],
  }) async {
    final inbox = FakeShareInbox(initial);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.none),
          shareProvider(inbox: inbox),
        ],
        child: const MaterialApp(home: Text('setup')),
      ),
    );
    await tester.pump();
    return inbox;
  }

  testWidgets('the inbox is read at launch, before anything asks for it', (
    tester,
  ) async {
    final inbox = await pumpApp(tester);

    expect(inbox.initialCalls, 1);
  });

  testWidgets('a quote that launched the app waits for the chat screen', (
    tester,
  ) async {
    await pumpApp(tester, initial: const [SharedQuote('selected')]);

    final share = Provider.of<ShareController>(
      tester.element(find.text('setup')),
      listen: false,
    );
    expect(share.take(), const [SharedQuote('selected')]);
  });
}
