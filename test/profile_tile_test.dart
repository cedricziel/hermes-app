import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/widgets/profile_tile.dart';

const _work = HermesProfile(name: 'work', skillCount: 3);

Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform, {
  bool active = false,
  VoidCallback? onChangeModel,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: ProfileTile(
        profile: _work,
        active: active,
        onTap: () {},
        onChangeModel: onChangeModel,
      ),
    ),
  ),
);

void main() {
  group('on iOS', () {
    testWidgets('marks the active profile with a checkmark, not a chip', (
      tester,
    ) async {
      await _pump(tester, TargetPlatform.iOS, active: true);

      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
      expect(find.byIcon(Icons.person_outline), findsNothing);
    });

    testWidgets('shows no checkmark on an inactive profile', (tester) async {
      await _pump(tester, TargetPlatform.iOS);

      expect(find.byIcon(CupertinoIcons.check_mark), findsNothing);
    });

    testWidgets('is a standard row, shorter than the Material tile', (
      tester,
    ) async {
      await _pump(tester, TargetPlatform.iOS);

      final height = tester.getSize(find.byType(ListTile)).height;
      expect(height, greaterThanOrEqualTo(44));
      expect(height, lessThan(72));
    });

    testWidgets('changes the model from a long-press action sheet', (
      tester,
    ) async {
      var changed = 0;
      await _pump(tester, TargetPlatform.iOS, onChangeModel: () => changed++);
      expect(find.byIcon(Icons.tune), findsNothing);

      await tester.longPress(find.byType(ListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change default model'));
      await tester.pumpAndSettle();

      expect(changed, 1);
    });

    testWidgets('offers the model change to VoiceOver as a custom action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, TargetPlatform.iOS, onChangeModel: () {});

      expect(
        find.semantics.byAction(SemanticsAction.customAction),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('has no long-press without a model change', (tester) async {
      await _pump(tester, TargetPlatform.iOS);

      await tester.longPress(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.text('Change default model'), findsNothing);
    });
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    testWidgets('keeps the Material tile on $platform', (tester) async {
      await _pump(tester, platform, active: true, onChangeModel: () {});

      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.check_mark), findsNothing);
    });
  }
}
