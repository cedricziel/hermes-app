import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/starter_prompts.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer_builder.dart';
import 'package:hermes_app/src/chat/widgets/welcome_view.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _homeIndicator = 34.0;
const _keyboard = 336.0;
const _dpr = 3.0;

Future<void> _pump(
  WidgetTester tester, {
  required double keyboard,
  List<Message> messages = const [],
  List<StarterPrompt> prompts = const [],
}) async {
  tester.view.devicePixelRatio = _dpr;
  tester.view.physicalSize = const Size(393 * _dpr, 852 * _dpr);
  tester.view.padding = FakeViewPadding(
    top: 59 * _dpr,
    bottom: (keyboard > 0 ? 0 : _homeIndicator) * _dpr,
  );
  tester.view.viewPadding = FakeViewPadding(
    top: 59 * _dpr,
    bottom: _homeIndicator * _dpr,
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * _dpr);
  addTearDown(tester.view.reset);
  final chatController = InMemoryChatController(messages: messages);
  final text = TextEditingController();
  addTearDown(() {
    chatController.dispose();
    text.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: FlyerMaterialScope(
          child: Chat(
            currentUserId: 'user',
            resolveUser: (id) async => User(id: id),
            chatController: chatController,
            builders:
                buildChatBuilders(
                  onPickPrompt: (_) {},
                  starterPrompts: prompts,
                ).copyWith(
                  composerBuilder: buildChatComposer(
                    controller: text,
                    attachments: const [],
                    onRemoveAttachment: (_) {},
                  ),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('sits right above the keyboard when it is up', (tester) async {
    await _pump(tester, keyboard: _keyboard);
    final bottom = tester.getBottomLeft(find.byType(ChatComposer)).dy;
    expect(bottom, closeTo(852 - _keyboard, 0.5));
  });

  testWidgets('clears the home indicator when the keyboard is down', (
    tester,
  ) async {
    await _pump(tester, keyboard: 0);
    final bottom = tester.getBottomLeft(find.byType(ChatComposer)).dy;
    expect(bottom, closeTo(852 - _homeIndicator, 0.5));
  });

  testWidgets('the composer background reaches the screen edge', (
    tester,
  ) async {
    await _pump(tester, keyboard: 0);
    final slot = find
        .ancestor(
          of: find.byType(ChatComposer),
          matching: find.byType(ColoredBox),
        )
        .first;
    expect(tester.getBottomLeft(slot).dy, closeTo(852, 0.5));
  });

  for (final count in [0, 1, 30]) {
    testWidgets('dragging down dismisses the keyboard with $count messages', (
      tester,
    ) async {
      await _pump(
        tester,
        keyboard: _keyboard,
        messages: [
          for (var i = 0; i < count; i++)
            TextMessage(id: '$i', authorId: 'assistant', text: 'Message $i'),
        ],
      );
      await _expectDragDismisses(tester, count == 0);
    });
  }

  testWidgets('dragging the welcome prompts dismisses the keyboard', (
    tester,
  ) async {
    await _pump(tester, keyboard: _keyboard, prompts: kGenericStarterPrompts);
    await _expectDragDismisses(tester, true);
  });
}

Future<void> _expectDragDismisses(WidgetTester tester, bool welcome) async {
  final field = find.descendant(
    of: find.byKey(chatComposerFieldKey),
    matching: find.byType(EditableText),
  );
  await tester.enterText(field, 'Keep this draft');
  await tester.pump();
  final editable = tester.widget<EditableText>(field);
  expect(editable.focusNode.hasFocus, isTrue);
  expect(tester.testTextInput.isVisible, isTrue);

  final scroll = welcome
      ? find.descendant(
          of: find.byType(WelcomeView),
          matching: find.byType(SingleChildScrollView),
        )
      : find.byType(CustomScrollView);
  // Start above the composer, including the blank space in a short thread.
  await tester.dragFrom(
    tester.getTopLeft(scroll) + const Offset(30, 60),
    const Offset(0, 100),
  );
  await tester.pump(const Duration(milliseconds: 300));

  expect(editable.focusNode.hasFocus, isFalse);
  expect(tester.testTextInput.isVisible, isFalse);
  expect(editable.controller.text, 'Keep this draft');
}
