import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/composer_model_pill.dart';
import 'package:hermes_app/src/models/widgets/model_picker.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _options = ModelOptions(
  current: ModelChoice('anthropic', 'claude-opus-4'),
  providers: [
    ModelProviderOption(
      id: 'anthropic',
      label: 'Anthropic',
      models: [
        ModelOption(id: 'claude-opus-4', canDisableReasoning: true),
        ModelOption(id: 'claude-haiku-4-5', reasoning: false),
      ],
    ),
  ],
);

Future<List<ModelChoice>> _pumpPill(
  WidgetTester tester, {
  ModelOptions? options = _options,
  double width = 400,
}) async {
  final picked = <ModelChoice>[];
  tester.view
    ..physicalSize = Size(width, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  ModelChoice? choice;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ComposerModelPill(
            options: options,
            choice: choice,
            onChanged: (next) => setState(() {
              choice = next;
              picked.add(next);
            }),
          ),
        ),
      ),
    ),
  );
  return picked;
}

void main() {
  testWidgets('names the default model until one is picked', (tester) async {
    await _pumpPill(tester);

    expect(find.text('claude-opus-4'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('picking a model and an effort changes the pill', (tester) async {
    final picked = await _pumpPill(tester);

    await tester.tap(find.byKey(const Key('composer-model-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('effort-high')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('model-anthropic-claude-haiku-4-5')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('effort-high')), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(picked, [
      const ModelChoice('anthropic', 'claude-opus-4', effort: 'high'),
      const ModelChoice('anthropic', 'claude-haiku-4-5'),
    ]);
    expect(find.text('claude-haiku-4-5'), findsOneWidget);
  });

  testWidgets('shows the effort after the model', (tester) async {
    await _pumpPill(tester);

    await tester.tap(find.byKey(const Key('composer-model-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('effort-none')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text(' · Off'), findsOneWidget);
  });

  testWidgets('opens as a dialog on a wide window', (tester) async {
    await _pumpPill(tester, width: 1200);

    await tester.tap(find.byKey(const Key('composer-model-pill')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('shows nothing without options', (tester) async {
    await _pumpPill(tester, options: null);

    expect(find.byKey(const Key('composer-model-pill')), findsNothing);
  });

  testWidgets('the picker marks the selected model as selected, and follows '
      'a new selection from its parent', (tester) async {
    Widget picker(ModelChoice selected) => MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: ModelPicker(
          options: _options,
          selected: selected,
          onChanged: (_) {},
        ),
      ),
    );
    bool isSelected(String id) => tester
        .widget<ListTile>(find.byKey(Key('model-anthropic-$id')))
        .selected;

    await tester.pumpWidget(
      picker(const ModelChoice('anthropic', 'claude-opus-4')),
    );
    expect(isSelected('claude-opus-4'), isTrue);
    expect(isSelected('claude-haiku-4-5'), isFalse);

    await tester.pumpWidget(
      picker(const ModelChoice('anthropic', 'claude-haiku-4-5')),
    );
    expect(isSelected('claude-opus-4'), isFalse);
    expect(isSelected('claude-haiku-4-5'), isTrue);
  });
}
