import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/tools/tools_models.dart';
import 'package:hermes_app/src/tools/widgets/readiness_row.dart';

import 'pump_tools.dart';

const _macMissing = ComputerUseStatus(
  platform: 'darwin',
  platformSupported: true,
  installed: true,
  ready: false,
  canGrant: true,
  accessibility: true,
  screenRecording: false,
  checks: [ComputerUseCheck(label: 'Driver binary', message: '2.4.1')],
);

const _macNoDriver = ComputerUseStatus(
  platform: 'darwin',
  platformSupported: true,
  installed: false,
  canGrant: true,
);

const _linux = ComputerUseStatus(
  platform: 'linux',
  platformSupported: true,
  installed: true,
  ready: true,
);

Widget _section(
  ComputerUseStatus status, {
  bool screen = false,
  bool open = false,
  VoidCallback? install,
  VoidCallback? grant,
  VoidCallback? openScreen,
}) => Builder(
  builder: (context) => ReadinessSection(
    items: readinessItems(context.l10n, status),
    details: [
      for (final c in status.checks)
        ReadinessDetail(label: c.label, text: c.message),
    ],
    errorText: status.error,
    detailsInitiallyOpen: open,
    onOpenBotScreen: screen ? (openScreen ?? () {}) : null,
    onInstall: install,
    onAllowAccess: grant,
  ),
);

Finder get _filled => find.byType(FilledButton);

