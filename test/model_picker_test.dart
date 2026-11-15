import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/widgets/safe_path_text.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/widgets/model_picker.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/screenshot_recorder.dart';

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
      tester.getSemantics(entry),
      isSemantics(hasCheckedState: true, isChecked: false),
    );

    await tester.tap(entry);
    await tester.pump();

    expect(usedDefault, 1);
    expect(
      tester.getSemantics(entry),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    expect(
      tester.getSemantics(
        find.byKey(const Key('model-anthropic-claude-opus-4')),
      ),
      isSemantics(hasCheckedState: true, isChecked: false),
    );
  });

  testWidgets('a long list can be searched by model and provider', (
    tester,
  ) async {
    final options = ModelOptions(
      providers: [
        ModelProviderOption(
          id: 'openrouter',
          label: 'OpenRouter',
          models: [
            for (var i = 0; i < ModelPicker.searchAbove; i++)
              ModelOption(id: 'vendor/model-$i'),
          ],
        ),
        const ModelProviderOption(
          id: 'anthropic',
          label: 'Anthropic',
          models: [ModelOption(id: 'claude-opus-4')],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: ModelPicker(
            options: options,
            selected: null,
            onChanged: (_) {},
            onUseDefault: () {},
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'OPUS',
    );
    await tester.pump();

    expect(find.text('claude-opus-4'), findsOneWidget);
    expect(find.text('vendor/model-0'), findsNothing);
    expect(find.text('OpenRouter'), findsNothing);
    expect(find.byKey(const Key('model-default')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'openrouter',
    );
    await tester.pump();

    expect(find.text('vendor/model-0'), findsOneWidget);
    expect(find.text('claude-opus-4'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('settings-search-field')),
      'gpt',
    );
    await tester.pump();

    expect(find.text('No models match “gpt”'), findsOneWidget);
  });

  testWidgets('a short list has no search field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: ModelPicker(
            options: _options,
            selected: null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('settings-search-field')), findsNothing);
  });

  group('the default entry names the default model', () {
    Widget picker(ModelOptions options, {ModelChoice? selected}) => MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: ModelPicker(
          options: options,
          selected: selected,
          onChanged: (_) {},
          onUseDefault: () {},
        ),
      ),
    );

    testWidgets('with its name in the row and its semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(picker(_options));

      final entry = find.byKey(const Key('model-default'));
      expect(
        find.descendant(of: entry, matching: find.text('Uses claude-opus-4')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(entry).label,
        allOf(contains('default'), contains('claude-opus-4')),
      );
      expect(tester.getSize(entry).height, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    testWidgets('and is plain when the options name no default', (
      tester,
    ) async {
      await tester.pumpWidget(
        picker(ModelOptions(providers: _options.providers)),
      );

      final entry = find.byKey(const Key('model-default'));
      expect(
        find.descendant(
          of: entry,
          matching: find.text('Use the profile’s default'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: entry, matching: find.textContaining('Uses')),
        findsNothing,
      );
      // No second line either: an empty subtitle would still draw a blank one.
      expect(find.descendant(of: entry, matching: find.byType(Text)), findsOne);
    });

    testWidgets('shows control characters of a server name visibly', (
      tester,
    ) async {
      await tester.pumpWidget(
        picker(
          ModelOptions(
            current: const ModelChoice('p', 'evil\u202Emodel'),
            providers: _options.providers,
          ),
        ),
      );

      expect(find.text('Uses evil<U+202E>model'), findsOneWidget);
    });

    testWidgets('and follows a quiet refresh while the picker is open', (
      tester,
    ) async {
      ModelOptions optionsFor(String model) => ModelOptions(
        current: ModelChoice('anthropic', model),
        providers: _options.providers,
      );
      var current = optionsFor('claude-opus-4');
      final updates = ValueNotifier<int>(0);
      addTearDown(updates.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModelPicker(
                  context,
                  options: current,
                  selected: null,
                  onChanged: (_) {},
                  onUseDefault: () {},
                  updates: updates,
                  latest: () => current,
                  latestSelected: () => null,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Uses claude-opus-4'), findsOneWidget);

      current = optionsFor('claude-sonnet-4-5');
      updates.value++;
      await tester.pumpAndSettle();

      expect(find.text('Uses claude-sonnet-4-5'), findsOneWidget);
      expect(find.text('Uses claude-opus-4'), findsNothing);

      current = ModelOptions(providers: _options.providers);
      updates.value++;
      await tester.pumpAndSettle();

      expect(find.textContaining('Uses'), findsNothing);
    });
  });

  group('long ids and large text', () {
    const longId = 'acme-lm-large-2025-0914-long-context-instruct';
    const otherId = 'acme-lm-large-2025-0914-long-context-preview';
    const long = ModelOptions(
      current: ModelChoice('acme', longId),
      providers: [
        ModelProviderOption(
          id: 'acme',
          label: 'Acme',
          models: [
            ModelOption(id: longId),
            ModelOption(id: otherId),
            ModelOption(id: 'acme-lm-small', reasoning: false),
          ],
        ),
      ],
    );

    Future<void> pump(
      WidgetTester tester,
      ModelOptions options, {
      ModelChoice? selected,
      TargetPlatform platform = TargetPlatform.iOS,
      double width = 320,
      double scale = 1,
    }) async {
      // Real fonts: in Ahem a glyph is as wide as it is tall, which no
      // language needs at a text scale of 2.
      await tester.runAsync(loadTestFonts);
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: withScreenshotFont(
            buildHermesLightTheme().copyWith(platform: platform),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: ModelPicker(
              options: options,
              selected: selected,
              onChanged: (_) {},
              onUseDefault: () {},
            ),
          ),
        ),
      );
      // A new theme animates; settle so the platform is the new one.
      await tester.pumpAndSettle();
    }

    Finder under(Finder parent, Finder child) =>
        find.descendant(of: parent, matching: child);

    testWidgets('the default subtitle is cut in the middle, keeps "Uses" and '
        'the end of the id, and the full id is in the semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, long, width: 260);

      final entry = find.byKey(const Key('model-default'));
      final subtitle = tester
          .widgetList<Text>(under(entry, find.byType(Text)))
          .map((text) => text.data ?? '')
          .firstWhere((text) => text.startsWith('Uses'));
      expect(subtitle, contains('…'));
      expect(subtitle, endsWith('instruct'));
      expect(tester.getSemantics(entry).label, contains(longId));
      handle.dispose();
    });

    testWidgets('model rows are cut in the middle and tell ids apart', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, long, width: 260);

      for (final (id, end) in [(longId, 'instruct'), (otherId, 'preview')]) {
        final row = find.byKey(Key('model-acme-$id'));
        final title = tester
            .widgetList<Text>(under(row, find.byType(Text)))
            .map((text) => text.data ?? '')
            .single;
        expect(title, contains('…'));
        expect(title, endsWith(end));
        expect(tester.getSemantics(row).label, contains(id));
      }
      handle.dispose();
    });

    testWidgets('hover text names the id on a desktop platform only', (
      tester,
    ) async {
      await pump(tester, long, platform: TargetPlatform.macOS, width: 500);
      expect(find.byTooltip(longId), findsOneWidget);

      await pump(tester, long, platform: TargetPlatform.iOS, width: 500);
      expect(find.byTooltip(longId), findsNothing);
    });

    testWidgets('effort pills have a hit area of 44 on iOS, 48 on Material '
        'and 28 on a Mac, and are drawn 36, 40 and 28', (tester) async {
      const picked = ModelChoice('acme', longId, effort: 'high');
      for (final (platform, hit, drawn) in [
        (TargetPlatform.iOS, 44.0, 36.0),
        (TargetPlatform.android, 48.0, 40.0),
        (TargetPlatform.macOS, 28.0, 28.0),
      ]) {
        await pump(tester, long, selected: picked, platform: platform);
        final pill = find.byKey(const Key('effort-high'));
        expect(tester.getSize(pill).height, hit, reason: '$platform hit');
        expect(
          tester.getSize(under(pill, find.byType(Material)).first).height,
          drawn,
          reason: '$platform drawn',
        );
      }
    });

    testWidgets('a tap in the margin of the 44 point hit area picks the '
        'effort', (tester) async {
      final picked = <ModelChoice>[];
      tester.view
        ..physicalSize = const Size(320, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: ModelPicker(
              options: long,
              selected: const ModelChoice('acme', longId),
              onChanged: picked.add,
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(const Key('effort-high')));
      await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
      expect(picked.last.effort, 'high');
    });

    testWidgets('the effort block is pinned at the normal size and moves '
        'into the list from a text scale of 1.3', (tester) async {
      const picked = ModelChoice('acme', longId, effort: 'high');
      final block = find.byKey(const Key('effort-high'));

      await pump(tester, long, selected: picked, scale: 1.2);
      expect(under(find.byType(ListView), block), findsNothing);
      expect(block, findsOneWidget);

      await pump(tester, long, selected: picked, scale: 1.3);
      expect(under(find.byType(ListView), block), findsOneWidget);

      await pump(tester, long, selected: picked, scale: 2, width: 390);
      expect(under(find.byType(ListView), block), findsOneWidget);
    });

    testWidgets('at a text scale of 2 the default row wraps its title and '
        'shows the id, cut in the middle after two lines', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, long, width: 390, scale: 2);

      final entry = find.byKey(const Key('model-default'));
      final title = under(entry, find.text('Use the profile’s default'));
      expect(title, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(title);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.maxLines, 2);

      final subtitle = tester
          .widgetList<Text>(under(entry, find.byType(Text)))
          .map((text) => text.data ?? '')
          .firstWhere((text) => text.startsWith('Uses'));
      expect(subtitle, endsWith('instruct'));
      expect(tester.getSemantics(entry).label, contains(longId));
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });

  group('a server id is shown with its control characters visible', () {
    const evil = 'evil\u202Emodel';
    const options = ModelOptions(
      current: ModelChoice('p', evil),
      providers: [
        ModelProviderOption(
          id: 'p',
          label: 'P',
          models: [ModelOption(id: evil)],
        ),
      ],
    );

    testWidgets('in the model row, the checked row and the default row', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: ModelPicker(
              options: options,
              selected: const ModelChoice('p', evil),
              onChanged: (_) {},
              onUseDefault: () {},
            ),
          ),
        ),
      );

      final row = find.byKey(const Key('model-p-$evil'));
      expect(
        find.descendant(of: row, matching: find.text(safePathText(evil))),
        findsOneWidget,
      );
      expect(find.text('evil<U+202E>model'), findsOneWidget);
      expect(find.text('Uses evil<U+202E>model'), findsOneWidget);
      expect(find.textContaining('\u202E'), findsNothing);
    });
  });
}
