import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_chat_context.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/chat_suggestions.dart';

import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

const bot = BotModeBot(serverId: 'fixture', name: 'research', revision: 1);
const writer = BotModeBot(
  serverId: 'fixture',
  name: 'writer',
  revision: 1,
  displayName: 'Writer',
);

void main() {
  for (final (label, platform, size, brightness) in [
    ('ios', TargetPlatform.iOS, phoneSize, Brightness.light),
    ('ios-dark', TargetPlatform.iOS, phoneSize, Brightness.dark),
    ('mac', TargetPlatform.macOS, desktopSize, Brightness.light),
    ('mac-dark', TargetPlatform.macOS, desktopSize, Brightness.dark),
  ]) {
    testWidgets('autocomplete insertion and keyboard $label', (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      final sent = <String>[];
      final shots = ScreenshotRecorder('autocomplete-$label');
      await pumpScreen(
        tester,
        shots,
        Material(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ChatComposer(
              controller: controller,
              focusNode: focus,
              onSend: sent.add,
              onRemoveAttachment: (_) {},
              slashCommands: const [
                SlashCommand('/help', 'Show command help'),
                SlashCommand('/model', 'Change the model'),
                SlashCommand('/new', 'Start a chat'),
                SlashCommand('/reset', 'Reset the conversation'),
                SlashCommand('/status', 'Show status'),
                SlashCommand('/skills', 'Show skills'),
                SlashCommand('/config', 'Show configuration'),
                SlashCommand('/version', 'Show version'),
              ],
              botContext: const BotChatContext(
                bot: bot,
                rootId: 'fixture',
                storedId: 'fixture',
                peers: [bot, writer],
              ),
            ),
          ),
        ),
        size: size,
        platform: platform,
        brightness: brightness,
      );
      await tester.enterText(
        find.byType(EditableText),
        'Ask @wr then continue',
      );
      controller.selection = const TextSelection.collapsed(offset: 7);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'teammate');
      await tester.tap(find.text('@writer'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Ask @writer  then continue');
      expect(controller.selection.baseOffset, 12);
      expect(focus.hasFocus, isTrue);
      expect(sent, isEmpty);
      await tester.enterText(find.byType(EditableText), '/');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'commands');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(controller.text, '/model ');
      expect(focus.hasFocus, isTrue);
      expect(sent, isEmpty);
      await shots.capture(tester, 'completed');
      await tester.enterText(find.byType(EditableText), '/');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      final panel = tester.getRect(find.byType(ChatSuggestions));
      final last = tester.getRect(find.text('/version'));
      expect(last.top, greaterThanOrEqualTo(panel.top));
      expect(last.bottom, lessThanOrEqualTo(panel.bottom));
      expect(focus.hasFocus, isTrue);
      await shots.capture(tester, 'last-command-visible');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(controller.text, '/version ');
      expect(sent, isEmpty);
    });
  }
}
