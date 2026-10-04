import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/widgets/chat_header.dart';
import 'package:hermes_app/src/chat/widgets/mac_chat_toolbar.dart';
import 'package:hermes_app/src/macos/mac_sidebar.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_share_inbox.dart';

Future<void> _pump(WidgetTester tester, TargetPlatform platform) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
        ChangeNotifierProvider<ShareController>(
          create: (_) => ShareController(FakeShareInbox()),
        ),
      ],
      child: MaterialApp(
        theme: buildHermesLightTheme().copyWith(platform: platform),
        home: const MacSidebarScope(child: ChatScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('macOS header is the 52pt toolbar with no rule under it', (
    tester,
  ) async {
    await _pump(tester, TargetPlatform.macOS);
    final header = tester.getRect(find.byType(MacChatToolbar));
    expect(header.height, kMacToolbarHeight);
    final rules = tester
        .widgetList<Divider>(find.byType(Divider))
        .where((d) => d.height == 1)
        .map((d) => tester.getRect(find.byWidget(d)))
        .where((r) => r.top == header.bottom && r.left >= header.left);
    expect(rules, isEmpty);
  });

  testWidgets('macOS sidebar starts at the top, with no brand row', (
    tester,
  ) async {
    await _pump(tester, TargetPlatform.macOS);
    expect(find.byKey(const Key('mac-sidebar-toggle')), findsOneWidget);
    expect(find.byIcon(Icons.hub_outlined), findsNothing);
  });

  testWidgets('collapsing the sidebar moves its toggle into the header', (
    tester,
  ) async {
    await _pump(tester, TargetPlatform.macOS);
    await tester.tap(find.byKey(const Key('mac-sidebar-toggle')));
    await tester.pumpAndSettle();
    final toggle = find.descendant(
      of: find.byType(MacChatToolbar),
      matching: find.byKey(const Key('mac-sidebar-toggle')),
    );
    expect(toggle, findsOneWidget);
    expect(tester.getTopLeft(toggle).dx, greaterThanOrEqualTo(78));
  });

  testWidgets('other platforms keep the Material header and sidebar', (
    tester,
  ) async {
    await _pump(tester, TargetPlatform.android);
    expect(tester.getSize(find.byType(ChatHeader)).height, isNot(52));
    expect(find.byKey(const Key('mac-sidebar-toggle')), findsNothing);
    expect(find.byKey(const Key('mac-sidebar-resize')), findsNothing);
  });
}
