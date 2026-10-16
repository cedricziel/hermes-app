import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/model_options_state.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/composer_model_pill.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _profile = HermesProfile(
  name: 'research',
  displayName: 'Research partner for every international product launch',
);
const _model = ModelChoice(
  'demo',
  'demo/long-context-research-and-planning-model',
);
const _options = ModelOptions(
  current: _model,
  providers: [
    ModelProviderOption(
      id: 'demo',
      models: [
        ModelOption(id: 'demo/long-context-research-and-planning-model'),
      ],
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  double width = 320,
  double scale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child,
            ),
          ),
        ),
      ),
    ),
  ),
);

Widget _pair({
  RecipientSelectorState recipient = RecipientSelectorState.ready,
  ModelOptionsState model = ModelOptionsState.ready,
  VoidCallback? onRecipientRetry,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: ProfileRecipientChip(
        profile: _profile,
        state: recipient,
        onTap: () {},
        onRetry: onRecipientRetry ?? () {},
        onSetup: () {},
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: ComposerModelPill(
        options: _options,
        choice: null,
        state: model,
        onChanged: (_) {},
        onRetry: () {},
        onSetup: () {},
      ),
    ),
  ],
);

void main() {
  testWidgets('loading retains the full selected recipient accessible name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const ProfileRecipientChip(
        profile: _profile,
        state: RecipientSelectorState.loading,
      ),
    );

    expect(find.text('Loading recipients'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Loading recipients, selected recipient ${_profile.label}',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('missing selection offers a recipient choice', (tester) async {
    var opened = false;
    await _pump(
      tester,
      ProfileRecipientChip(
        profile: null,
        state: RecipientSelectorState.choose,
        onTap: () => opened = true,
      ),
    );

    await tester.tap(find.text('Choose a recipient'));

    expect(opened, isTrue);
  });

  testWidgets('empty recipients expose actionable setup', (tester) async {
    var opened = false;
    await _pump(
      tester,
      ProfileRecipientChip(
        profile: null,
        state: RecipientSelectorState.empty,
        onSetup: () => opened = true,
      ),
    );

    expect(find.text('No profiles available'), findsOneWidget);
    await tester.tap(find.text('Set up profiles'));

    expect(opened, isTrue);
  });

  testWidgets(
    'unavailable recipient stays named and Retry preserves selection',
    (tester) async {
      final handle = tester.ensureSemantics();
      var retries = 0;
      var choices = 0;
      await _pump(
        tester,
        ProfileRecipientChip(
          profile: _profile,
          state: RecipientSelectorState.unavailable,
          onTap: () => choices++,
          onRetry: () => retries++,
        ),
      );

      expect(
        find.bySemanticsLabel('${_profile.label} unavailable'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));

      expect(retries, 1);
      expect(choices, 0);
      handle.dispose();
    },
  );

  testWidgets('recipient retry leaves the ready model picker usable', (
    tester,
  ) async {
    var retries = 0;
    await _pump(
      tester,
      _pair(
        recipient: RecipientSelectorState.failed,
        onRecipientRetry: () => retries++,
      ),
    );

    await tester.tap(find.text('Retry'));
    await tester.tap(find.byKey(const Key('composer-model-pill')));
    await tester.pumpAndSettle();

    expect(retries, 1);
    expect(
      find.byKey(
        const Key('model-demo-demo/long-context-research-and-planning-model'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty recipient picker offers profile setup', (tester) async {
    var opened = false;
    await _pump(
      tester,
      RecipientPicker(
        profiles: const [],
        onSelected: (_) {},
        onSetup: () => opened = true,
      ),
    );

    expect(find.text('No profiles available'), findsOneWidget);
    await tester.tap(find.text('Set up profiles'));

    expect(opened, isTrue);
  });

  for (final dark in [false, true]) {
    for (final width in [200.0, 288.0, 720.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'long selector labels stay side by side: dark=$dark width=$width scale=$scale',
          (tester) async {
            final handle = tester.ensureSemantics();
            await _pump(
              tester,
              _pair(),
              width: width,
              scale: scale,
              dark: dark,
            );
            final recipient = find.byType(ProfileRecipientChip);
            final model = find.byType(ComposerModelPill);

            expect(
              tester.getTopLeft(recipient).dy,
              tester.getTopLeft(model).dy,
            );
            expect(
              tester.getRect(recipient).right,
              lessThanOrEqualTo(tester.getRect(model).left),
            );
            expect(
              find.bySemanticsLabel('To: ${_profile.label}'),
              findsOneWidget,
            );
            expect(
              find.bySemanticsLabel(RegExp(RegExp.escape(_model.modelId))),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            handle.dispose();
          },
        );
      }
    }
  }

  testWidgets('both retry actions stay independent in compact large text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var retries = 0;
    await _pump(
      tester,
      _pair(
        recipient: RecipientSelectorState.failed,
        model: ModelOptionsState.failed,
        onRecipientRetry: () => retries++,
      ),
      width: 200,
      scale: 2,
    );

    await tester.tap(find.bySemanticsLabel('Retry recipients'));

    expect(retries, 1);
    expect(find.bySemanticsLabel('Retry models'), findsOneWidget);
    expect(
      tester.getSize(find.text('Could not load recipients')).width,
      greaterThan(0),
    );
    expect(
      tester.getSize(find.text('Could not load models')).width,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('compact large text keeps both setup labels visible and named', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _pair(
        recipient: RecipientSelectorState.empty,
        model: ModelOptionsState.incomplete,
      ),
      width: 200,
      scale: 2,
    );

    expect(
      tester.getSize(find.text('No profiles available')).width,
      greaterThan(0),
    );
    expect(tester.getSize(find.text('Set up a model')).width, greaterThan(0));
    expect(find.bySemanticsLabel('Set up profiles'), findsOneWidget);
    expect(find.bySemanticsLabel('Set up a model'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
