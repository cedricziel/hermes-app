import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/accessibility_announcements.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';

/// On an iPad a chat row's actions open in a popover menu at the row (long
/// press) or at the pointer (secondary click); an iPhone keeps its sheet.
void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s2/messages',
        messageListBody('s2', [messageRow(id: 1, role: 'user', content: 'hi')]),
      )
      ..on(
        'PATCH',
        '/api/sessions/s2',
        sessionPatchBody(flags: {'pinned': true}),
      )
      ..on('DELETE', '/api/sessions/s2', {'ok': true});
  });

  final row = find.byKey(const ValueKey('thread-s2'));
  final title = find.descendant(of: row, matching: find.text('Release notes'));
  final menuItems = find.byType(CupertinoMenuItem);

  Future<void> pumpIpad(WidgetTester tester) => pumpChatScreen(
    tester,
    server: server,
    platform: TargetPlatform.iOS,
    size: const Size(1024, 768),
  );

  testWidgets('a long press opens a popover at the row, not a sheet', (
    tester,
  ) async {
    final said = captureAnnouncements(tester);
    await pumpIpad(tester);

    await tester.longPress(title);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(menuItems, findsNWidgets(4));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.hintOverrides?.onLongPressHint ==
                'Chat actions for Release notes',
      ),
      findsOneWidget,
    );
    for (final label in ['Rename', 'Pin', 'Archive', 'Delete']) {
      expect(
        find.descendant(of: menuItems, matching: find.text(label)),
        findsOneWidget,
      );
    }
    final rowRect = tester.getRect(row);
    final menu = tester.getRect(
      find
          .ancestor(of: menuItems.first, matching: find.byType(Scrollable))
          .first,
    );
    expect(menu.width, lessThan(300));
    expect(
      menu.left,
      closeTo(rowRect.right, 1),
      reason: "the menu opens at the row's trailing edge",
    );
    expect(menu.top, closeTo(rowRect.top, 1), reason: 'level with the row');
    expect(said, [
      (message: 'Chat actions for Release notes', textDirection: 1),
    ], reason: 'the open menu is named by an announcement');
  });

  testWidgets('a secondary click opens the menu at the pointer', (
    tester,
  ) async {
    await pumpIpad(tester);
    final at = tester.getTopLeft(row) + const Offset(40, 20);

    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await mouse.down(at);
    await mouse.up();
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(menuItems, findsNWidgets(4));
    final menu = tester.getRect(
      find
          .ancestor(of: menuItems.first, matching: find.byType(Scrollable))
          .first,
    );
    expect((menu.left - at.dx).abs(), lessThan(8));
    expect((menu.top - at.dy).abs(), lessThan(40));
  });

  testWidgets('the popover pins the chat', (tester) async {
    await pumpIpad(tester);

    await tester.longPress(title);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: menuItems, matching: find.text('Pin')),
    );
    await tester.pumpAndSettle();

    final request = server.requestsTo('PATCH', '/api/sessions/s2').single;
    expect(jsonBody(request), {'pinned': true});
  });

  testWidgets('Delete in the popover asks first, with Cancel as default', (
    tester,
  ) async {
    await pumpIpad(tester);

    await tester.longPress(title);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: menuItems, matching: find.text('Delete')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete this chat?'), findsOneWidget);
    expect(server.requestsTo('DELETE', '/api/sessions/s2'), isEmpty);
    final cancel = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Cancel'),
    );
    final delete = tester.widget<CupertinoDialogAction>(
      find.widgetWithText(CupertinoDialogAction, 'Delete'),
    );
    expect(cancel.isDefaultAction, isTrue);
    expect(delete.isDefaultAction, isFalse);
    expect(delete.isDestructiveAction, isTrue);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Delete'));
    await tester.pumpAndSettle();
    expect(server.requestsTo('DELETE', '/api/sessions/s2'), hasLength(1));
  });

  testWidgets('an iPhone keeps the action sheet', (tester) async {
    await pumpChatScreen(tester, server: server, platform: TargetPlatform.iOS);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    await tester.longPress(title);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(menuItems, findsNothing);
    for (final label in ['Rename', 'Pin', 'Archive', 'Delete', 'Cancel']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
