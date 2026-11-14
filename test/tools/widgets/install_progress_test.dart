import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/widgets/install_progress.dart';

import 'pump_tools.dart';

const _lines = [
  'line 1',
  'line 2',
  'line 3',
  'line 4',
  'line 5',
  'line 6',
  'line 7',
  'line 8',
];

Widget _progress(
  InstallPhase phase, {
  List<String> lines = _lines,
  VoidCallback? onTryAgain,
}) => InstallProgress(phase: phase, lines: lines, onTryAgain: onTryAgain);

Finder get _filled => find.byType(FilledButton);

void main() {
  group('InstallProgress', () {
    testWidgets('running: title, the leave line and the last six lines', (
      t,
    ) async {
      await pumpTools(t, _progress(InstallPhase.running));
      expect(find.text('Installing on your server…'), findsOneWidget);
      expect(
        find.text('You can leave this screen. The install keeps going.'),
        findsOneWidget,
      );
      expect(find.text('line 1'), findsNothing);
      expect(find.text('line 2'), findsNothing);
      for (var i = 3; i <= 8; i++) {
        expect(find.text('line $i'), findsOneWidget);
      }
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('each line is its own selectable monospace text', (t) async {
      await pumpTools(t, _progress(InstallPhase.running));
      final lines = t.widgetList<SelectableText>(find.byType(SelectableText));
      expect(lines, hasLength(6));
      for (final line in lines) {
        expect(line.style?.fontFamily, 'monospace');
      }
    });

    testWidgets('running is one live region', (t) async {
      final handle = t.ensureSemantics();
      await pumpTools(t, _progress(InstallPhase.running));
      final node = t.getSemantics(find.text('Installing on your server…'));
      expect(node, isSemantics(isLiveRegion: true));
      expect(node.label, contains('Installing on your server…'));
      // The lines stay separate nodes, each one readable and selectable.
      expect(t.getSemantics(find.text('line 8')).value, 'line 8');
      handle.dispose();
    });

    testWidgets('started by a switch names the driver', (t) async {
      await pumpTools(
        t,
        _progress(InstallPhase.startedBySwitch, lines: const []),
      );
      expect(
        find.text('Hermes is installing the driver on your server.'),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('reduced motion: no spinner animation', (t) async {
      await pumpTools(
        t,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _progress(InstallPhase.running),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Installing on your server…'), findsOneWidget);
    });

    testWidgets('done and unknown are live regions', (t) async {
      final handle = t.ensureSemantics();
      await pumpTools(t, _progress(InstallPhase.done));
      expect(find.text('Installed.'), findsOneWidget);
      expect(
        t.getSemantics(find.bySemanticsLabel('Installed.')),
        isSemantics(label: 'Installed.', isLiveRegion: true),
      );
      await pumpTools(t, _progress(InstallPhase.unknown));
      expect(find.text("Couldn't tell whether it finished."), findsOneWidget);
      expect(_filled, findsNothing);
      handle.dispose();
    });

    testWidgets('failed: lines, the nothing-changed sentence, Try again', (
      t,
    ) async {
      var again = 0;
      await pumpTools(
        t,
        _progress(InstallPhase.failed, onTryAgain: () => again++),
      );
      expect(find.text("The install didn't finish."), findsOneWidget);
      final intro = find.text(
        'Nothing changed on your server. The last lines from the installer:',
      );
      expect(intro, findsOneWidget);
      expect(
        t.getTopLeft(intro).dy,
        lessThan(t.getTopLeft(find.text('line 3')).dy),
      );
      expect(_filled, findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'Try again'));
      expect(again, 1);
      expect(
        t.getSize(find.widgetWithText(FilledButton, 'Try again')).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('German', (t) async {
      await pumpTools(
        t,
        _progress(InstallPhase.failed),
        locale: const Locale('de'),
      );
      expect(
        find.text('Die Installation wurde nicht abgeschlossen.'),
        findsOneWidget,
      );
    });

    testWidgets('wraps at 3x without overflow', (t) async {
      for (final phase in InstallPhase.values) {
        await pumpTools(t, _progress(phase), textScale: 3);
        expect(t.takeException(), isNull, reason: '$phase');
      }
    });
  });

  group('ToolsInstallButton', () {
    testWidgets('filled with a download icon and the helper when needed', (
      t,
    ) async {
      var presses = 0;
      await pumpTools(
        t,
        ToolsInstallButton(needsSetup: true, onPressed: () => presses++),
      );
      expect(_filled, findsOneWidget);
      expect(find.text('Install on server'), findsOneWidget);
      expect(
        find.text('Needed before this works. The app asks first.'),
        findsOneWidget,
      );
      await t.tap(find.text('Install on server'));
      expect(presses, 1);
    });

    testWidgets('quiet "Run the install step again" when not needed', (
      t,
    ) async {
      await pumpTools(
        t,
        ToolsInstallButton(needsSetup: false, onPressed: () {}),
      );
      expect(_filled, findsNothing);
      expect(
        find.widgetWithText(TextButton, 'Run the install step again'),
        findsOneWidget,
      );
      expect(find.textContaining('Needed before'), findsNothing);
    });

    testWidgets('another install running disables it and says so', (t) async {
      var presses = 0;
      for (final needs in [true, false]) {
        await pumpTools(
          t,
          ToolsInstallButton(
            needsSetup: needs,
            anotherRunning: true,
            onPressed: () => presses++,
          ),
        );
        expect(find.text('Another install is running'), findsOneWidget);
        await t.tap(
          find.text('Another install is running'),
          warnIfMissed: false,
        );
      }
      expect(presses, 0);
    });

    for (final (platform, min) in [
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.android, 48.0),
      (TargetPlatform.macOS, 28.0),
    ]) {
      testWidgets('is at least $min on $platform', (t) async {
        for (final needs in [true, false]) {
          await pumpTools(
            t,
            ToolsInstallButton(needsSetup: needs, onPressed: () {}),
            platform: platform,
          );
          expect(
            t.getSize(find.byType(needs ? FilledButton : TextButton)).height,
            greaterThanOrEqualTo(min),
          );
        }
      });
    }
  });
}
