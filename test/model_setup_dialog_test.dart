import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/widgets/model_setup_dialog.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('the setup dialog stays within the dialog cap on an iPad '
        'sized screen ($platform)', (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModelSetup(context, 'default'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Set up a model'), findsOneWidget);
      final dialog = find.byType(
        platform == TargetPlatform.iOS ? CupertinoAlertDialog : AlertDialog,
      );
      expect(dialog, findsOneWidget);
      // The alert widget is laid out at the window's width; measure the panel
      // the user sees: its first Material, or the command line's box on
      // Cupertino, whose panel is a fixed small width anyway.
      final panel = find.descendant(
        of: dialog,
        matching: find.byType(
          platform == TargetPlatform.iOS ? SelectableText : Material,
        ),
      );
      expect(tester.getSize(panel.first).width, lessThanOrEqualTo(560));
    });
  }
}
