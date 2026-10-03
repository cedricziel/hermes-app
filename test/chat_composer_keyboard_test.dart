import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer_builder.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _homeIndicator = 34.0;
const _keyboard = 336.0;
const _dpr = 3.0;

Future<void> _pump(WidgetTester tester, {required double keyboard}) async {
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
  final chatController = InMemoryChatController();
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
            builders: Builders(
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

  testWidgets('dragging the thread dismisses the keyboard', (tester) async {
    await _pump(tester, keyboard: _keyboard);
    final lists = tester.widgetList<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    expect(
      lists.map((l) => l.keyboardDismissBehavior),
      contains(ScrollViewKeyboardDismissBehavior.onDrag),
    );
  });
}
