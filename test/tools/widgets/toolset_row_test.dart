import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/widgets/toolset_header.dart';
import 'package:hermes_app/src/tools/widgets/toolset_row.dart';
import 'package:hermes_app/src/tools/widgets/tools_list_footer.dart';

import 'pump_tools.dart';

ToolsetRowView _view({
  bool enabled = false,
  bool risk = false,
  ToolsetRowPhase phase = ToolsetRowPhase.idle,
  bool tryAgain = false,
  ToolsetRowError? error,
}) => ToolsetRowView(
  name: 'Terminal',
  sentence: 'Run commands on the machine where Hermes runs.',
  enabled: enabled,
  riskLine: risk,
  needsSetup: true,
  actionCount: 2,
  phase: phase,
  showTryAgain: tryAgain,
  error: error,
);

Widget _row(
  ToolsetRowView view, {
  VoidCallback? onOpen,
  ValueChanged<bool>? onChanged,
  VoidCallback? onTryAgain,
}) => ToolsetRow(
  view: view,
  onOpen: onOpen ?? () {},
  onChanged: onChanged ?? (_) {},
  onTryAgain: onTryAgain,
);

void main() {
  testWidgets('shows the lines of a risky row that needs setup', (t) async {
    await pumpTools(t, _row(_view(risk: true)));
    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('2 actions'), findsOneWidget);
    expect(find.text('Can change things'), findsOneWidget);
    expect(find.text('Needs setup'), findsOneWidget);
  });

  testWidgets('the action count is pluralised and German', (t) async {
    await pumpTools(
      t,
      _row(
        const ToolsetRowView(
          name: 'Memory',
          sentence: 's',
          enabled: true,
          actionCount: 1,
        ),
      ),
      locale: const Locale('de'),
    );
    expect(find.text('1 Aktion'), findsOneWidget);
  });

  testWidgets('a plugin toolset shows no risk line', (t) async {
    await pumpTools(
      t,
      _row(
        const ToolsetRowView(
          name: 'Weather',
          sentence: 'get_forecast',
          enabled: false,
          riskLine: true,
          unknownPlugin: true,
        ),
      ),
    );
    expect(find.text('Can change things'), findsNothing);
  });

  testWidgets('the text opens the details and the switch only switches', (
    t,
  ) async {
    var opened = 0;
    final changes = <bool>[];
    await pumpTools(
      t,
      _row(_view(), onOpen: () => opened++, onChanged: changes.add),
    );
    await t.tap(find.text('Terminal'));
    expect(opened, 1);
    expect(changes, isEmpty);
    await t.tap(find.byType(Switch));
    expect(changes, [true]);
    expect(opened, 1);
  });

  testWidgets('the switch is its own semantics node named "name, on"', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pumpTools(t, _row(_view(enabled: true, risk: true)));
    expect(
      t.getSemantics(find.bySemanticsLabel(RegExp('^Terminal, (on|off)'))),
      isSemantics(
        label: 'Terminal, on',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    // The row's text node reads the risk line and opens the details.
    final text = t.getSemantics(find.text('Terminal'));
    expect(text.label, contains('Can change things'));
    expect(text.label, contains('Run commands'));
    handle.dispose();
  });

  testWidgets('saving says so, is disabled and shows a spinner', (t) async {
    final handle = t.ensureSemantics();
    await pumpTools(
      t,
      _row(_view(enabled: true, phase: ToolsetRowPhase.saving)),
    );
    expect(
      t.getSemantics(find.bySemanticsLabel(RegExp('^Terminal, (on|off)'))),
      isSemantics(
        label: 'Terminal, on, saving',
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a lost answer shows the caption and disables the switch', (
    t,
  ) async {
    await pumpTools(t, _row(_view(phase: ToolsetRowPhase.checking)));
    expect(find.text('May have changed. Checking…'), findsOneWidget);
    expect(find.text('2 actions'), findsNothing);
    expect(t.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testWidgets('not confirmed: pull to refresh, or Try again', (t) async {
    await pumpTools(t, _row(_view(phase: ToolsetRowPhase.unconfirmed)));
    expect(find.text("Couldn't confirm. Pull to refresh."), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    var again = 0;
    await pumpTools(
      t,
      _row(
        _view(phase: ToolsetRowPhase.unconfirmed, tryAgain: true),
        onTryAgain: () => again++,
      ),
    );
    expect(find.text("Couldn't confirm. Try again."), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Try again'));
    expect(again, 1);
  });

  testWidgets('waiting for a confirmation leaves the switch usable', (t) async {
    await pumpTools(
      t,
      _row(_view(phase: ToolsetRowPhase.awaitingConfirmation)),
    );
    expect(t.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('an error is a line with the error glyph', (t) async {
    await pumpTools(
      t,
      _row(
        _view(
          error: const ToolsetRowError(
            ToolsetRowErrorKind.notAllowed,
            "You can't change tools on this server.",
          ),
        ),
      ),
    );
    expect(find.text("You can't change tools on this server."), findsOneWidget);
  });

  testWidgets('the sentence keeps three lines, and all of it at 2x', (t) async {
    const long =
        'one two three four five six seven eight nine ten eleven twelve '
        'thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty '
        'twentyone twentytwo twentythree twentyfour twentyfive twentysix';
    const view = ToolsetRowView(name: 'X', sentence: long, enabled: false);
    await pumpTools(t, _row(view));
    expect(t.widget<Text>(find.text(long)).maxLines, 3);
    await pumpTools(t, _row(view), textScale: 2);
    expect(t.widget<Text>(find.text(long)).maxLines, isNull);
  });

  testWidgets('at the largest text the switch has its own line with On/Off', (
    t,
  ) async {
    await pumpTools(t, _row(_view(enabled: true)), textScale: 2);
    expect(t.takeException(), isNull);
    expect(find.text('On'), findsOneWidget);
    final switchTop = t.getTopLeft(find.byType(Switch)).dy;
    final bottom = t.getBottomLeft(find.text('Needs setup')).dy;
    expect(switchTop, greaterThanOrEqualTo(bottom));
    await pumpTools(t, _row(_view()), textScale: 3, locale: const Locale('de'));
    expect(find.text('Aus'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('at the default size the switch is beside the text', (t) async {
    await pumpTools(t, _row(_view()));
    expect(find.text('Off'), findsNothing);
    final switchTop = t.getTopLeft(find.byType(Switch)).dy;
    expect(switchTop, lessThan(t.getBottomLeft(find.text('Needs setup')).dy));
  });

  group('touch targets', () {
    for (final (platform, min) in [
      (TargetPlatform.iOS, 44.0),
      (TargetPlatform.android, 48.0),
      (TargetPlatform.macOS, 28.0),
    ]) {
      testWidgets('the switch area is at least $min on $platform', (t) async {
        await pumpTools(t, _row(_view()), platform: platform);
        final box = find.ancestor(
          of: find.byType(Switch),
          matching: find.byType(ConstrainedBox),
        );
        final size = t.getSize(box.first);
        expect(size.height, greaterThanOrEqualTo(min));
        expect(size.width, greaterThanOrEqualTo(min));
        expect(
          t.getSize(find.byType(ToolsetRow)).height,
          greaterThanOrEqualTo(min),
        );
      });
    }
  });

  testWidgets('meets the platform tap target guidelines', (t) async {
    final handle = t.ensureSemantics();
    await pumpTools(t, _row(_view(risk: true)));
    await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('meets the Android tap target guideline', (t) async {
    final handle = t.ensureSemantics();
    await pumpTools(t, _row(_view()), platform: TargetPlatform.android);
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a selected row is filled in the border colour', (t) async {
    await pumpTools(
      t,
      _row(
        const ToolsetRowView(
          name: 'A',
          sentence: 's',
          enabled: false,
          selected: true,
        ),
      ),
    );
    final scheme = Theme.of(t.element(find.byType(ToolsetRow))).colorScheme;
    final material = t.widgetList<Material>(
      find.descendant(
        of: find.byType(ToolsetRow),
        matching: find.byType(Material),
      ),
    );
    expect(material.any((m) => m.color == scheme.outline), isTrue);
  });

  group('ToolsetHeader', () {
    Widget header({
      bool enabled = false,
      bool needsSetup = false,
      bool saving = false,
      ValueChanged<bool>? onChanged,
    }) => ToolsetHeader(
      name: 'Web search and scraping',
      sentence: 'Look things up on the web and read pages.',
      enabled: enabled,
      needsSetup: needsSetup,
      saving: saving,
      onChanged: onChanged ?? (_) {},
    );

    testWidgets('state lines', (t) async {
      for (final (on, setup, text) in [
        (true, false, 'On'),
        (false, false, 'Off'),
        (true, true, 'On · needs setup'),
        (false, true, 'Off · needs setup'),
      ]) {
        await pumpTools(t, header(enabled: on, needsSetup: setup));
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('the name is a heading and the switch is named', (t) async {
      final handle = t.ensureSemantics();
      await pumpTools(t, header(enabled: true, saving: true));
      expect(
        t.getSemantics(find.text('Web search and scraping')),
        isSemantics(isHeader: true),
      );
      expect(
        t.getSemantics(find.bySemanticsLabel(RegExp(r'saving$'))).label,
        'Web search and scraping, on, saving',
      );
      expect(t.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      handle.dispose();
    });

    testWidgets('the switch calls back', (t) async {
      final changes = <bool>[];
      await pumpTools(t, header(onChanged: changes.add));
      await t.tap(find.byType(Switch));
      expect(changes, [true]);
    });

    testWidgets('at 2x the switch is under the name', (t) async {
      await pumpTools(t, header(), textScale: 2);
      expect(t.takeException(), isNull);
      expect(
        t.getTopLeft(find.byType(Switch)).dy,
        greaterThanOrEqualTo(
          t.getBottomLeft(find.text('Web search and scraping')).dy,
        ),
      );
      await pumpTools(t, header(), textScale: 1);
      expect(
        t.getTopLeft(find.byType(Switch)).dy,
        lessThan(t.getBottomLeft(find.text('Web search and scraping')).dy),
      );
    });
  });

  testWidgets('the footer link calls back and is a link', (t) async {
    final handle = t.ensureSemantics();
    var taps = 0;
    await pumpTools(t, ToolsListFooter(onWhatsTheDifference: () => taps++));
    expect(
      find.textContaining('Switching a tool on or off applies from your next'),
      findsOneWidget,
    );
    await t.tap(find.text("What's the difference?"));
    expect(taps, 1);
    expect(
      t.getSemantics(find.text("What's the difference?")),
      isSemantics(isLink: true, isButton: true),
    );
    handle.dispose();
  });
}
