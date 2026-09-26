import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
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
        ModelOption(id: 'claude-sonnet-4-5'),
      ],
    ),
  ],
);

void main() {
  testWidgets('without effort it names the purpose, offers no effort, and '
      'closes on a pick', (tester) async {
    final picked = <ModelChoice>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModelPicker(
                context,
                options: _options,
                selected: const ModelChoice(
                  'anthropic',
                  'claude-opus-4',
                  effort: 'high',
                ),
                onChanged: picked.add,
                withEffort: false,
                title: 'Default model',
                note: 'New chats use this model.',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Default model'), findsOneWidget);
    expect(find.text('New chats use this model.'), findsOneWidget);
    expect(find.text('Reasoning effort'), findsNothing);

    await tester.tap(find.text('claude-sonnet-4-5'));
    await tester.pumpAndSettle();

    expect(picked, [const ModelChoice('anthropic', 'claude-sonnet-4-5')]);
    expect(find.text('Default model'), findsNothing);
  });

  testWidgets('a default entry comes first, is checked while nothing is '
      'selected, and reports its pick', (tester) async {
    var usedDefault = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: ModelPicker(
            options: _options,
            selected: const ModelChoice('anthropic', 'claude-opus-4'),
            onChanged: (_) {},
            onUseDefault: () => usedDefault++,
          ),
        ),
      ),
    );

    final entry = find.byKey(const Key('model-default'));
    expect(entry, findsOneWidget);
    expect(
      find.descendant(of: entry, matching: find.byIcon(Icons.check)),
      findsNothing,
    );

    await tester.tap(entry);
    await tester.pump();

    expect(usedDefault, 1);
    expect(
      find.descendant(of: entry, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });
}
