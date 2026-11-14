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
    group('subtitle', () {
      Widget withSubtitle(String subtitle, {GroupedActionStatus? status}) =>
          GroupedSection(
            children: [
              GroupedActionRow(
                title: 'Check skills',
                subtitle: subtitle,
                icon: AppIcons.refresh,
                onPressed: () {},
                status: status,
              ),
            ],
          );

      testWidgets('shows under the title, above a status line', (tester) async {
        await tester.pumpWidget(
          _host(
            withSubtitle(
              'Last run 2 days ago',
              status: const GroupedActionStatus(
                phase: GroupedActionPhase.failed,
                text: 'It failed',
              ),
            ),
          ),
        );
        final title = tester.getTopLeft(find.text('Check skills')).dy;
        final sub = tester.getTopLeft(find.text('Last run 2 days ago')).dy;
        final status = tester.getTopLeft(find.text('It failed')).dy;
        expect(title, lessThan(sub));
        expect(sub, lessThan(status));
      });

      testWidgets('is muted and smaller than the title', (tester) async {
        await tester.pumpWidget(_host(withSubtitle('Last run 2 days ago')));
        final t = tester.widget<Text>(find.text('Check skills'));
        final s = tester.widget<Text>(find.text('Last run 2 days ago'));
        expect(s.style!.fontSize, lessThan(t.style!.fontSize!));
        expect(s.style!.color, isNot(t.style!.color));
      });

      testWidgets('wraps at the largest text without overflow', (tester) async {
        const long =
            'Looks at every skill in this profile and lists the ones that '
            'were never used, so you can decide what to keep.';
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _host(withSubtitle(long)),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.text(long)).height,
          greaterThan(tester.getSize(find.text('Check skills')).height * 2),
        );
      });

      testWidgets('is part of the row label', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_host(withSubtitle('Last run 2 days ago')));
        final node = tester.getSemantics(find.byType(InkWell).first);
        expect(node.label, contains('Check skills'));
        expect(node.label, contains('Last run 2 days ago'));
        handle.dispose();
      });

      testWidgets('keeps the hit target', (tester) async {
        await tester.pumpWidget(
          _host(
            GroupedSection(
              children: [
                GroupedActionRow(
                  title: 'Check skills',
                  icon: AppIcons.refresh,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
        final bare = tester.getSize(find.byType(InkWell)).height;
        expect(bare, greaterThanOrEqualTo(44));
        await tester.pumpWidget(_host(withSubtitle('Short')));
        expect(
          tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(bare),
        );
        await tester.pumpWidget(
          _host(withSubtitle('Short'), platform: TargetPlatform.android),
        );
        expect(
          tester.getSize(find.byType(InkWell)).height,
          greaterThanOrEqualTo(48),
        );
      });

      testWidgets('is plain on the Mac: no icon, subtitle shown', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(withSubtitle('Last run'), platform: TargetPlatform.macOS),
        );
        expect(find.byType(AppIcon), findsNothing);
        expect(find.text('Last run'), findsOneWidget);
      });
    });
  });
}
