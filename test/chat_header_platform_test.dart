import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/widgets/chat_header.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_share_inbox.dart';

const _statusBar = 59.0;

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required TargetPlatform platform,
}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = const FakeViewPadding(top: _statusBar);
  tester.view.viewPadding = const FakeViewPadding(top: _statusBar);
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
        home: const ChatScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Offset _barTitleCenter(WidgetTester tester) => tester.getCenter(
  find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first,
);

void main() {
  const phone = Size(393, 852);

  testWidgets('phone bar is a 44pt bar with a centred title on iOS', (
    tester,
  ) async {
    await _pump(tester, size: phone, platform: TargetPlatform.iOS);
    final bar = tester.getRect(find.byType(AppBar));
    expect(bar.top, 0);
    expect(bar.height, 44 + _statusBar);
    final title = _barTitleCenter(tester);
    expect(title.dx, closeTo(phone.width / 2, 4));
    expect(title.dy, greaterThan(_statusBar));
  });

  testWidgets('phone bar stays the Material bar on Android', (tester) async {
    await _pump(tester, size: phone, platform: TargetPlatform.android);
    expect(tester.getSize(find.byType(AppBar)).height, 56 + _statusBar);
  });

  testWidgets('wide header sits below the status bar', (tester) async {
    await _pump(
      tester,
      size: const Size(1194, 834),
      platform: TargetPlatform.iOS,
    );
    final title = tester.getTopLeft(
      find
          .descendant(of: find.byType(ChatHeader), matching: find.byType(Text))
          .first,
    );
    expect(title.dy, greaterThanOrEqualTo(_statusBar));
  });
}
