import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/widgets/profile_tile.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

const _work = HermesProfile(
  name: 'work',
  displayName: 'Work assistant',
  model: 'hermes-4',
  skillCount: 3,
  path: '/home/hermes/.hermes/profiles/work',
);

Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform, {
  HermesProfile profile = _work,
  bool active = false,
  VoidCallback? onChangeModel,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: ProfileTile(
        profile: profile,
        active: active,
        onTap: () {},
        onChangeModel: onChangeModel,
      ),
    ),
  ),
);

void main() {
  testWidgets('leads with the initials and shows home, model and skills', (
    tester,
  ) async {
    await _pump(tester, TargetPlatform.iOS);

    expect(
      find.descendant(of: find.byType(GroupedTile), matching: find.text('WA')),
      findsOneWidget,
    );
    expect(find.text('/home/hermes/.hermes/profiles/work'), findsOneWidget);
    expect(find.text('hermes-4 · 3 skills'), findsOneWidget);
  });

  testWidgets('prefers the description to the home', (tester) async {
    await _pump(
      tester,
      TargetPlatform.iOS,
      profile: const HermesProfile(
        name: 'work',
        description: 'Day job',
        path: '/home/hermes/.hermes/profiles/work',
      ),
    );

    expect(find.text('Day job'), findsOneWidget);
    expect(find.text('/home/hermes/.hermes/profiles/work'), findsNothing);
  });

  group('on iOS', () {
    testWidgets('marks the active profile with a checkmark', (tester) async {
      await _pump(tester, TargetPlatform.iOS, active: true);

      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
      expect(find.text('Active'), findsNothing);
    });

    testWidgets('shows no checkmark on an inactive profile', (tester) async {
      await _pump(tester, TargetPlatform.iOS);

      expect(find.byIcon(CupertinoIcons.check_mark), findsNothing);
    });

    testWidgets('is a grouped row of at least 44 points', (tester) async {
      await _pump(tester, TargetPlatform.iOS);

      final height = tester.getSize(find.byType(GroupedRow)).height;
      expect(height, greaterThanOrEqualTo(44));
    });

    testWidgets('changes the model from a long-press action sheet', (
      tester,
    ) async {
      var changed = 0;
      await _pump(tester, TargetPlatform.iOS, onChangeModel: () => changed++);
      expect(find.byKey(const Key('profile-model-work')), findsNothing);

      await tester.longPress(find.byType(GroupedRow));
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

      await tester.longPress(find.byType(GroupedRow));
      await tester.pumpAndSettle();

      expect(find.text('Change default model'), findsNothing);
    });
  });

  testWidgets('says Active and offers the model button on Android', (
    tester,
  ) async {
    await _pump(
      tester,
      TargetPlatform.android,
      active: true,
      onChangeModel: () {},
    );

    expect(find.text('Active'), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('checks the active profile and offers the button on macOS', (
    tester,
  ) async {
    await _pump(
      tester,
      TargetPlatform.macOS,
      active: true,
      onChangeModel: () {},
    );

    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.slider_horizontal_3), findsOneWidget);
    expect(find.text('Active'), findsNothing);
  });
}
