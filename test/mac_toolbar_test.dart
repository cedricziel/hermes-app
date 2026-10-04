import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_sidebar.dart';
import 'package:hermes_app/src/macos/mac_toolbar.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1000, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'hermes.mac_sidebar_collapsed': true,
        }),
  );

  group('MacToolbarButton', () {
    testWidgets('is 28 points square and names its shortcut on hover', (
      tester,
    ) async {
      var pressed = 0;
      await _pump(
        tester,
        Center(
          child: MacToolbarButton(
            label: 'New Task',
            shortcut: '⌘N',
            icon: AppIcons.add,
            onPressed: () => pressed++,
          ),
        ),
      );

      expect(tester.getSize(find.byType(MacToolbarButton)), const Size(28, 28));
      expect(find.byTooltip('New Task ⌘N'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('New Task')),
        isSemantics(label: 'New Task', isButton: true, isEnabled: true),
      );

      await tester.tap(find.byType(MacToolbarButton));
      expect(pressed, 1);
    });

    testWidgets('a toggle is filled and says it is selected while on', (
      tester,
    ) async {
      Future<void> pump({required bool selected}) => _pump(
        tester,
        Center(
          child: MacToolbarButton(
            label: 'Inspector',
            icon: AppIcons.inspector,
            selected: selected,
            onPressed: () {},
          ),
        ),
      );
      Color? fill() => tester
          .widget<Material>(
            find.descendant(
              of: find.byType(MacToolbarButton),
              matching: find.byType(Material),
            ),
          )
          .color;

      await pump(selected: false);
      expect(fill(), anyOf(isNull, Colors.transparent));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Inspector')),
        isSemantics(isSelected: false, hasSelectedState: true),
      );

      await pump(selected: true);
      expect(fill()?.a, greaterThan(0));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Inspector')),
        isSemantics(isSelected: true, hasSelectedState: true),
      );
    });
  });

  group('MacToolbar', () {
    testWidgets('is the 52 point bar with a title and a subtitle', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          children: [
            MacToolbar(title: 'Kanban', subtitle: 'Default · 4 tasks'),
          ],
        ),
      );

      expect(tester.getSize(find.byType(MacToolbar)).height, kMacToolbarHeight);
      final title = tester.widget<Text>(find.text('Kanban'));
      expect(title.style?.fontSize, 13);
      expect(title.style?.fontWeight, FontWeight.w700);
      expect(
        tester.widget<Text>(find.text('Default · 4 tasks')).style?.fontSize,
        11,
      );
      expect(find.byKey(const Key('mac-sidebar-toggle')), findsNothing);
      expect(tester.getTopLeft(find.text('Kanban')).dx, 20);
    });

    testWidgets('with the sidebar collapsed it clears the traffic lights and '
        'offers to show the sidebar', (tester) async {
      await _pump(
        tester,
        MacSidebarScope(
          child: Builder(
            builder: (context) => ShellMenu(
              onOpen: MacSidebarScope.of(context).toggle,
              leadingInset: kMacTrafficLightsWidth,
              child: const Column(children: [MacToolbar(title: 'Kanban')]),
            ),
          ),
        ),
      );

      final toggle = find.byKey(const Key('mac-sidebar-toggle'));
      expect(
        tester.getTopLeft(toggle).dx,
        greaterThanOrEqualTo(kMacTrafficLightsWidth),
      );
      expect(find.byTooltip('Show sidebar ⌃⌘S'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final scope = tester.element(find.byType(MacToolbar));
      expect(MacSidebarScope.of(scope).collapsed, isFalse);
    });

    testWidgets('in a narrow window it opens the navigation drawer', (
      tester,
    ) async {
      var opened = 0;
      await _pump(
        tester,
        ShellMenu(
          onOpen: () => opened++,
          child: const Column(children: [MacToolbar(title: 'Kanban')]),
        ),
      );

      final menu = find.byKey(const Key('shell-menu'));
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      expect(
        tester.getTopLeft(menu).dx,
        greaterThanOrEqualTo(kMacTrafficLightsWidth),
      );
      await tester.tap(menu);
      expect(opened, 1);
    });

    testWidgets('lays out its actions at the trailing edge', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            MacToolbar(
              title: 'Kanban',
              actions: [
                MacToolbarButton(
                  label: 'New Task',
                  icon: AppIcons.add,
                  onPressed: () {},
                ),
                const MacToolbarSeparator(),
              ],
            ),
          ],
        ),
      );

      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(MacToolbarSeparator),
            matching: find.byType(ColoredBox),
          ),
        ),
        const Size(1, 20),
      );
      expect(
        tester.getTopRight(find.byType(MacToolbarSeparator)).dx,
        greaterThan(tester.getTopRight(find.byType(MacToolbarButton)).dx),
      );
    });
  });
}
