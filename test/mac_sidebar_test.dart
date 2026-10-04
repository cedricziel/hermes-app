import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> _pump(WidgetTester tester, {double width = 1280}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MacSidebarScope(
        child: Scaffold(
          body: MacSplitView(
            sidebar: Container(key: const Key('sidebar')),
            content: Container(key: const Key('content')),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('opens at the default width', (tester) async {
    await _pump(tester);
    expect(tester.getSize(find.byKey(const Key('sidebar'))).width, 280);
    expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, 281);
  });

  testWidgets('dragging the divider resizes within the limits', (tester) async {
    await _pump(tester);
    final handle = find.byKey(const Key('mac-sidebar-resize'));
    await tester.drag(handle, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('sidebar'))).width, 340);
    await tester.drag(handle, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('sidebar'))).width, 360);
    await tester.drag(handle, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('sidebar'))).width, 220);
  });

  testWidgets('control-command-S collapses and restores the sidebar', (
    tester,
  ) async {
    await _pump(tester);
    Future<void> chord() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
    }

    await chord();
    expect(find.byKey(const Key('sidebar')), findsNothing);
    expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, 0);
    await chord();
    expect(tester.getSize(find.byKey(const Key('sidebar'))).width, 280);
  });

  testWidgets('remembers the width and the collapsed state', (tester) async {
    await _pump(tester);
    await tester.drag(
      find.byKey(const Key('mac-sidebar-resize')),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();
    MacSidebarScope.of(tester.element(find.byKey(const Key('content'))))
        .toggle();
    await tester.pumpAndSettle();

    final prefs = SharedPreferencesAsync();
    expect(await prefs.getDouble('hermes.mac_sidebar_width'), 320);
    expect(await prefs.getBool('hermes.mac_sidebar_collapsed'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester);
    expect(find.byKey(const Key('sidebar')), findsNothing);
    MacSidebarScope.of(tester.element(find.byKey(const Key('content'))))
        .toggle();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const Key('sidebar'))).width, 320);
  });

  test('remembers which sections are folded', () async {
    final controller = MacSidebarController();
    await controller.load();
    expect(controller.sections.isCollapsed('today'), isFalse);
    controller.sections.toggle('today');
    expect(controller.sections.isCollapsed('today'), isTrue);
    await Future<void>.delayed(Duration.zero);

    final reloaded = MacSidebarController();
    await reloaded.load();
    expect(reloaded.sections.isCollapsed('today'), isTrue);
    reloaded.sections.toggle('today');
    expect(reloaded.sections.isCollapsed('today'), isFalse);
  });

  group('in a compact window', () {
    Future<void> toggle(WidgetTester tester) async {
      MacSidebarScope.of(tester.element(find.byKey(const Key('content'))))
          .toggle(compact: true);
      await tester.pumpAndSettle();
    }

    testWidgets('the sidebar is not docked', (tester) async {
      await _pump(tester, width: 700);
      expect(find.byKey(const Key('sidebar')), findsNothing);
      expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, 0);
      expect(find.byKey(const Key('mac-sidebar-resize')), findsNothing);
    });

    testWidgets('opens over the content, and the scrim closes it', (
      tester,
    ) async {
      await _pump(tester, width: 700);
      await toggle(tester);

      expect(find.byKey(const Key('mac-sidebar-overlay')), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, 0);
      expect(tester.getSize(find.byKey(const Key('sidebar'))).width, 280);

      await tester.tapAt(const Offset(600, 400));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sidebar')), findsNothing);
    });

    testWidgets('control-command-S opens the overlay, not the docked one', (
      tester,
    ) async {
      await _pump(tester, width: 700);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mac-sidebar-overlay')), findsOneWidget);
      expect(
        await SharedPreferencesAsync().getBool('hermes.mac_sidebar_collapsed'),
        isNull,
      );
    });

    testWidgets('closeOverlay closes it', (tester) async {
      await _pump(tester, width: 700);
      await toggle(tester);
      MacSidebarScope.of(tester.element(find.byKey(const Key('content'))))
          .closeOverlay();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mac-sidebar-overlay')), findsNothing);
    });
  });
}
