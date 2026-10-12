import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/main.dart' as app;
import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_status_chips.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_header.dart';
import 'package:hermes_app/src/platform_hint/widgets/platform_hint_prompt.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

const _shotPort = String.fromEnvironment('SHOT_PORT');
const _kanbanOnly = bool.fromEnvironment('SHOT_KANBAN_ONLY');

/// `light` or `dark` sets the app's own theme; empty follows the system, which
/// is what the simulators are set to.
const _shotTheme = String.fromEnvironment('SHOT_THEME');

/// `<width>x<height>` in points resizes the Mac window first, which opens at
/// 800 x 600, below the wide layout.
const _shotWindow = String.fromEnvironment('SHOT_WINDOW');

const _serverUrl = String.fromEnvironment('HERMES_SERVER_URL');

/// Where the throwaway backend's address is drawn, in image pixels, as
/// `left,top,right,bottom;...`. The finish step erases these areas.
String _addressBoxes(WidgetTester tester) {
  final address = Uri.parse(_serverUrl).authority;
  if (address.isEmpty) return '';
  final ratio = tester.view.devicePixelRatio;
  return find
      .textContaining(address)
      .evaluate()
      .map((element) {
        final box = element.renderObject! as RenderBox;
        final rect = (box.localToGlobal(Offset.zero) & box.size).inflate(4);
        return [
          rect.left,
          rect.top,
          rect.right,
          rect.bottom,
        ].map((value) => (value * ratio).round()).join(',');
      })
      .join(';');
}

/// Walks the real app through the screens shown on the store listing and in
/// the README. It needs a Hermes dashboard seeded by
/// `scripts/seed_demo_sessions.py`, passed as `--dart-define=HERMES_SERVER_URL`,
/// and a driver that decides where each screenshot goes
/// (`test_driver/integration_test.dart`). `scripts/store-screenshots.sh` runs it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 2]) async {
    for (var i = 0; i < seconds * 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('store screenshots', (tester) async {
    // A tap that misses would otherwise leave the same screen in every image.
    WidgetController.hitTestWarningShouldBeFatal = true;
    await app.main();
    await settle(tester, 4);
    final hintPrompt = find.byType(PlatformHintPrompt);
    if (hintPrompt.evaluate().isNotEmpty) {
      await tester.tap(
        find.descendant(of: hintPrompt, matching: find.text('Not now')),
      );
      await settle(tester);
    }
    if (_shotWindow.isNotEmpty) {
      final [width, height] = _shotWindow.split('x').map(double.parse).toList();
      await const MethodChannel('hermes_app/window').invokeMethod<void>(
        'setContentSize',
        {'width': width, 'height': height},
      );
      await settle(tester);
    }
    if (_shotTheme.isNotEmpty) {
      final context = tester.element(find.byType(MaterialApp));
      await Provider.of<ThemeController>(
        context,
        listen: false,
      ).setMode(ThemeMode.values.byName(_shotTheme));
      await settle(tester);
    }

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final wide = width >= 900;

    Future<void> openThreads() async {
      if (wide) return;
      await tester.tap(find.byIcon(Icons.menu).first);
      await settle(tester);
    }

    // The driver answers once the screen has been captured.
    Future<void> shot(String name) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.http('127.0.0.1:$_shotPort', '/shot', {
            'name': name,
            'erase': _addressBoxes(tester),
          }),
        );
        final response = await request.close();
        expect(response.statusCode, 200, reason: 'screenshot $name');
      } finally {
        client.close();
      }
    }

    if (!_kanbanOnly) {
      await openThreads();
      await tester.tap(
        find.byKey(const ValueKey('thread-demo-backup-failure')),
      );
      await settle(tester, 3);
      await shot('chat');

      await openThreads();
      if (!wide) await shot('threads');

      final macNewChat = find.byKey(const Key('toolbar-new-chat'));
      await tester.tap(
        macNewChat.evaluate().isEmpty ? find.text('New chat') : macNewChat,
      );
      await settle(tester);
      await shot('welcome');
    }

    await openThreads();
    await tester.tap(find.text('Kanban').first);
    await settle(tester, 4);
    final statusChips = find.byType(KanbanStatusChips);
    if (statusChips.evaluate().isNotEmpty) {
      final ready = find.descendant(
        of: statusChips,
        matching: find.textContaining(RegExp(r'^Ready \d+$')),
      );
      expect(ready, findsOneWidget);
      await tester.ensureVisible(ready);
      await tester.tap(ready);
      await settle(tester);
    }
    final task = find.ancestor(
      of: find.text('Verify the nightly backup'),
      matching: find.byType(KanbanCard),
    );
    if (task.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        task,
        300,
        scrollable: find
            .descendant(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is ListView &&
                    widget.scrollDirection == Axis.horizontal,
              ),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.right,
              ),
            )
            .first,
      );
      await settle(tester);
    }
    expect(task, findsOneWidget);
    await tester.ensureVisible(task);
    await shot('kanban');
    await tester.tap(task);
    await settle(tester);
    expect(find.byType(KanbanTaskPanel), findsOneWidget);
    final grabber = find.byKey(const Key('kanbanTaskGrabber'));
    if (grabber.evaluate().isNotEmpty) {
      await tester.flingFrom(
        tester.getCenter(grabber),
        const Offset(0, -600),
        1500,
      );
      await settle(tester);
      expect(
        tester.getSize(find.byKey(const Key('kanbanTaskSheet'))).height,
        greaterThan(
          tester.view.physicalSize.height / tester.view.devicePixelRatio * 0.8,
        ),
      );
      await tester.ensureVisible(find.byType(KanbanTaskHeader));
      await settle(tester);
    }
    await shot('kanban-task');
  });
}
