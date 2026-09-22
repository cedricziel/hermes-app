import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/model_effort_picker.dart';

const _providers = [
  ModelProviderOption(
    id: 'anthropic',
    status: ModelProviderStatus.ready,
    models: [
      ModelOption(
        id: 'claude-sonnet-5',
        supportedEfforts: ['low', 'medium', 'high'],
      ),
    ],
  ),
];

Widget _pickerWith({String? selectedEffort}) => MaterialApp(
  home: Scaffold(
    body: ModelEffortPicker(
      providers: _providers,
      selectedProviderId: 'anthropic',
      selectedModelId: 'claude-sonnet-5',
      selectedEffort: selectedEffort,
      onModelSelected: (_, _) {},
      onEffortSelected: (_) {},
    ),
  ),
);

SegmentedButton<String> _segmentedButton(WidgetTester tester) => tester
    .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));

void main() {
  testWidgets('selects nothing when no effort is set', (tester) async {
    await tester.pumpWidget(_pickerWith());

    expect(_segmentedButton(tester).selected, isEmpty);
  });

  testWidgets('selects nothing when the effort is stale for this model', (
    tester,
  ) async {
    await tester.pumpWidget(_pickerWith(selectedEffort: 'minimal'));

    expect(_segmentedButton(tester).selected, isEmpty);
  });

  testWidgets('selects the matching segment', (tester) async {
    await tester.pumpWidget(_pickerWith(selectedEffort: 'medium'));

    expect(_segmentedButton(tester).selected, {'medium'});
  });

  testWidgets('reports the tapped effort', (tester) async {
    String? reported;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelEffortPicker(
            providers: _providers,
            selectedProviderId: 'anthropic',
            selectedModelId: 'claude-sonnet-5',
            onModelSelected: (_, _) {},
            onEffortSelected: (value) => reported = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('High'));
    await tester.pump();

    expect(reported, 'high');
  });
}
