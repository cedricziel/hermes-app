import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Finder grip() => find.byTooltip('Drag message text');

  Future<void> hover(WidgetTester tester, Finder target, {Offset? at}) async {
    final to = at ?? tester.getCenter(target);
    if (mouse == null) {
      final created = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(created.removePointer);
      await created.addPointer(location: to);
      mouse = created;
    } else {
      await mouse!.moveTo(to);
    }
    await tester.pump();
  }

  Future<void> pumpGrip(
    WidgetTester tester, {
    String text = '# Title\n\nSome **bold** text',
    bool withSource = true,
    bool enabled = true,
  }) async {
    final child = MessageDragGrip(
      text: text,
      enabled: enabled,
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
      await pumpGrip(tester);
      expect(grip(), findsNothing);

      await hover(tester, find.text('message'));

      expect(grip(), findsOneWidget);
    });

    testWidgets('the grip is beside the message, never over it', (
      tester,
    ) async {
      await pumpGrip(tester);
      await hover(tester, find.text('message'));

      final message = tester.getRect(
        find
            .ancestor(of: find.text('message'), matching: find.byType(SizedBox))
            .first,
      );
      final handle = tester.getRect(grip());
      expect(handle.left, greaterThanOrEqualTo(message.right));
      expect(handle.width, lessThanOrEqualTo(kMessageGripGutter));
    });

    testWidgets('the grip can be reached from the message', (tester) async {
      await pumpGrip(tester);
      await hover(tester, find.text('message'));

      await hover(tester, grip());

      expect(grip(), findsOneWidget, reason: 'still shown over its own gutter');
    });

    testWidgets('drags out the Markdown source as text', (tester) async {
      await pumpGrip(tester);
      await hover(tester, find.text('message'));

      expect(source.wraps.single.kind, DragOutKind.text);
      final item = source.lastItem;
      expect(item, isA<DragOutText>());
      expect((item as DragOutText).text, '# Title\n\nSome **bold** text');
    });

    testWidgets('is the child itself without drag-out', (tester) async {
      await pumpGrip(tester, withSource: false);
      final width = tester.getSize(find.byType(MessageDragGrip)).width;
      await hover(tester, find.text('message'));

      expect(grip(), findsNothing);
      expect(width, 300, reason: 'no gutter is reserved');
    });

    testWidgets('is the child itself for a message with no text', (
      tester,
    ) async {
      await pumpGrip(tester, text: '');
      await hover(tester, find.text('message'));

      expect(grip(), findsNothing);
      expect(source.wraps, isEmpty);
    });

    testWidgets('disabled it keeps the gutter but shows no grip', (
      tester,
    ) async {
      await pumpGrip(tester, enabled: false);
      await hover(tester, find.text('message'));

      expect(grip(), findsNothing);
      expect(source.wraps, isEmpty);
      expect(
        tester.getSize(find.byType(MessageDragGrip)).width,
        300 + kMessageGripGutter,
        reason: 'the message does not jump when the reply finishes',
      );
    });
  });

  group('in the transcript', () {
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

    Future<InMemoryChatController> pumpTranscript(
      WidgetTester tester,
      List<ChatMessage> messages,
    ) async {
      final controller = InMemoryChatController(
        messages: [for (final m in messages) ...chatMessageToFlyer(m)],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
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
      return controller;
    }

    Finder text(String start) =>
        find.textContaining(start, findRichText: true).first;

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

      await hover(tester, text('Question'));
      expect(grip(), findsOneWidget);
      await hover(tester, text('Answer'));
      expect(grip(), findsOneWidget);

      expect(dragged().toSet(), {'Question', 'Answer **bold**'});
    });

    testWidgets('a reply has a grip once it has finished, not while it '
        'streams', (tester) async {
      final controller = await pumpTranscript(tester, [
        message(
          '2',
          ChatRole.assistant,
          'Half an ans',
          status: MessageStatus.streaming,
        ),
      ]);
      await hover(tester, text('Half'));
      expect(grip(), findsNothing);
      expect(dragged(), isEmpty);

      await controller.updateMessage(
        controller.messages.single,
        chatMessageToFlyer(message('2', ChatRole.assistant, 'Half an answer'))
            .single,
      );
      await tester.pump(const Duration(milliseconds: 500));
      // The row may be a new one: leave it and come back.
      await hover(tester, find.byType(Chat), at: const Offset(2, 2));
      await hover(tester, text('Half'));

      expect(grip(), findsOneWidget);
      expect(dragged(), ['Half an answer']);
    });

    testWidgets('text can be selected from its far end while the grip is '
        'shown', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final words = List.generate(60, (i) => 'word$i').join(' ');
      await pumpTranscript(tester, [message('2', ChatRole.assistant, words)]);
      final reply = text('word0');
      final box = tester.getRect(reply);

      // Hover so the grip is shown, then select from the right end of the
      // first line (where a grip laid over the text would sit) to its start.
      await hover(tester, reply);
      expect(grip(), findsOneWidget);
      final start = Offset(box.right - 3, box.top + 8);
      final selecting = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await selecting.moveTo(Offset(box.left + 2, box.top + 8));
      await selecting.up();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();

      debugDefaultTargetPlatformOverride = null;

      expect(copied, isNotEmpty);
      expect(copied.last, startsWith('word0'));
      expect(copied.last.split(' ').length, greaterThan(3));
    });
  });
}
