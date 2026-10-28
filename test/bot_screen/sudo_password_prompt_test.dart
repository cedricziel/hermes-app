import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/widgets/sudo_password_prompt.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  late TextEditingController controller;
  late List<String> answered;
  var cancelled = 0;

  setUp(() {
    controller = TextEditingController();
    answered = [];
    cancelled = 0;
  });

  tearDown(() => controller.dispose());

  Future<void> pump(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      home: Scaffold(
        body: SudoPasswordPrompt(
          host: 'hermes.example.com',
          controller: controller,
          onInstall: answered.add,
          onCancel: () => cancelled++,
        ),
      ),
    ),
  );

  EditableText field(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    group('on $platform', () {
      testWidgets('the field is obscured and offers nothing to remember', (
        tester,
      ) async {
        await pump(tester, platform: platform);

        final text = field(tester);
        expect(text.obscureText, isTrue);
        expect(text.autocorrect, isFalse);
        expect(text.enableSuggestions, isFalse);
        expect(text.enableIMEPersonalizedLearning, isFalse);
        // Cupertino hands autofill to the platform through its own client, so
        // its widget is where "off" is visible.
        expect(
          platform == TargetPlatform.android
              ? text.autofillHints
              : tester
                    .widget<CupertinoTextField>(find.byType(CupertinoTextField))
                    .autofillHints,
          isNull,
        );
        expect(text.keyboardType, TextInputType.visiblePassword);
        expect(text.smartDashesType, SmartDashesType.disabled);
        expect(text.smartQuotesType, SmartQuotesType.disabled);
        expect(text.readOnly, isFalse);
      });

      testWidgets('names the host and says the password is not kept', (
        tester,
      ) async {
        await pump(tester, platform: platform);

        expect(find.textContaining('hermes.example.com'), findsOne);
        expect(find.textContaining('not stored'), findsOne);
      });

      testWidgets('Install answers the password once and clears the field', (
        tester,
      ) async {
        await pump(tester, platform: platform);

        await tester.enterText(find.byType(EditableText), 'hunter2');
        await tester.pump();
        await tester.tap(find.text('Install'));
        await tester.pump();
        await tester.tap(find.text('Install'), warnIfMissed: false);
        await tester.pump();

        expect(answered, ['hunter2']);
        expect(controller.text, isEmpty);
        expect(cancelled, 0);
      });

      testWidgets('Install waits for a password', (tester) async {
        await pump(tester, platform: platform);

        await tester.tap(find.text('Install'));
        await tester.pump();

        expect(answered, isEmpty);
      });

      testWidgets('Cancel answers nothing and clears the field', (
        tester,
      ) async {
        await pump(tester, platform: platform);
        await tester.enterText(find.byType(EditableText), 'hunter2');
        await tester.pump();

        await tester.tap(find.text('Cancel'));
        await tester.pump();

        expect(cancelled, 1);
        expect(answered, isEmpty);
        expect(controller.text, isEmpty);
      });

      testWidgets('the keyboard\'s done key answers too', (tester) async {
        await pump(tester, platform: platform);
        await tester.enterText(find.byType(EditableText), 'hunter2');

        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(answered, ['hunter2']);
      });
    });
  }

  testWidgets('iOS uses the Cupertino field', (tester) async {
    await pump(tester, platform: TargetPlatform.iOS);

    expect(find.byType(CupertinoTextField), findsOne);
  });

  testWidgets('Material uses the Material field', (tester) async {
    await pump(tester);

    expect(find.byType(TextField), findsOne);
  });
}
