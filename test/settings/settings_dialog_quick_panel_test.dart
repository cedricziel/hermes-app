import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/quick_panel/global_shortcut.dart';
import 'package:hermes_app/src/settings/settings_dialog.dart';
import 'package:provider/provider.dart';

import '../support/fake_global_shortcut.dart';

void main() {
  // The native recorder is a platform view; answer its creation.
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        ),
  );

  Future<void> openSettings(
    WidgetTester tester,
    GlobalShortcut? shortcut,
  ) async {
    await tester.pumpWidget(
      Provider<GlobalShortcut?>.value(
        value: shortcut,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsDialog(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a Mac, which provides the shortcut, shows the Quick panel row', (
    tester,
  ) async {
    final shortcut = FakeGlobalShortcut();
    addTearDown(shortcut.dispose);

    await openSettings(tester, shortcut);

    expect(find.text('Quick panel'), findsOneWidget);
  });

  testWidgets('elsewhere there is no Quick panel row', (tester) async {
    await openSettings(tester, null);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Quick panel'), findsNothing);
  });
}
