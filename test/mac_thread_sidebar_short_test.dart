import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/macos/mac_sidebar.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/widgets/mac_profile_switcher.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final height in [420.0, 320.0, 280.0]) {
    testWidgets('production Mac sidebar remains reachable at 800 x $height', (
      tester,
    ) async {
      tester.view.physicalSize = Size(800, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = AuthController();
      addTearDown(auth.dispose);
      int? selectedDestination;
      String? selectedThread;
      final navigation = Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MacProfileSwitcher(
              profiles: const [
                HermesProfile(
                  name: 'work',
                  displayName: 'Work',
                  description: 'Synthetic work profile',
                ),
              ],
              current: 'work',
              onSwitch: (_) {},
              onNewProfile: () {},
              onManage: () {},
            ),
          ),
          ShellNavigation(
            destinations: const [
              (
                icon: AppIcons.chat,
                selected: AppIcons.chatFilled,
                label: 'Chat',
                caption: null,
              ),
              (
                icon: AppIcons.bot,
                selected: AppIcons.bot,
                label: 'Bots',
                caption: null,
              ),
              (
                icon: AppIcons.kanban,
                selected: AppIcons.kanbanFilled,
                label: 'Kanban',
                caption: 'All profiles',
              ),
              (
                icon: AppIcons.scheduleOutlined,
                selected: AppIcons.schedule,
                label: 'Schedules',
                caption: null,
              ),
              (
                icon: AppIcons.person,
                selected: AppIcons.person,
                label: 'Profiles',
                caption: null,
              ),
            ],
            selectedIndex: 0,
            onSelected: (index) => selectedDestination = index,
          ),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: auth,
          child: MaterialApp(
            theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
            home: MacSidebarScope(
              child: Scaffold(
                body: MacSplitView(
                  sidebar: ThreadSidebar(
                    threads: [
                      ChatThread(
                        id: 'synthetic-thread',
                        title: 'Current thread',
                        updatedAt: DateTime(2024),
                      ),
                    ],
                    selectedId: 'synthetic-thread',
                    onSelect: (id) => selectedThread = id,
                    onNewThread: () {},
                    navigation: navigation,
                  ),
                  content: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Profiles'));
      await tester.pumpAndSettle();
      expect(find.text('Profiles').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Profiles'));
      expect(selectedDestination, 4);
      expect(find.text('Not connected').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Current thread'),
        28,
        scrollable: find
            .descendant(
              of: find.byType(ThreadSidebar),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Current thread').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Current thread'));
      expect(selectedThread, 'synthetic-thread');
      expect(find.text('Not connected').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
