import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';

Future<void> _open(
  WidgetTester tester,
  TargetPlatform platform,
  bool? dismissible,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppDialog<void>(
            context: context,
            barrierDismissible: dismissible,
            builder: (_) => const AlertDialog(content: Text('Body')),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(find.text('Body'), findsOneWidget);
  await tester.tapAt(const Offset(4, 4));
  await tester.pumpAndSettle();
}

void main() {
  // Today's defaults: Material and macOS close on a barrier tap, iOS
  // (showAdaptiveDialog) does not.
  const defaults = {
    TargetPlatform.android: true,
    TargetPlatform.iOS: false,
    TargetPlatform.macOS: true,
  };
  for (final entry in defaults.entries) {
    testWidgets('${entry.key.name}: the default keeps the platform way', (
      tester,
    ) async {
      await _open(tester, entry.key, null);
      expect(find.text('Body'), entry.value ? findsNothing : findsOneWidget);
    });
    testWidgets('${entry.key.name}: false keeps the dialog open', (
      tester,
    ) async {
      await _open(tester, entry.key, false);
      expect(find.text('Body'), findsOneWidget);
    });
  }
}
