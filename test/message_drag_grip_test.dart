import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/chat/widgets/message_drag_grip.dart';
import 'package:hermes_app/src/drag_out/drag_out_item.dart';
import 'package:hermes_app/src/drag_out/drag_out_source.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

import 'support/fake_drag_out_source.dart';

void main() {
  late FakeDragOutSource source;
  TestGesture? mouse;

  setUp(() {
    source = FakeDragOutSource();
    mouse = null;
  });

  Finder grip() => find.bySemanticsLabel('Drag message text');

  Future<void> hover(WidgetTester tester, Finder target) async {
    final at = tester.getCenter(target);
    if (mouse == null) {
      final created = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(created.removePointer);
      await created.addPointer(location: at);
      mouse = created;
    } else {
      await mouse!.moveTo(at);
    }
    await tester.pump();
  }

  Future<void> pumpGrip(
    WidgetTester tester, {
    String text = '# Title\n\nSome **bold** text',
    bool withSource = true,
  }) async {
    final child = MessageDragGrip(
      text: text,
      child: const SizedBox(width: 300, height: 80, child: Text('message')),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: Center(
            child: withSource
                ? Provider<DragOutSource?>.value(value: source, child: child)
                : child,
          ),
        ),
      ),
    );
  }

  group('MessageDragGrip', () {
    testWidgets('shows a grip on hover, not before', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpGrip(tester);
      expect(grip(), findsNothing);

      await hover(tester, find.text('message'));

      expect(grip(), findsOneWidget);
      handle.dispose();
    });

    testWidgets('drags out the Markdown source as text', (tester) async {
      await pumpGrip(tester);
      await hover(tester, find.text('message'));

      expect(source.wraps.single.kind, DragOutKind.text);
      final item = source.lastItem;
      expect(item, isA<DragOutText>());
      expect((item as DragOutText).text, '# Title\n\nSome **bold** text');
    });

    testWidgets('has no grip without drag-out', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpGrip(tester, withSource: false);
      await hover(tester, find.text('message'));

      expect(grip(), findsNothing);
      handle.dispose();
    });

    testWidgets('has no grip for a message with no text', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpGrip(tester, text: '');
      await hover(tester, find.text('message'));

      expect(grip(), findsNothing);
      expect(source.wraps, isEmpty);
      handle.dispose();
    });

    testWidgets('the message stays selectable text underneath', (tester) async {
      await pumpGrip(tester);

      expect(find.text('message'), findsOneWidget);
    });
  });

  group('in the transcript', () {
    Future<void> pumpTranscript(
      WidgetTester tester,
      List<ChatMessage> messages,
    ) async {
      final controller = InMemoryChatController(
        messages: [for (final m in messages) ...chatMessageToFlyer(m)],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Provider<DragOutSource?>.value(
            value: source,
            child: Scaffold(
              body: Chat(
                currentUserId: kUserAuthorId,
                resolveUser: (id) async => User(id: id),
                chatController: controller,
                builders: buildChatBuilders(onPickPrompt: (_) {})
                    .copyWith(composerBuilder: (_) => const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    ChatMessage message(
      String id,
      ChatRole role,
      String text, {
      MessageStatus status = MessageStatus.sent,
    }) => ChatMessage(
      id: id,
      role: role,
      content: text,
      createdAt: DateTime(2026, 1, 1),
      status: status,
    );

    List<String> dragged() => [
      for (final wrap in source.wraps)
        if (wrap.kind == DragOutKind.text) (wrap.item() as DragOutText).text,
    ];

    testWidgets('a finished reply and a sent message can be dragged', (
      tester,
    ) async {
      await pumpTranscript(tester, [
        message('1', ChatRole.user, 'Question'),
        message('2', ChatRole.assistant, 'Answer **bold**'),
      ]);
      final handle = tester.ensureSemantics();
      await hover(tester, find.text('Question'));
      await hover(tester, find.textContaining('Answer', findRichText: true));

      expect(dragged().toSet(), {'Question', 'Answer **bold**'});
      handle.dispose();
    });

    testWidgets('a reply still streaming has no grip', (tester) async {
      await pumpTranscript(tester, [
        message(
          '2',
          ChatRole.assistant,
          'Half an ans',
          status: MessageStatus.streaming,
        ),
      ]);

      expect(dragged(), isEmpty);
    });

    testWidgets('selecting text in a reply still works', (tester) async {
      await pumpTranscript(tester, [
        message('2', ChatRole.assistant, 'Answer one two three'),
      ]);

      final target = find.textContaining('Answer', findRichText: true);
      final gesture = await tester.startGesture(
        tester.getTopLeft(target) + const Offset(2, 8),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(60, 0));
      await gesture.up();
      await tester.pump();

      expect(find.byType(SelectionArea), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
