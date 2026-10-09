import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_choice_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

class _Choice extends StatefulWidget {
  const _Choice({this.picked = 'light'});

  final String picked;

  @override
  State<_Choice> createState() => _ChoiceState();
}

class _ChoiceState extends State<_Choice> {
  late String _picked = widget.picked;

  @override
  Widget build(BuildContext context) => RadioGroup<String>(
    groupValue: _picked,
    onChanged: (value) => setState(() => _picked = value!),
    child: GroupedSection(
      dividerIndent: GroupedChoiceRow.dividerIndent(context),
      children: const [
        GroupedChoiceRow(key: Key('light'), value: 'light', title: 'Light'),
        GroupedChoiceRow(key: Key('dark'), value: 'dark', title: 'Dark'),
        GroupedChoiceRow(
          key: Key('auto'),
          value: 'auto',
          title: 'Automatic',
          enabled: false,
        ),
      ],
    ),
  );
}

Widget _app(TargetPlatform platform, {String picked = 'light'}) => MaterialApp(
  theme: buildHermesLightTheme(platform: platform),
  home: Scaffold(
    body: GroupedListView(children: [_Choice(picked: picked)]),
  ),
);

String? _groupValue(WidgetTester tester) =>
    RadioGroup.maybeOf<String>(tester.element(find.byType(Radio<String>).first))
        ?.groupValue;

void main() {
  testWidgets('tapping a row picks its value', (tester) async {
    await tester.pumpWidget(_app(TargetPlatform.android));

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(_groupValue(tester), 'dark');
  });

  testWidgets('a disabled row cannot be picked', (tester) async {
    await tester.pumpWidget(_app(TargetPlatform.iOS));

    await tester.tap(find.text('Automatic'));
    await tester.pump();

    expect(_groupValue(tester), 'light');
  });

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    testWidgets('on $platform a row is one node with its checked state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(platform));

      expect(
        tester.getSemantics(find.text('Light')),
        isSemantics(
          label: 'Light',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Dark')),
        isSemantics(
          label: 'Dark',
          hasCheckedState: true,
          isChecked: false,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Automatic')),
        isSemantics(
          label: 'Automatic',
          hasCheckedState: true,
          isChecked: false,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      semantics.dispose();
    });
  }

  testWidgets('Material leads with the radio, past which separators start', (
    tester,
  ) async {
    await tester.pumpWidget(_app(TargetPlatform.android));

    final radio = tester.getCenter(
      find.descendant(
        of: find.byKey(const Key('dark')),
        matching: find.byType(Radio<String>),
      ),
    );
    expect(radio.dx, lessThan(tester.getTopLeft(find.text('Dark')).dx));
    final divider = tester.widget<Divider>(find.byType(Divider).first);
    expect(divider.indent, greaterThan(GroupedMetrics.material.rowPadding));
  });

  testWidgets('Apple platforms trail with the check', (tester) async {
    await tester.pumpWidget(_app(TargetPlatform.macOS));

    final radio = tester.getCenter(
      find.descendant(
        of: find.byKey(const Key('dark')),
        matching: find.byType(Radio<String>),
      ),
    );
    expect(radio.dx, greaterThan(tester.getTopRight(find.text('Dark')).dx));
    final divider = tester.widget<Divider>(find.byType(Divider).first);
    expect(divider.indent, GroupedMetrics.macos.rowPadding);
  });
}
