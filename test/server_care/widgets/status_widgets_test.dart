import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/widgets/grouped_action_row.dart';
import 'package:hermes_app/src/server_care/widgets/server_attention_dot.dart';
import 'package:hermes_app/src/server_care/widgets/server_restart_banner.dart';
import 'package:hermes_app/src/server_care/widgets/server_status_card.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/busy_bar.dart';
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
  group('ServerStatusCard', () {
    testWidgets('its button fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          ServerStatusCard(
            tone: ServerStatusTone.error,
            title: 'The messaging gateway stopped with an error',
            button: ServerStatusButton(
              label: 'Restart gateway',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.text('Restart gateway'));
      expect(taps, 1);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('Show logs is outlined and healthy has no button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ServerStatusCard(
            tone: ServerStatusTone.warning,
            title: '1 of 2 messaging channels are offline',
            button: ServerStatusButton(
              label: 'Show logs',
              onPressed: () {},
              outlined: true,
            ),
          ),
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      await tester.pumpWidget(
        _host(
          const ServerStatusCard(
            tone: ServerStatusTone.healthy,
            title: 'Everything looks good',
          ),
        ),
      );
      expect(find.byType(ButtonStyleButton), findsNothing);
    });

    testWidgets('reads the sentence and second line as one node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const ServerStatusCard(
            tone: ServerStatusTone.warning,
            title: "Can't reach Hermes",
            detail: 'Check the server.',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text("Can't reach Hermes")).label,
        "Can't reach Hermes\nCheck the server.",
      );
      handle.dispose();
    });
  });

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

  group('ServerAttentionDot', () {
    testWidgets('is a 14 pt circle (10 pt dot, 2 pt ring) with no semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const Center(child: ServerAttentionDot())));
      expect(
        tester.getSize(find.byType(ServerAttentionDot)),
        const Size(14, 14),
      );
      expect(
        find.descendant(
          of: find.byType(ServerAttentionDot),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the menu label says it in words', (tester) async {
      await tester.pumpWidget(
        _host(const ServerMenuItemLabel(needsAttention: true)),
      );
      expect(find.text('Server · needs attention'), findsOneWidget);
      expect(find.byType(ServerAttentionDot), findsOneWidget);
      await tester.pumpWidget(
        _host(const ServerMenuItemLabel(needsAttention: false)),
      );
      expect(find.text('Server'), findsOneWidget);
      expect(find.byType(ServerAttentionDot), findsNothing);
    });
  });

  group('ServerRestartBanner', () {
    testWidgets('restarting: a tap opens the update page', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(ServerRestartBanner.restarting(onTap: () => taps++)),
      );
      expect(
        find.text(
          "Hermes is restarting after the update. Chats continue when it's "
          'back.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(ServerRestartBanner)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byType(InkWell));
      expect(taps, 1);
    });

    testWidgets('ready: the close button is 44 pt and works', (tester) async {
      var closed = 0;
      await tester.pumpWidget(
        _host(
          ServerRestartBanner.ready(version: '0.23.0', onClose: () => closed++),
        ),
      );
      expect(find.text('Hermes 0.23.0 is ready'), findsOneWidget);
      final size = tester.getSize(find.byType(IconButton));
      expect(size.shortestSide, greaterThanOrEqualTo(44));
      await tester.tap(find.byType(IconButton));
      expect(closed, 1);
    });

    testWidgets('ready: dismisses itself after 6 s', (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        _host(
          ServerRestartBanner.ready(
            version: '0.23.0',
            onClose: () {},
            onAutoDismiss: () => dismissed++,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(dismissed, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(dismissed, 1);
    });

    testWidgets('ready: a new dismiss callback replaces the old timer', (
      tester,
    ) async {
      var first = 0, second = 0;
      Widget banner(VoidCallback dismiss) => _host(
        ServerRestartBanner.ready(
          version: '0.23.0',
          onClose: () {},
          onAutoDismiss: dismiss,
        ),
      );
      await tester.pumpWidget(banner(() => first++));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(banner(() => second++));
      await tester.pump(const Duration(seconds: 7));
      expect(first, 0);
      expect(second, 1);
    });

    testWidgets('ready: stays until closed under reduced motion', (
      tester,
    ) async {
      var dismissed = 0;
      await tester.pumpWidget(
        _host(
          ServerRestartBanner.ready(
            version: '0.23.0',
            onClose: () {},
            onAutoDismiss: () => dismissed++,
          ),
          reduceMotion: true,
        ),
      );
      await tester.pump(const Duration(seconds: 30));
      expect(dismissed, 0);
    });

    testWidgets('is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(ServerRestartBanner.ready(version: '0.23.0', onClose: () {})),
      );
      expect(
        tester.semantics.find(find.text('Hermes 0.23.0 is ready')),
        matchesSemantics(label: 'Hermes 0.23.0 is ready', isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
