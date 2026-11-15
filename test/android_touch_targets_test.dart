import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// On Android the chat list and the message actions are touch-sized (48dp)
/// and every tappable node has a name.
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
        messageListBody('s2', [
          messageRow(id: 1, role: 'user', content: 'hi'),
          messageRow(id: 2, role: 'assistant', content: 'hello'),
        ]),
      );
  });

  Future<void> pump(WidgetTester tester) => pumpChatScreen(
    tester,
    server: server,
    platform: TargetPlatform.android,
    size: const Size(411, 891),
  );

  testWidgets('the chat list meets the Android tap target guideline', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(
      tester.getSize(find.byKey(const Key('thread-search-field'))).height,
      greaterThanOrEqualTo(48),
    );
    handle.dispose();
  });

  testWidgets('an open thread names every tappable node', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await tester.tap(find.text('Release notes'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the message action buttons are 48dp touch targets', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Release notes'));
    await tester.pumpAndSettle();
    final buttons = find.descendant(
      of: find.byType(Row),
      matching: find.byType(IconButton),
    );
    expect(find.byTooltip('Copy'), findsWidgets);
    for (final tip in ['Copy', 'Try again']) {
      for (final element in find.byTooltip(tip).evaluate()) {
        final size = (element.renderObject! as RenderBox).size;
        expect(size.width, greaterThanOrEqualTo(48), reason: tip);
        expect(size.height, greaterThanOrEqualTo(48), reason: tip);
      }
    }
    expect(buttons, findsWidgets);
  });

  group('desktop sizes stay as they were', () {
    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      testWidgets('rows, search and message actions on $platform', (
        tester,
      ) async {
        await pumpChatScreen(
          tester,
          server: server,
          platform: platform,
          size: const Size(411, 891),
        );
        final row = find.byKey(const ValueKey('thread-s2'));
        expect(tester.getSize(row).height, lessThan(44));
        final more = find.descendant(
          of: row,
          matching: find.byTooltip('Chat actions'),
        );
        expect(tester.getSize(more).width, 28);
        final search = find.byKey(const Key('thread-search-field'));
        if (search.evaluate().isNotEmpty) {
          expect(tester.getSize(search).height, lessThan(44));
        }
        await tester.tap(row);
        await tester.pumpAndSettle();
        for (final element in find.byTooltip('Copy').evaluate()) {
          expect(
            (element.renderObject! as RenderBox).size.width,
            lessThanOrEqualTo(40),
          );
        }
      });
    }
  });
}
