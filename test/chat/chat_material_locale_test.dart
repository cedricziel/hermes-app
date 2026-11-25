import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer_builder.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump_chat.dart';

void main() {
  // The chat sits under `FlyerMaterialScope`, which once replaced the app's
  // Material localizations with English ones for everything below it.
  testWidgets('Material labels inside the chat are in the app language', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpChatScreen(tester);

    final field = find.descendant(
      of: find.byType(FlyerMaterialScope),
      matching: composerField,
    );
    expect(field, findsOneWidget);
    // What a Material widget at this place in the chat labels itself with.
    final labels = MaterialLocalizations.of(tester.element(field));
    expect(labels.pasteButtonLabel, 'Einsetzen');
    expect(labels.selectAllButtonLabel, 'Alle auswählen');
  });
}
