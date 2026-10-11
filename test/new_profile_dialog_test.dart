import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/widgets/new_profile_dialog.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.android,
  ]) {
    testWidgets('profile form validates and submits on $platform', (
      tester,
    ) async {
      NewProfile? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showNewProfileDialog(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupedDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('new-profile-name')),
        'bad/name',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('new-profile-name')),
        ' writer ',
      );
      await tester.enterText(
        find.byKey(const Key('new-profile-description')),
        ' Careful editing ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result, (name: 'writer', description: 'Careful editing'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  }
}
