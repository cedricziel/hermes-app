import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/bot_mode/bot_chat_context.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_housekeeping.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import '../support/test_localizations.dart';

/// A canonical Bot Chat row in the sidebar offers Retire and no Rename on
/// iOS, in the phone's action sheet and in the iPad's popover.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> pumpSidebar(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bot = ChatThread(
      id: 'bot',
      title: 'Release helper',
      remote: true,
      updatedAt: DateTime(2026),
      botContext: const BotChatContext(
        bot: BotModeBot(serverId: 'server', name: 'default', revision: 0),
        rootId: 'root',
        storedId: 'tip',
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(),
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: ThreadSidebar(
              threads: [bot],
              selectedId: null,
              onSelect: (_) {},
              onNewThread: () {},
              housekeeping: ThreadHousekeeping(
                repository: HermesChatRepository(
                  FakeHermesServer().client().raw,
                ),
                threads: () => const [],
                profile: () => null,
                changed: () {},
                report: (_) {},
                removed: (_) {},
                history: (thread, {cancelled}) async => const [],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('on a phone the action sheet has Retire and no Rename', (
    tester,
  ) async {
    await pumpSidebar(tester, const Size(390, 844));

    await tester.longPress(find.text('Release helper'));
    await tester.pumpAndSettle();

    final sheet = find.byType(CupertinoActionSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Retire Bot Chat…')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Rename')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Archive')),
      findsNothing,
    );
  });

  testWidgets('on an iPad the popover has Retire and no Rename', (
    tester,
  ) async {
    await pumpSidebar(tester, const Size(1024, 768));

    await tester.longPress(find.text('Release helper'));
    await tester.pumpAndSettle();

    final items = find.byType(CupertinoMenuItem);
    expect(items, findsNWidgets(3));
    expect(
      find.descendant(of: items, matching: find.text('Retire Bot Chat…')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: items, matching: find.text('Rename')),
      findsNothing,
    );
    expect(
      find.descendant(of: items, matching: find.text('Archive')),
      findsNothing,
    );
  });
}
