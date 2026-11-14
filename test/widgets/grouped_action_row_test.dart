import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/busy_bar.dart';
import 'package:hermes_app/src/widgets/grouped_action_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

Widget _host(
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: buildHermesLightTheme(platform: platform),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  group('GroupedActionRow', () {
    Widget row({GroupedActionStatus? status, VoidCallback? onPressed}) =>
        GroupedSection(
          children: [
            GroupedActionRow(
              title: 'Restart gateway',
              icon: AppIcons.refresh,
              onPressed: onPressed ?? () {},
              status: status,
            ),
          ],
        );

    testWidgets('a tap runs the action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(row(onPressed: () => taps++)));
      await tester.tap(find.text('Restart gateway'));
      expect(taps, 1);
    });

    testWidgets('is plain on the Mac: no icon', (tester) async {
      await tester.pumpWidget(_host(row(), platform: TargetPlatform.macOS));
      expect(find.byType(AppIcon), findsNothing);
    });

    testWidgets('has its icon on iOS and Material', (tester) async {
      await tester.pumpWidget(_host(row()));
      expect(find.byType(AppIcon), findsOneWidget);
      await tester.pumpWidget(_host(row(), platform: TargetPlatform.android));
      expect(find.byType(AppIcon), findsOneWidget);
    });

    testWidgets('while working it shows a BusyBar and ignores taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          row(
            onPressed: () => taps++,
            status: const GroupedActionStatus(
              phase: GroupedActionPhase.working,
              text: 'Restarting…',
            ),
          ),
          reduceMotion: true,
        ),
      );
      expect(find.text('Restarting…'), findsOneWidget);
      expect(find.text('Restart gateway'), findsNothing);
      expect(find.byType(BusyBar), findsOneWidget);
      await tester.tap(find.text('Restarting…'), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('an error line has working buttons', (tester) async {
      final pressed = <String>[];
      await tester.pumpWidget(
        _host(
          row(
            status: GroupedActionStatus(
              phase: GroupedActionPhase.failed,
              text: "The gateway didn't restart",
              buttons: [
                GroupedActionButton(
                  label: 'Show logs',
                  onPressed: () => pressed.add('logs'),
                ),
                GroupedActionButton(
                  label: 'Try again',
                  onPressed: () => pressed.add('again'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text("The gateway didn't restart"), findsOneWidget);
      await tester.tap(find.text('Show logs'));
      await tester.tap(find.text('Try again'));
      expect(pressed, ['logs', 'again']);
      expect(find.text('Restart gateway'), findsOneWidget);
    });
  });
}
