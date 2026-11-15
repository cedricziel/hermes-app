import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/busy_bar.dart';
import 'package:hermes_app/src/widgets/grouped_action_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/motion_spinner.dart';

Widget _host(
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  bool reduceMotion = false,
  double scale = 1,
}) => MaterialApp(
  theme: buildHermesLightTheme(platform: platform),
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(scale),
    ),
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
    group('long-running pass states', () {
      Widget plain({
        VoidCallback? onPressed,
        GroupedActionStatus? status,
        bool spinner = false,
        String? semanticLabel,
      }) => GroupedSection(
        children: [
          GroupedActionRow(
            title: 'Run now',
            icon: AppIcons.play,
            onPressed: onPressed,
            status: status,
            spinnerWhileWorking: spinner,
            semanticLabel: semanticLabel,
          ),
        ],
      );

      testWidgets('a null onPressed ignores taps and reads as disabled', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_host(plain()));
        await tester.tap(find.text('Run now'), warnIfMissed: false);
        final context = tester.element(find.text('Run now'));
        expect(
          tester.widget<Text>(find.text('Run now')).style!.color,
          context.hermesColors.subtleText,
        );
        expect(
          tester.getSemantics(find.text('Run now')),
          isSemantics(
            label: 'Run now',
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
        handle.dispose();
      });

      testWidgets('the neutral phase shows its line and working button', (
        tester,
      ) async {
        var checks = 0;
        await tester.pumpWidget(
          _host(
            plain(
              status: GroupedActionStatus(
                phase: GroupedActionPhase.neutral,
                text: 'Still running on the server.',
                buttons: [
                  GroupedActionButton(
                    label: 'Check status',
                    onPressed: () => checks++,
                  ),
                  const GroupedActionButton(label: 'Wait', onPressed: null),
                ],
              ),
            ),
          ),
        );
        expect(find.text('Still running on the server.'), findsOneWidget);
        expect(find.text('Run now'), findsOneWidget);
        await tester.tap(find.text('Check status'));
        expect(checks, 1);
        final disabled = find.ancestor(
          of: find.text('Wait'),
          matching: find.byType(OutlinedButton),
        );
        expect(tester.widget<OutlinedButton>(disabled).onPressed, isNull);
      });

      testWidgets('a spinner leads the working phase, on the Mac too', (
        tester,
      ) async {
        const working = GroupedActionStatus(
          phase: GroupedActionPhase.working,
          text: 'Running on the server…',
        );
        for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
          await tester.pumpWidget(
            _host(
              plain(status: working, spinner: true),
              platform: platform,
              reduceMotion: true,
            ),
          );
          expect(find.byType(MotionSpinner), findsOneWidget);
          expect(find.text('Run now'), findsNothing);
        }
        await tester.pumpWidget(
          _host(
            plain(status: working),
            platform: TargetPlatform.macOS,
            reduceMotion: true,
          ),
        );
        expect(find.byType(MotionSpinner), findsNothing);
      });

      testWidgets('semanticLabel replaces the visible text', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(plain(onPressed: () {}, semanticLabel: 'Run now, running')),
        );
        expect(find.bySemanticsLabel('Run now, running'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('the icon grows with the text size', (tester) async {
        await tester.pumpWidget(_host(plain(onPressed: () {})));
        final normal = tester.getSize(find.byType(AppIcon)).width;
        await tester.pumpWidget(_host(plain(onPressed: () {}), scale: 2));
        expect(tester.getSize(find.byType(AppIcon)).width, greaterThan(normal));
      });

      for (final (platform, min) in [
        (TargetPlatform.iOS, 44.0),
        (TargetPlatform.android, 48.0),
        (TargetPlatform.macOS, 28.0),
      ]) {
        testWidgets('status buttons are at least $min tall on $platform', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              plain(
                onPressed: () {},
                status: GroupedActionStatus(
                  phase: GroupedActionPhase.neutral,
                  text: 'Still running.',
                  buttons: [
                    GroupedActionButton(
                      label: 'Check status',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              platform: platform,
            ),
          );
          final button = find.ancestor(
            of: find.text('Check status'),
            matching: find.byType(OutlinedButton),
          );
          expect(tester.getSize(button).height, greaterThanOrEqualTo(min));
        });
      }
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
