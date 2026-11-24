import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/mac_commands_builder.dart';
import '../support/pump_chat.dart';
import '../support/test_localizations.dart';
import '../support/wait_until.dart';

/// The commands a screen offers on Windows and Linux that only the Mac
/// offered before: the chord reaches the screen through the registry.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
    testWidgets('Ctrl+R and F5 read the status again on $platform', (
      tester,
    ) async {
      final server = FakeHermesServer()
        ..on('GET', '/api/status', {'version': '0.21.4'});
      final auth = CatalogAuth(server: server, gated: true);
      addTearDown(auth.dispose);
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            localizationsDelegates: kTestLocalizationsDelegates,
            builder: macCommandsBuilder(commands, desktopKeys: true),
            home: const HomeScreen(),
          ),
        ),
      );
      int statuses() => server.requestsTo('GET', '/api/status').length;
      await waitUntil(
        tester,
        () => statuses() >= 1,
        reason: 'the initial status request',
      );
      await tester.pumpAndSettle();
      final before = statuses();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await waitUntil(
        tester,
        () => statuses() >= before + 1,
        reason: 'the Ctrl+R status request',
      );
      await tester.pumpAndSettle();
      expect(statuses(), before + 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await waitUntil(
        tester,
        () => statuses() >= before + 2,
        reason: 'the F5 status request',
      );
      await tester.pumpAndSettle();
      expect(statuses(), before + 2);
    });

    testWidgets('Ctrl+B opens and closes the chat list drawer on $platform', (
      tester,
    ) async {
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      await pumpChatScreen(
        tester,
        platform: platform,
        size: const Size(500, 800),
        transport: FakeChatTransport(),
        commands: commands,
        desktopKeys: true,
      );
      expect(find.byType(Drawer), findsNothing);
      expect(commands.handlerFor(MacCommand.toggleSidebar)?.enabled, isTrue);

      Future<void> ctrlB() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await ctrlB();
      expect(find.byType(Drawer), findsOneWidget);
      await ctrlB();
      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('Ctrl+B has nothing to do beside a permanent sidebar on '
        '$platform', (tester) async {
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      await pumpChatScreen(
        tester,
        platform: platform,
        size: const Size(1400, 900),
        transport: FakeChatTransport(),
        commands: commands,
        desktopKeys: true,
      );
      expect(commands.handlerFor(MacCommand.toggleSidebar), isNull);
    });
  }
}
