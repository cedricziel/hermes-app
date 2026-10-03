import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';

import 'support/pump_chat.dart';

void main() {
  testWidgets('the message column stops at a readable width on a wide window', (
    tester,
  ) async {
    await pumpChatScreen(tester);

    final chat = tester.getRect(find.byType(Chat));
    final composer = tester.getRect(find.byKey(chatComposerFieldKey));

    expect(chat.width, 680);
    expect(composer.left, greaterThanOrEqualTo(chat.left));
    expect(composer.right, lessThanOrEqualTo(chat.right));
  });
}
