import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/tools/widgets/provider_row.dart';
import 'package:hermes_app/src/tools/widgets/status_chip.dart';
import 'package:hermes_app/src/tools/widgets/tools_load_state.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

import 'pump_tools.dart';

Widget _row({
  bool picked = false,
  ToolsStatus status = ToolsStatus.needsKey,
  String? badge = 'paid',
  String? line = 'Search and extract',
  bool nous = false,
  String? hermes,
  bool fails = false,
  VoidCallback? onPick,
}) => GroupedSection(
  children: [
    ProviderRow(
      name: 'Brightfetch',
      status: status,
      badge: badge,
      line: line,
      needsNousSignIn: nous,
      hermesText: hermes,
      commandsWillFail: fails,
      picked: picked,
      onPick: onPick ?? () {},
    ),
  ],
);

void main() {
  testWidgets('shows name, badge, line and the status chip in that order', (
    t,
  ) async {
    await pumpTools(t, _row());
    expect(find.textContaining('Brightfetch'), findsOneWidget);
    expect(find.text('paid'), findsOneWidget);
    expect(find.text('Search and extract'), findsOneWidget);
    expect(find.text('Needs a key'), findsOneWidget);
    final name = t.getTopLeft(find.textContaining('Brightfetch')).dy;
    final line = t.getTopLeft(find.text('Search and extract')).dy;
    final chip = t.getTopLeft(find.byType(StatusChip)).dy;
    expect(name, lessThan(line));
    expect(line, lessThan(chip));
  });

  testWidgets('the badge is an outlined tag, not a filled one', (t) async {
    await pumpTools(t, _row());
    final box = t.widget<Container>(
      find
          .ancestor(of: find.text('paid'), matching: find.byType(Container))
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, isNull);
    expect(decoration.border, isNotNull);
  });

  testWidgets('a row without a badge or line shows neither', (t) async {
    await pumpTools(t, _row(badge: null, line: null));
    expect(find.text('paid'), findsNothing);
    expect(find.text('Search and extract'), findsNothing);
  });

  testWidgets('the notes follow the chip', (t) async {
    await pumpTools(
      t,
      _row(
        status: ToolsStatus.needsSignIn,
        nous: true,
        hermes: 'Docker is not running.',
        fails: true,
        picked: true,
      ),
    );
    final chip = t.getTopLeft(find.byType(StatusChip)).dy;
    for (final text in [
      "This needs a sign-in to Nous Portal on your server. The app can't do that for you.",
      'From Hermes: Docker is not running.',
      'Commands will fail until this is set up on your server.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
      expect(t.getTopLeft(find.text(text)).dy, greaterThan(chip));
    }
  });

  testWidgets('German notes', (t) async {
    await pumpTools(
      t,
      _row(nous: true, hermes: 'x'),
      locale: const Locale('de'),
    );
    expect(
      find.textContaining('Nous Portal auf deinem Server'),
      findsOneWidget,
    );
    expect(find.text('Von Hermes: x'), findsOneWidget);
  });

  testWidgets('Apple: a check mark in the link colour only when picked', (
    t,
  ) async {
    await pumpTools(t, _row());
    expect(find.byType(Radio<bool>), findsNothing);
    expect(find.byIcon(AppIcons.check.apple), findsNothing);
    await pumpTools(t, _row(picked: true));
    final icon = t.widget<Icon>(find.byIcon(AppIcons.check.apple));
    final colors = t.element(find.byType(ProviderRow)).hermesColors;
    expect(icon.color, colors.link);
    // The mark is at the trailing edge.
    expect(
      t.getTopRight(find.byIcon(AppIcons.check.apple)).dx,
      greaterThan(t.getTopRight(find.text('Search and extract')).dx - 1),
    );
  });

  testWidgets('Material: a leading radio button that follows the pick', (
    t,
  ) async {
    await pumpTools(t, _row(), platform: TargetPlatform.android);
    expect(find.byIcon(AppIcons.check.material), findsNothing);
    final radio = find.byType(Radio<bool>);
    expect(radio, findsOneWidget);
    expect(
      t.getTopLeft(radio).dx,
      lessThan(t.getTopLeft(find.text('paid')).dx),
    );
    await pumpTools(t, _row(picked: true), platform: TargetPlatform.android);
    final group = RadioGroup.maybeOf<bool>(t.element(find.byType(Radio<bool>)));
    expect(group?.groupValue, isTrue);
  });

  testWidgets('a tap on the row picks it', (t) async {
    var picks = 0;
    await pumpTools(t, _row(onPick: () => picks++));
    await t.tap(find.text('Search and extract'));
    expect(picks, 1);
  });

  testWidgets('a tap on the Material radio picks it', (t) async {
    var picks = 0;
    await pumpTools(
      t,
      _row(onPick: () => picks++),
      platform: TargetPlatform.android,
    );
    await t.tap(find.byType(Radio<bool>));
    expect(picks, 1);
  });

  testWidgets('one radio node that says what it is and whether it is picked', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pumpTools(t, _row(picked: true, nous: true));
    final node = t.getSemantics(find.textContaining('Brightfetch'));
    expect(node.label, contains('Brightfetch'));
    expect(node.label, contains('paid'));
    expect(node.label, contains('Needs a key'));
    expect(node.label, contains('Nous Portal'));
    expect(
      node,
      isSemantics(
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('Material: one radio node, checked, in a group', (t) async {
    final handle = t.ensureSemantics();
    await pumpTools(
      t,
      _row(picked: true, nous: true),
      platform: TargetPlatform.android,
    );
    final node = t.getSemantics(find.textContaining('Brightfetch'));
    expect(node.label, contains('Needs a key'));
    expect(node.label, contains('Nous Portal'));
    expect(
      node,
      isSemantics(
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a row that cannot be picked has a disabled radio', (t) async {
    await pumpTools(
      t,
      GroupedSection(
        children: [
          ProviderRow(
            name: 'Brightfetch',
            status: ToolsStatus.ready,
            picked: false,
            onPick: null,
          ),
        ],
      ),
      platform: TargetPlatform.android,
    );
    expect(t.widget<Radio<bool>>(find.byType(Radio<bool>)).enabled, isFalse);
  });

  for (final scale in [2.0, 3.0]) {
    testWidgets('wraps without overflow at ${scale}x', (t) async {
      await pumpTools(
        t,
        _row(
          status: ToolsStatus.needsSignIn,
          nous: true,
          fails: true,
          picked: true,
          line: 'A tag line that is also long enough to wrap',
        ),
        textScale: scale,
        locale: const Locale('de'),
      );
      expect(t.takeException(), isNull);
    });
  }

  group('load states', () {
    testWidgets('loading is a live region', (t) async {
      final handle = t.ensureSemantics();
      await pumpTools(t, const ToolsLoadingRow('Loading setup…'));
      expect(find.text('Loading setup…'), findsOneWidget);
      expect(
        t.getSemantics(find.bySemanticsLabel('Loading setup…')),
        isSemantics(label: 'Loading setup…', isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('loading with reduced motion shows no spinner', (t) async {
      await pumpTools(
        t,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const ToolsLoadingRow('Loading setup…'),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
    });

    testWidgets('failure says so and offers Try again at 44 pt', (t) async {
      var retries = 0;
      await pumpTools(
        t,
        ToolsFailureRow(text: "Couldn't load setup.", onRetry: () => retries++),
      );
      expect(find.text("Couldn't load setup."), findsOneWidget);
      expect(
        t.getSize(find.widgetWithText(TextButton, 'Try again')).height,
        greaterThanOrEqualTo(44),
      );
      await t.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('nothing to set up', (t) async {
      await pumpTools(t, const ToolsNothingRow('Nothing to set up.'));
      expect(find.text('Nothing to set up.'), findsOneWidget);
    });
  });
}
