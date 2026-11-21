import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_theme.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer_builder.dart';
import 'package:hermes_app/src/chat/widgets/chat_text_message.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';

import '../../support/markdown_contrast.dart';
import '../../support/screenshot_recorder.dart';

const _markdown =
    '## Next steps\n\nSee [the runbook](https://example.com/runbook) first.';

/// Mounts the chat as the app does: `MaterialUiThemeScope` from `app.dart`,
/// `FlyerMaterialScope` and `buildChatTheme` from the thread view.
Future<void> _pump(
  WidgetTester tester,
  ScreenshotRecorder shots,
  String authorId, {
  required bool dark,
}) async {
  await shots.start(tester, const Size(390, 400));
  final controller = InMemoryChatController(
    messages: [
      Message.text(
        id: 'm-1',
        authorId: authorId,
        text: _markdown,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    shots.frame(
      MaterialApp(
        theme: dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
        builder: (context, child) => MaterialUiThemeScope(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: FlyerMaterialScope(
              child: Chat(
                currentUserId: kUserAuthorId,
                resolveUser: (id) async => User(id: id),
                chatController: controller,
                theme: buildChatTheme(Theme.of(context)),
                builders: buildChatBuilders(onPickPrompt: (_) {})
                    .copyWith(composerBuilder: (_) => const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  for (final dark in [false, true]) {
    for (final author in [kAssistantAuthorId, kUserAuthorId]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('a link and heading in a $author message read in $mode', (
        tester,
      ) async {
        final shots = ScreenshotRecorder('chat-markdown-$author-$mode');
        await _pump(tester, shots, author, dark: dark);
        await shots.capture(tester, 'link-and-heading');
        final context = tester.element(find.byType(ChatTextMessage));
        final surface = Theme.of(context).colorScheme.surface;
        // The bubble the text really sits on: the user's is translucent.
        final message = tester.widget<ChatTextMessage>(
          find.byType(ChatTextMessage),
        );
        final bubble = Color.alphaBlend(message.backgroundColor, surface);
        for (final text in ['Next steps', 'the runbook']) {
          final ink = markdownInkOf(tester, text);
          expect(
            contrastRatio(ink, bubble),
            greaterThanOrEqualTo(4.5),
            reason: '$text: $ink on $bubble',
          );
        }
      });
    }
  }
}
