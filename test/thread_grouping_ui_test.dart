import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/chat/widgets/thread_grouping_controls.dart';
import 'package:hermes_app/src/chat/thread_list_preferences.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> show(
    WidgetTester tester,
    TargetPlatform platform,
    List<ChatThread> rows,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(),
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: platform),
          home: Scaffold(
            body: ThreadSidebar(
              threads: rows,
              selectedId: null,
              onSelect: (_) {},
              onNewThread: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('${platform.name} keeps one inline menu when no chats exist', (
      tester,
    ) async {
      await show(tester, platform, []);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.byType(ThreadGroupingMenu), findsOneWidget);
      await tester.tap(find.byTooltip('Group chats'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: find.text('Folder'),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is CheckedPopupMenuItem<ThreadGrouping> ||
                    w is CupertinoMenuItem,
              ),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Chats'), findsOneWidget);
      expect(find.byType(ThreadGroupingMenu), findsOneWidget);
    });

    testWidgets(
      '${platform.name} moves the menu with the first section and keeps its taps separate',
      (tester) async {
        final rows = [
          ChatThread(
            id: 'p',
            title: 'Pinned plan',
            pinned: true,
            updatedAt: DateTime.now(),
          ),
          ChatThread(
            id: 's',
            title: 'Working chat',
            folderPath: '/code/app',
            updatedAt: DateTime.now(),
          ),
          ChatThread(id: 'd', title: 'General chat', updatedAt: DateTime.now()),
        ];
        await show(tester, platform, rows);
        await tester.tap(find.text('Pinned'));
        await tester.pumpAndSettle();
        expect(find.text('Pinned plan'), findsNothing);
        await tester.tap(find.byTooltip('Group chats'));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .ancestor(
                of: find.text('Recent'),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is CheckedPopupMenuItem<ThreadGrouping> ||
                      w is CupertinoMenuItem,
                ),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Pinned plan'), findsNothing);
        rows.removeAt(0);
        await show(tester, platform, rows);
        expect(find.text('Pinned'), findsNothing);
        expect(find.byType(ThreadGroupingMenu), findsOneWidget);
        await tester.tap(find.byTooltip('Group chats'));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .ancestor(
                of: find.text('Folder'),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is CheckedPopupMenuItem<ThreadGrouping> ||
                      w is CupertinoMenuItem,
                ),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('app'));
        await tester.pumpAndSettle();
        expect(find.text('Working chat'), findsNothing);
        expect(find.byType(ThreadGroupingMenu), findsOneWidget);
        await tester.tap(find.byTooltip('Group chats'));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .ancestor(
                of: find.text('Folder'),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is CheckedPopupMenuItem<ThreadGrouping> ||
                      w is CupertinoMenuItem,
                ),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Working chat'), findsNothing);
        rows.removeAt(0);
        await show(tester, platform, rows);
        expect(find.text('No folder'), findsOneWidget);
        expect(find.byType(ThreadGroupingMenu), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${platform.name} long distinct folder names leave the menu accessible',
      (tester) async {
        await show(tester, platform, [
          ChatThread(
            id: 'a',
            title: 'Work chat',
            folderPath: '/workspace/very-long-work-directory/app',
            updatedAt: DateTime.now(),
          ),
          ChatThread(
            id: 'b',
            title: 'Personal chat',
            folderPath: '/workspace/very-long-personal-directory/app',
            updatedAt: DateTime.now(),
          ),
        ]);
        await tester.tap(find.byTooltip('Group chats'));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .ancestor(
                of: find.text('Folder'),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is CheckedPopupMenuItem<ThreadGrouping> ||
                      w is CupertinoMenuItem,
                ),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('/workspace/very-long-work-directory/app'),
          findsOneWidget,
        );
        expect(
          find.text('/workspace/very-long-personal-directory/app'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Group chats'));
        await tester.pumpAndSettle();
        expect(find.text('Recent'), findsOneWidget);
      },
    );

    testWidgets(
      '${platform.name} groups folders without changing selection and remembers disclosures',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final selected = <String>[];
        final auth = AuthController();
        addTearDown(auth.dispose);
        final rows = [
          ChatThread(
            id: 'p',
            title: 'Release checklist',
            pinned: true,
            folderPath: '/code/hermes',
            updatedAt: DateTime.now(),
          ),
          ChatThread(
            id: 's',
            title: 'Fix session search',
            folderPath: '/code/hermes',
            updatedAt: DateTime.now(),
          ),
          ChatThread(
            id: 'd',
            title: 'Research voice input',
            updatedAt: DateTime.now(),
          ),
        ];
        Future<void> pumpSidebar() async {
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: auth,
              child: MaterialApp(
                theme: buildHermesLightTheme(platform: platform),
                home: Scaffold(
                  body: ThreadSidebar(
                    threads: rows,
                    selectedId: 's',
                    onSelect: selected.add,
                    onNewThread: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pumpSidebar();
        expect(find.text('Today'), findsOneWidget);
        expect(
          (tester.getCenter(find.byType(ThreadGroupingMenu)).dy -
                  tester
                      .getCenter(
                        find.byKey(const ValueKey('thread-section-Pinned')),
                      )
                      .dy)
              .abs(),
          lessThan(2),
        );
        expect(
          tester.getSize(find.byType(ThreadGroupingMenu)).width,
          platform == TargetPlatform.macOS ? 24 : 44,
        );
        expect(
          tester.getSize(
            find.descendant(
              of: find.byType(ThreadGroupingMenu),
              matching: find.byType(Icon),
            ),
          ),
          const Size(14, 14),
        );
        expect(find.byType(CupertinoSwitch), findsNothing);
        expect(find.byType(Switch), findsNothing);
        await tester.tap(find.byTooltip('Group chats'));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .ancestor(
                of: find.text('Folder'),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is CheckedPopupMenuItem<ThreadGrouping> ||
                      w is CupertinoMenuItem,
                ),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('hermes'), findsOneWidget);
        expect(find.text('No folder'), findsOneWidget);
        expect(find.text('Release checklist'), findsOneWidget);
        expect(selected, isEmpty);
        expect(
          tester.widget<ThreadSidebar>(find.byType(ThreadSidebar)).selectedId,
          's',
        );
        await tester.tap(find.text('hermes'));
        await tester.pumpAndSettle();
        expect(find.text('Fix session search'), findsNothing);
        expect(find.text('Research voice input'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await pumpSidebar();
        expect(find.text('hermes'), findsOneWidget);
        expect(find.text('Fix session search'), findsNothing);
        await tester.tap(find.byTooltip('Group chats'));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .ancestor(
                of: find.text('Recent'),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is CheckedPopupMenuItem<ThreadGrouping> ||
                      w is CupertinoMenuItem,
                ),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Fix session search'), findsOneWidget);
      },
    );
  }
}
