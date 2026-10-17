import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/new_chat_fab.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

void main() {
  testWidgets('iPhone shortcut opens and focuses an unsent new chat', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final transport = FakeChatTransport();
    await pumpChatScreen(
      tester,
      platform: TargetPlatform.iOS,
      size: const Size(400, 800),
      transport: transport,
    );

    final fab = find.byType(NewChatFab);
    expect(fab, findsOneWidget);
    expect(tester.getBottomRight(fab), const Offset(384, 750));
    expect(find.byTooltip('New message'), findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(composerField, findsOneWidget);
    expect(
      tester.widget<EditableText>(composerField).focusNode.hasFocus,
      isTrue,
    );
    expect(transport.sends, isEmpty);
    expect(fab, findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fab, findsOneWidget);
  });

  for (final (platform, size) in [
    (TargetPlatform.iOS, const Size(834, 1194)),
    (TargetPlatform.android, const Size(400, 800)),
    (TargetPlatform.macOS, const Size(1000, 800)),
  ]) {
    testWidgets('no floating shortcut for ${platform.name} at $size', (
      tester,
    ) async {
      await pumpChatScreen(tester, platform: platform, size: size);
      expect(find.byType(NewChatFab), findsNothing);
    });
  }

  testWidgets(
    'shortcut keeps recipient selection and cancellation draft-safe',
    (tester) async {
      final transport = FakeChatTransport();
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/profiles',
          profileListBody([
            profileRow(
              name: 'default',
              displayName: 'Personal',
              isDefault: true,
            ),
            profileRow(name: 'work', displayName: 'Work'),
          ]),
        )
        ..on(
          'GET',
          '/api/profiles/active',
          activeProfileBody(active: 'default'),
        )
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([
            sessionRow(id: 'personal', title: 'Personal notes'),
          ]),
          query: {'profile': 'default'},
        )
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([]),
          query: {'profile': 'work'},
        )
        ..on(
          'GET',
          '/api/sessions/personal/messages',
          messageListBody('personal', []),
        );
      await pumpChatScreen(
        tester,
        server: server,
        transport: transport,
        withProfiles: true,
        platform: TargetPlatform.iOS,
        size: const Size(400, 800),
      );
      await tester.tap(find.byKey(const ValueKey('thread-personal')));
      await tester.pumpAndSettle();
      await tester.enterText(composerField, 'Keep my draft');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NewChatFab));
      await tester.pumpAndSettle();
      expect(find.byType(RecipientPicker), findsOneWidget);
      Navigator.of(tester.element(find.byType(RecipientPicker))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('thread-personal')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(composerField).controller.text,
        'Keep my draft',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NewChatFab));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(RecipientPicker),
          matching: find.text('Work'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(composerField).controller.text,
        isEmpty,
      );
      expect(
        tester.widget<EditableText>(composerField).focusNode.hasFocus,
        isTrue,
      );
      expect(transport.sends, isEmpty);
    },
  );

  testWidgets('the final chat can scroll above the floating shortcut', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          for (var i = 0; i < 30; i++)
            sessionRow(
              id: 'chat-$i',
              title: 'Conversation $i',
              lastActive: 1760000000.0 - i,
            ),
        ]),
      );
    await pumpChatScreen(
      tester,
      server: server,
      platform: TargetPlatform.iOS,
      size: const Size(400, 800),
    );
    final list = find.descendant(
      of: find.byType(ThreadSidebar),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    final position = tester.state<ScrollableState>(list).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    final lastRow = find.byKey(const ValueKey('thread-chat-29'));
    expect(lastRow, findsOneWidget);
    expect(
      tester.getBottomRight(lastRow).dy,
      lessThan(tester.getTopLeft(find.byType(NewChatFab)).dy),
    );
  });

  testWidgets('the final search result can scroll above the shortcut', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/sessions/search', {
        'results': [
          for (var i = 0; i < 30; i++)
            {
              'id': 'result-$i',
              'title': 'Matching conversation $i',
              'snippet': 'A matching message',
              'session_started': 1760000000 - i,
            },
        ],
      });
    await pumpChatScreen(
      tester,
      server: server,
      platform: TargetPlatform.iOS,
      size: const Size(400, 800),
    );
    await tester.enterText(
      find.byKey(const Key('thread-search-field')),
      'matching',
    );
    await tester.pump(ThreadSearch.defaultDebounce);
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byType(ThreadSidebar),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    final position = tester.state<ScrollableState>(list).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(
      tester
          .getBottomRight(find.byKey(const ValueKey('search-hit-result-29')))
          .dy,
      lessThan(tester.getTopLeft(find.byType(NewChatFab)).dy),
    );
  });
}
