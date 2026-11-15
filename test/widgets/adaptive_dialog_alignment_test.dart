import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

const _message = ValueKey('alert-message');

Future<void> _pump(WidgetTester tester, TargetPlatform platform) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      home: const Scaffold(
        body: AppAlertDialog(
          title: Text('Restart the gateway?'),
          content: Text(
            'Running chats stop and reconnect. This can take a moment.',
            key: _message,
          ),
        ),
      ),
    ),
  );
}

TextAlign _paragraphAlign(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.byKey(_message)).textAlign;

TextAlign _inheritedAlign(WidgetTester tester) =>
    DefaultTextStyle.of(tester.element(find.byKey(_message))).textAlign ??
    TextAlign.start;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('alert message is centred on $platform', (tester) async {
      await _pump(tester, platform);
      expect(_inheritedAlign(tester), TextAlign.center);
      expect(_paragraphAlign(tester), TextAlign.center);
    });

    testWidgets('alert message uses the Cupertino 13 pt size on $platform', (
      tester,
    ) async {
      await _pump(tester, platform);
      final style = DefaultTextStyle.of(tester.element(find.byKey(_message)));
      expect(style.style.fontSize, 13);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(_message),
      );
      expect(paragraph.text.style?.fontSize ?? style.style.fontSize, 13);
    });
  }

  testWidgets('alert message is start-aligned on Material', (tester) async {
    await _pump(tester, TargetPlatform.android);
    expect(_inheritedAlign(tester), TextAlign.start);
    expect(_paragraphAlign(tester), TextAlign.start);
  });

  testWidgets('field content still lays out on Apple platforms', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: AppAlertDialog(
            title: const Text('New board'),
            content: Column(
              children: [
                const Text('Name it'),
                AppDialogTextField(controller: controller, hint: 'Name'),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(EditableText), findsOneWidget);
  });
}
