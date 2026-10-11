import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/widgets/new_profile_dialog.dart';

import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

void main() {
  for (final (label, size, platform, brightness) in [
    ('phone', phoneSize, TargetPlatform.iOS, Brightness.light),
    ('desktop', desktopSize, TargetPlatform.macOS, Brightness.light),
    ('phone-dark', phoneSize, TargetPlatform.iOS, Brightness.dark),
    ('desktop-dark', desktopSize, TargetPlatform.macOS, Brightness.dark),
  ]) {
    testWidgets('profile creation $label', (tester) async {
      final shots = ScreenshotRecorder('profile-creation-$label');
      await pumpScreen(
        tester,
        shots,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showNewProfileDialog(context),
              child: const Text('New profile'),
            ),
          ),
        ),
        size: size,
        platform: platform,
        brightness: brightness,
      );
      await tester.tap(find.text('New profile'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'create');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  }
}
