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
  themeAnimationDuration: Duration.zero,
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

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('has its icon on $platform', (tester) async {
        await tester.pumpWidget(_host(row(), platform: platform));
        expect(find.byType(AppIcon), findsOneWidget);
      });
    }

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
        String? subtitle,
        bool touchTargetButtons = false,
      }) => GroupedSection(
        children: [
          GroupedActionRow(
            title: 'Run now',
            subtitle: subtitle,
            touchTargetButtons: touchTargetButtons,
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
        await tester.pumpWidget(
          _host(plain(subtitle: 'A pass is running on this server')),
        );
        await tester.tap(find.text('Run now'), warnIfMissed: false);
        final context = tester.element(find.text('Run now'));
        expect(
          tester.widget<Text>(find.text('Run now')).style!.color,
          context.hermesColors.subtleText,
        );
        expect(
          tester.getSemantics(find.byType(InkWell).first),
          isSemantics(
            label: 'Run now\nA pass is running on this server',
            hasEnabledState: true,
            isEnabled: false,
          ),
        );
        handle.dispose();
      });

      testWidgets('a disabled row fades its icon as a second cue', (
        tester,
      ) async {
        await tester.pumpWidget(_host(plain(onPressed: () {})));
        final enabled = tester.widget<AppIcon>(find.byType(AppIcon)).color!;
        await tester.pumpWidget(_host(plain(subtitle: 'Not now')));
        final disabled = tester.widget<AppIcon>(find.byType(AppIcon)).color!;
        expect(disabled.a, lessThan(enabled.a));
      });

      test('a disabled row without a reason is refused', () {
        expect(
          () => GroupedActionRow(
            title: 'Run now',
            icon: AppIcons.play,
            onPressed: null,
          ),
          throwsAssertionError,
        );
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

      const working = GroupedActionStatus(
        phase: GroupedActionPhase.working,
        text: 'Running on the server…',
      );
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.macOS,
      ]) {
        testWidgets('a spinner leads the working phase on $platform', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              plain(status: working, spinner: true),
              platform: platform,
              reduceMotion: true,
            ),
          );
          expect(find.byType(MotionSpinner), findsOneWidget);
          expect(find.text('Run now'), findsNothing);
        });

        testWidgets('without the flag $platform shows no spinner', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              plain(status: working),
              platform: platform,
              reduceMotion: true,
            ),
          );
          expect(find.byType(MotionSpinner), findsNothing);
        });

        testWidgets('the spinner flag shows nothing while idle on $platform', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              plain(onPressed: () {}, spinner: true),
              platform: platform,
              reduceMotion: true,
            ),
          );
          expect(find.byType(MotionSpinner), findsNothing);
          expect(
            find.byType(AppIcon),
            platform == TargetPlatform.macOS ? findsNothing : findsOneWidget,
          );
        });
      }

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

      testWidgets('the status line icon grows with the text size', (
        tester,
      ) async {
        const neutral = GroupedActionStatus(
          phase: GroupedActionPhase.neutral,
          text: 'Still running.',
        );
        await tester.pumpWidget(
          _host(
            plain(onPressed: () {}, status: neutral),
            platform: TargetPlatform.macOS,
          ),
        );
        final normal = tester.getSize(find.byType(AppIcon)).width;
        await tester.pumpWidget(
          _host(
            plain(onPressed: () {}, status: neutral),
            platform: TargetPlatform.macOS,
            scale: 1.5,
          ),
        );
        expect(tester.getSize(find.byType(AppIcon)).width, greaterThan(normal));
      });

      group('stacked at large text', () {
        Future<void> pump(WidgetTester tester, double scale) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _host(
              plain(
                onPressed: () {},
                subtitle: 'Leaving this screen does not stop it.',
              ),
              scale: scale,
            ),
          );
        }

        testWidgets('the icon leads on the left up to twice the size', (
          tester,
        ) async {
          await pump(tester, 2);
          final icon = tester.getRect(find.byType(AppIcon));
          final text = tester.getRect(find.text('Run now'));
          expect(icon.right, lessThanOrEqualTo(text.left));
          expect(text.left - icon.right, greaterThan(0));
        });

        testWidgets('beyond that the icon sits above the text', (tester) async {
          await pump(tester, 3.1);
          final icon = tester.getRect(find.byType(AppIcon));
          final text = tester.getRect(find.text('Run now'));
          expect(icon.bottom, lessThanOrEqualTo(text.top));
          expect(icon.left, text.left);
          final sub = tester.getRect(
            find.text('Leaving this screen does not stop it.'),
          );
          expect(sub.left, text.left);
          expect(tester.takeException(), isNull);
        });

        testWidgets('the status line starts at the row edge when stacked', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _host(
              plain(
                onPressed: () {},
                status: const GroupedActionStatus(
                  phase: GroupedActionPhase.neutral,
                  text: 'Still running.',
                ),
              ),
              scale: 3.1,
            ),
          );
          final title = tester.getRect(find.text('Run now')).left;
          final line = tester.getRect(find.text('Still running.')).left;
          final lineIcon = tester.getRect(find.byType(AppIcon).last).left;
          expect(lineIcon, title);
          expect(line, greaterThan(lineIcon));
        });
      });

      for (final (platform, min) in [
        (TargetPlatform.iOS, 44.0),
        (TargetPlatform.android, 48.0),
        (TargetPlatform.macOS, 28.0),
      ]) {
        Future<double> buttonHeight(
          WidgetTester tester,
          TargetPlatform platform, {
          required bool touchTargets,
        }) async {
          await tester.pumpWidget(
            _host(
              plain(
                onPressed: () {},
                touchTargetButtons: touchTargets,
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
          return tester
              .getSize(
                find
                    .descendant(of: button, matching: find.byType(Material))
                    .first,
              )
              .height;
        }

        testWidgets('touchTargetButtons are $min tall on $platform', (
          tester,
        ) async {
          expect(await buttonHeight(tester, platform, touchTargets: true), min);
        });

        testWidgets('the default buttons keep Server care\'s compact look '
            'on $platform', (tester) async {
          final height = await buttonHeight(
            tester,
            platform,
            touchTargets: false,
          );
          expect(height, 36, reason: 'compact density, as Server care drew it');
          final button = tester.widget<OutlinedButton>(
            find.byType(OutlinedButton),
          );
          expect(button.style!.visualDensity, VisualDensity.compact);
          expect(button.style!.minimumSize!.resolve({}), const Size(0, 44));
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
