import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/widgets/scroll_to_latest_button.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ComposerHeightNotifier;
import 'package:provider/provider.dart';

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
    theme: buildHermesLightTheme(platform: TargetPlatform.android),
    size: const Size(411, 891),
  );

  testWidgets('the chat list meets the Android tap target guideline', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    final decorator = find.descendant(
      of: find.byKey(const Key('thread-search-field')),
      matching: find.byType(InputDecorator),
    );
    expect(tester.getSize(decorator).height, greaterThanOrEqualTo(48));
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
    expect(find.byTooltip('Copy'), findsWidgets);
    for (final tip in ['Copy', 'Try again']) {
      for (final element in find.byTooltip(tip).evaluate()) {
        final size = (element.renderObject! as RenderBox).size;
        expect(size.width, greaterThanOrEqualTo(48), reason: tip);
        expect(size.height, greaterThanOrEqualTo(48), reason: tip);
      }
    }
  });

  testWidgets(
    'the hidden jump-to-latest button is out of semantics and inert',
    (tester) async {
      final handle = tester.ensureSemantics();
      final animation = AnimationController(vsync: const TestVSync(), value: 0);
      addTearDown(animation.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.android),
          home: ChangeNotifierProvider(
            create: (_) => ComposerHeightNotifier(),
            child: Stack(
              children: [
                ScrollToLatestButton(animation: animation, onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(FloatingActionButton).evaluate().length, 1);
      expect(find.semantics.byLabel('Scroll to latest message'), findsNothing);
      final ignore = tester.widget<IgnorePointer>(
        find
            .descendant(
              of: find.byType(ScrollToLatestButton),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignore.ignoring, isTrue);

      animation.value = 1;
      await tester.pump();
      expect(
        find.semantics.byLabel('Scroll to latest message'),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  group('desktop sizes stay as they were', () {
    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      testWidgets('rows, search and message actions on $platform', (
        tester,
      ) async {
        await pumpChatScreen(
          tester,
          server: server,
          platform: platform,
          theme: buildHermesLightTheme(platform: platform),
          size: const Size(411, 891),
        );
        final row = find.byKey(const ValueKey('thread-s2'));
        expect(tester.getSize(row).height, 32);
        final more = find.descendant(
          of: row,
          matching: find.byTooltip('Chat actions'),
        );
        expect(tester.getSize(more).width, 28);
        final search = find.descendant(
          of: find.byKey(const Key('thread-search-field')),
          matching: find.byType(InputDecorator),
        );
        expect(tester.getSize(search).height, 28);
        await tester.tap(row);
        await tester.pumpAndSettle();
        for (final element in find.byTooltip('Copy').evaluate()) {
          expect((element.renderObject! as RenderBox).size, const Size(24, 24));
        }
      });
    }
  });
}
