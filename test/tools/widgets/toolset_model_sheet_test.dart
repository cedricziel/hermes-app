import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/tools_models.dart';
import 'package:hermes_app/src/tools/widgets/toolset_model_sheet.dart';

import 'pump_tools.dart';

const _models = [
  ToolsetModel(
    id: 'fast',
    display: 'Bright Fast',
    speed: 'Quick',
    strengths: 'Drafts',
    price: r'$0.01 per image',
  ),
  ToolsetModel(
    id: 'pro',
    display: 'Bright Pro',
    speed: 'About 12 seconds',
    price: 'From 5 cents, more at 4K',
  ),
  ToolsetModel(id: 'plain', display: 'Bright Plain'),
];

Widget _sheet({
  String? current = 'pro',
  ValueChanged<String>? onPick,
  VoidCallback? onDone,
}) => ToolsetModelSheet(
  models: _models,
  current: current,
  defaultModel: 'fast',
  provider: 'Brightfetch',
  onPick: onPick ?? (_) {},
  onDone: onDone ?? () {},
);

void main() {
  testWidgets('title, Done, names, Default meta, second lines and footer', (
    t,
  ) async {
    await pumpTools(t, _sheet());
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('Bright Fast'), findsOneWidget);
    expect(find.textContaining('Default'), findsOneWidget);
    expect(find.text(r'Quick · Drafts · $0.01 per image'), findsOneWidget);
    // The price is free text and is shown as given.
    expect(
      find.text('About 12 seconds · From 5 cents, more at 4K'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Prices come from the provider, Brightfetch, as it gives them. Applies from your next chat.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('only the default model has the Default word', (t) async {
    await pumpTools(t, _sheet());
    expect(find.textContaining('Default'), findsOneWidget);
  });

  testWidgets('the current model is checked, the others are not', (t) async {
    final handle = t.ensureSemantics();
    await pumpTools(t, _sheet(current: 'pro'));
    for (final (id, checked) in [
      ('pro', true),
      ('fast', false),
      ('plain', false),
    ]) {
      expect(
        t.getSemantics(find.byKey(Key('tools-model-$id'))),
        isSemantics(
          hasCheckedState: true,
          isChecked: checked,
          isInMutuallyExclusiveGroup: true,
        ),
        reason: id,
      );
    }
    handle.dispose();
  });

  testWidgets('a tap picks the model and Done closes', (t) async {
    final picked = <String>[];
    var done = 0;
    await pumpTools(t, _sheet(onPick: picked.add, onDone: () => done++));
    await t.tap(find.text('Bright Plain'));
    expect(picked, ['plain']);
    await t.tap(find.text('Done'));
    expect(done, 1);
  });

  testWidgets('the title is a heading', (t) async {
    final handle = t.ensureSemantics();
    await pumpTools(t, _sheet());
    expect(t.getSemantics(find.text('Model')), isSemantics(isHeader: true));
    handle.dispose();
  });

  for (final (platform, min) in [
    (TargetPlatform.iOS, 44.0),
    (TargetPlatform.android, 48.0),
    (TargetPlatform.macOS, 28.0),
  ]) {
    testWidgets('Done is at least $min on $platform', (t) async {
      await pumpTools(t, _sheet(), platform: platform);
      expect(
        t.getSize(find.widgetWithText(TextButton, 'Done')).height,
        greaterThanOrEqualTo(min),
      );
    });
  }

  testWidgets('wraps at 3x in German without overflow', (t) async {
    await pumpTools(t, _sheet(), textScale: 3, locale: const Locale('de'));
    expect(t.takeException(), isNull);
    expect(find.text('Fertig'), findsOneWidget);
    expect(find.textContaining('Standard'), findsOneWidget);
  });

  testWidgets(
    'showToolsetModelSheet opens, reflects a pick and closes on Done',
    (t) async {
      final picked = <String>[];
      await pumpTools(
        t,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showToolsetModelSheet(
              context,
              models: _models,
              current: 'pro',
              defaultModel: 'fast',
              provider: 'Brightfetch',
              onPick: picked.add,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byType(ToolsetModelSheet), findsOneWidget);
      await t.tap(find.textContaining('Bright Fast'));
      await t.pump();
      expect(picked, ['fast']);
      expect(
        RadioGroup.maybeOf<String>(t.element(find.byType(Radio<String>).first))
            ?.groupValue,
        'fast',
      );
      await t.tap(find.text('Done'));
      await t.pumpAndSettle();
      expect(find.byType(ToolsetModelSheet), findsNothing);
    },
  );
}
