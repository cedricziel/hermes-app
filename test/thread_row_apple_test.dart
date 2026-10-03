import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// Thread rows follow the platform: swipe actions, a long-press sheet and 44pt
/// rows on iOS; the "more" button stays on macOS and Material.
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

  group('on iOS', () {
    Future<void> pump(WidgetTester tester) =>
        pumpChatScreen(tester, server: server, platform: TargetPlatform.iOS);

    testWidgets('the row has no inline more button and is 44pt tall', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byTooltip('Chat actions'), findsNothing);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
    });

    testWidgets('a long press opens an action sheet with every action', (
      tester,
    ) async {
      await pump(tester);

      await tester.longPress(title);
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      for (final label in ['Rename', 'Pin', 'Archive', 'Delete', 'Cancel']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('the sheet pins the thread', (tester) async {
      await pump(tester);

      await tester.longPress(title);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();

      final request = server.requestsTo('PATCH', '/api/sessions/s2').single;
      expect(jsonBody(request), {'pinned': true});
    });

    testWidgets('swiping right reveals Pin', (tester) async {
      await pump(tester);

      await tester.drag(title, const Offset(200, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('PATCH', '/api/sessions/s2'), hasLength(1));
    });

    testWidgets('swiping left reveals Delete, which still confirms', (
      tester,
    ) async {
      await pump(tester);

      await tester.drag(title, const Offset(-200, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this chat?'), findsOneWidget);
      expect(server.requestsTo('DELETE', '/api/sessions/s2'), isEmpty);
    });

    group('inside the phone drawer', () {
      Future<void> openDrawer(WidgetTester tester) async {
        await pump(tester);
        tester.view.physicalSize = const Size(393, 852);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.menu).first);
        await tester.pumpAndSettle();
      }

      testWidgets('a left drag on a row reveals Delete, drawer stays', (
        tester,
      ) async {
        await openDrawer(tester);

        await tester.drag(title, const Offset(-150, 0));
        await tester.pumpAndSettle();

        expect(find.text('Delete'), findsOneWidget);
        expect(title.hitTestable(), findsOneWidget);
        expect(find.byType(Drawer), findsOneWidget);
      });

      testWidgets('a left drag on empty drawer space closes it', (
        tester,
      ) async {
        await openDrawer(tester);

        await tester.flingFrom(
          const Offset(150, 600),
          const Offset(-150, 0),
          1000,
        );
        await tester.pumpAndSettle();

        expect(find.byType(Drawer), findsNothing);
      });
    });

    testWidgets('VoiceOver gets every action', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final data = tester.getSemantics(row).getSemanticsData();
      final labels = [
        for (final id in data.customSemanticsActionIds!)
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(labels, containsAll(['Rename', 'Pin', 'Archive', 'Delete']));
      handle.dispose();
    });
  });

  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets('on $platform the more button stays and rows stay compact', (
      tester,
    ) async {
      await pumpChatScreen(tester, server: server, platform: platform);

      expect(find.byTooltip('Chat actions'), findsOneWidget);
      expect(tester.getSize(row).height, lessThan(44));
    });
  }
}
