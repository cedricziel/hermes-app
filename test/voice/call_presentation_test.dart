import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/call_presentation.dart';

Future<void> _open(
  WidgetTester tester, {
  required Size size,
  required TargetPlatform platform,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showVoiceCall(
            context,
            builder: (_) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Show chat'),
                ),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a phone gets a full-screen page', (tester) async {
    await _open(
      tester,
      size: const Size(400, 800),
      platform: TargetPlatform.android,
    );
    expect(find.byKey(const Key('voice-call-dialog')), findsNothing);
    expect(find.text('Show chat'), findsOneWidget);
    await tester.tap(find.text('Show chat'));
    await tester.pumpAndSettle();
    expect(find.text('Show chat'), findsNothing);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.iOS,
  ]) {
    testWidgets('$platform at 760 pt gets a 480 pt dialog', (tester) async {
      await _open(tester, size: const Size(760, 900), platform: platform);
      final dialog = find.byKey(const Key('voice-call-dialog'));
      expect(dialog, findsOneWidget);
      expect(
        tester
            .getSize(
              find
                  .descendant(of: dialog, matching: find.byType(SizedBox))
                  .first,
            )
            .width,
        480,
      );
    });

    testWidgets('$platform below 760 pt gets a page', (tester) async {
      await _open(tester, size: const Size(759, 900), platform: platform);
      expect(find.byKey(const Key('voice-call-dialog')), findsNothing);
    });
  }

  testWidgets('every Mac width gets a dialog, never a sheet', (tester) async {
    await _open(
      tester,
      size: const Size(480, 700),
      platform: TargetPlatform.macOS,
    );
    expect(find.byKey(const Key('voice-call-dialog')), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('Escape and Show chat close the dialog', (tester) async {
    await _open(
      tester,
      size: const Size(1000, 800),
      platform: TargetPlatform.macOS,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice-call-dialog')), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show chat'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice-call-dialog')), findsNothing);
  });

  test('only iOS, macOS and Windows have a settings link', () {
    expect(canOpenMicrophoneSettings(TargetPlatform.iOS), isTrue);
    expect(canOpenMicrophoneSettings(TargetPlatform.macOS), isTrue);
    expect(canOpenMicrophoneSettings(TargetPlatform.windows), isTrue);
    expect(canOpenMicrophoneSettings(TargetPlatform.android), isFalse);
    expect(canOpenMicrophoneSettings(TargetPlatform.linux), isFalse);
  });
}