void main() {
  test(
    'the rows follow the server: a Mac has permission rows, Linux has not',
    () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        [for (final i in readinessItems(en, _macMissing)) i.label],
        [
          'Server system',
          'Driver',
          'Accessibility',
          'Screen recording',
          'Ready',
        ],
      );
      expect(
        [for (final i in readinessItems(en, _linux)) i.label],
        ['Driver', 'Ready'],
      );
      final values = {
        for (final i in readinessItems(en, _macMissing)) i.label: i.value,
      };
      expect(values['Server system'], 'macOS, supported');
      expect(values['Driver'], 'Installed');
      expect(values['Accessibility'], 'Allowed');
      expect(values['Screen recording'], 'Not allowed');
      expect(values['Ready'], 'No');
    },
  );

  test('a server that is not supported shows its system, whatever it is', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final rows = readinessItems(
      en,
      const ComputerUseStatus(platform: 'win32', platformSupported: false),
    );
    expect(rows.first.label, 'Server system');
    expect(rows.first.value, 'Windows, not supported');
    expect(rows.first.tone, ReadinessTone.bad);
    final odd = readinessItems(
      en,
      const ComputerUseStatus(platform: 'freebsd', platformSupported: false),
    );
    expect(odd.first.value, 'freebsd, not supported');
    // A supported Linux server still shows only Driver and Ready.
    expect(
      [for (final i in readinessItems(en, _linux)) i.label],
      ['Driver', 'Ready'],
    );
    // Nothing to name: no row.
    expect(
      [
        for (final i in readinessItems(
          en,
          const ComputerUseStatus(platformSupported: false),
        ))
          i.label,
      ],
      ['Driver', 'Ready'],
    );
  });

  test('tones: check, cross, question mark', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final rows = {
      for (final i in readinessItems(
        en,
        const ComputerUseStatus(platform: 'linux', installed: false),
      ))
        i.label: i,
    };
    expect(rows['Driver']!.tone, ReadinessTone.bad);
    expect(rows['Driver']!.value, 'Not installed');
    expect(rows['Ready']!.tone, ReadinessTone.unknown);
    expect(rows['Ready']!.value, "Couldn't tell");
  });

  testWidgets(
    'Mac server, screen recording missing: Allow access, no Install',
    (t) async {
      var grants = 0;
      await pumpTools(t, _section(_macMissing, grant: () => grants++));
      expect(find.text('Readiness'.toUpperCase()), findsOneWidget);
      expect(find.text('macOS, supported'), findsOneWidget);
      expect(find.text('Not allowed'), findsOneWidget);
      expect(find.text('Install on server'), findsNothing);
      expect(_filled, findsOneWidget);
      expect(
        find.text(
          'A permission window opens on the Mac that runs Hermes. Someone there has to approve it.',
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Allow access'));
      expect(grants, 1);
      expect(find.byIcon(AppIcons.lockOpen.apple), findsOneWidget);
    },
  );

  testWidgets(
    'Mac server without the driver: Install on server, no Allow access',
    (t) async {
      await pumpTools(t, _section(_macNoDriver, install: () {}));
      expect(find.text('Not installed'), findsOneWidget);
      expect(find.text('Install on server'), findsOneWidget);
      expect(find.text('Allow access'), findsNothing);
      expect(_filled, findsOneWidget);
    },
  );

  testWidgets('Linux: Driver and Ready only', (t) async {
    await pumpTools(t, _section(_linux));
    expect(find.text('Server system'), findsNothing);
    expect(find.text('Accessibility'), findsNothing);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(_filled, findsNothing);
  });

  testWidgets('unknown readiness shows Couldn\'t tell and Hermes\' error', (
    t,
  ) async {
    await pumpTools(
      t,
      _section(
        const ComputerUseStatus(
          platform: 'linux',
          installed: true,
          error: 'The driver did not answer.',
        ),
      ),
    );
    expect(find.text("Couldn't tell"), findsOneWidget);
    expect(find.text('The driver did not answer.'), findsOneWidget);
  });

  testWidgets('status is never colour alone: each tone has its own icon', (
    t,
  ) async {
    await pumpTools(
      t,
      const Column(
        children: [
          ReadinessRow(
            item: ReadinessItem(label: 'a', value: 'x', tone: ReadinessTone.ok),
          ),
          ReadinessRow(
            item: ReadinessItem(
              label: 'b',
              value: 'y',
              tone: ReadinessTone.bad,
            ),
          ),
          ReadinessRow(
            item: ReadinessItem(
              label: 'c',
              value: 'z',
              tone: ReadinessTone.unknown,
            ),
          ),
        ],
      ),
    );
    expect(find.byIcon(AppIcons.checkCircleFilled.apple), findsOneWidget);
    expect(find.byIcon(AppIcons.crossCircleFilled.apple), findsOneWidget);
    expect(find.byIcon(AppIcons.questionCircleFilled.apple), findsOneWidget);
    expect(t.widget<Text>(find.text('y')).style?.fontWeight, FontWeight.w600);
    expect(t.widget<Text>(find.text('x')).style?.fontWeight, FontWeight.w400);
  });

  testWidgets('a row reads "label, value" as one element', (t) async {
    final handle = t.ensureSemantics();
    await pumpTools(
      t,
      const ReadinessRow(
        item: ReadinessItem(
          label: 'Driver',
          value: 'Not installed',
          tone: ReadinessTone.bad,
        ),
      ),
    );
    expect(find.bySemanticsLabel('Driver, Not installed'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'the bot\'s screen row is a button with a chevron, only when offered',
    (t) async {
      var opens = 0;
      await pumpTools(
        t,
        _section(_linux, screen: true, openScreen: () => opens++),
      );
      expect(find.text("Open the bot's screen"), findsOneWidget);
      expect(find.byKey(const Key('grouped-row-chevron')), findsOneWidget);
      await t.tap(find.text("Open the bot's screen"));
      expect(opens, 1);
      await pumpTools(t, _section(_linux));
      expect(find.text("Open the bot's screen"), findsNothing);
    },
  );

  testWidgets('Details is the last row and opens the checks', (t) async {
    await pumpTools(t, _section(_macMissing, screen: true));
    final details = t.getTopLeft(find.text('Details')).dy;
    expect(
      details,
      greaterThan(t.getTopLeft(find.text("Open the bot's screen")).dy),
    );
    expect(details, greaterThan(t.getTopLeft(find.text('Ready')).dy));
    expect(find.text('Driver binary'), findsNothing);
    await t.tap(find.text('Details'));
    await t.pumpAndSettle();
    expect(find.text('Driver binary'), findsOneWidget);
    expect(find.text('2.4.1'), findsOneWidget);
    await pumpTools(t, _section(_linux));
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('German', (t) async {
    await pumpTools(
      t,
      _section(_macMissing, grant: () {}),
      locale: const Locale('de'),
    );
    expect(find.text('macOS, unterstützt'), findsOneWidget);
    expect(find.text('Nicht erlaubt'), findsOneWidget);
    expect(find.text('Zugriff erlauben'), findsOneWidget);
  });

  testWidgets('at 3x the value goes under the label without overflow', (
    t,
  ) async {
    await pumpTools(
      t,
      _section(_macMissing, grant: () {}, screen: true),
      textScale: 3,
      locale: const Locale('de'),
    );
    expect(t.takeException(), isNull);
    expect(
      t.getTopLeft(find.text('Nicht erlaubt')).dy,
      greaterThan(t.getTopLeft(find.text('Bildschirmaufnahme')).dy),
    );
  });

  for (final (platform, min) in [
    (TargetPlatform.iOS, 44.0),
    (TargetPlatform.android, 48.0),
    (TargetPlatform.macOS, 28.0),
  ]) {
    testWidgets('Allow access is at least $min on $platform', (t) async {
      await pumpTools(
        t,
        _section(_macMissing, grant: () {}),
        platform: platform,
      );
      expect(t.getSize(_filled).height, greaterThanOrEqualTo(min));
    });
  }
}
