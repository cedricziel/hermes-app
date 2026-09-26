import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/settings/helper_models_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';

Map<String, Object?> _auxiliary({String visionProvider = 'auto'}) => {
  'tasks': [
    {
      'task': 'vision',
      'provider': visionProvider,
      'model': visionProvider == 'auto' ? '' : 'gpt-5-mini',
    },
    {
      'task': 'title_generation',
      'provider': 'openrouter',
      'model': 'gemini-flash',
      'reasoning_effort': 'low',
    },
  ],
  'main': {'provider': 'anthropic', 'model': 'claude-opus-4'},
};

const _options = {
  'model': 'claude-opus-4',
  'provider': 'anthropic',
  'providers': [
    {
      'slug': 'openai',
      'name': 'OpenAI',
      'models': ['gpt-5-mini', 'gpt-5-pro'],
      'capabilities': {
        'gpt-5-mini': {'reasoning': false},
        'gpt-5-pro': {'reasoning': false},
      },
    },
  ],
};

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/model/auxiliary', _auxiliary())
      ..on('GET', '/api/model/options', _options)
      ..on('POST', '/api/model/set', {'ok': true, 'scope': 'auxiliary'});
  });

  List<Map<String, Object?>> posts() => [
    for (final r in server.requestsTo('POST', '/api/model/set'))
      jsonBody(r)! as Map<String, Object?>,
  ];

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: HelperModelsScreen(
          repository: HermesModelsRepository(server.client().raw),
          profile: 'work',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> closePicker(WidgetTester tester) async {
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the slots of the profile with their models', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Vision'), findsOneWidget);
    expect(find.text('Same as main model (claude-opus-4)'), findsOneWidget);
    expect(find.text('Chat titles'), findsOneWidget);
    expect(find.text('gemini-flash · openrouter · Low'), findsOneWidget);
    expect(find.textContaining('new chats'), findsOneWidget);
    expect(
      server.requestsTo('GET', '/api/model/auxiliary').single.queryParameters,
      {'profile': 'work'},
    );
  });

  testWidgets('saves the pick once when the picker closes', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Vision'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gpt-5-pro'));
    await tester.pump();
    await tester.tap(find.text('gpt-5-mini'));
    await tester.pump();
    expect(posts(), isEmpty);
    await closePicker(tester);

    expect(posts(), [containsPair('model', 'gpt-5-mini')]);
    expect(posts().single, containsPair('task', 'vision'));
    expect(posts().single, containsPair('provider', 'openai'));
    expect(server.requestsTo('POST', '/api/model/set').single.queryParameters, {
      'profile': 'work',
    });
    expect(find.text('gpt-5-mini · openai'), findsOneWidget);
  });

  testWidgets('closing without a change sends nothing', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Vision'));
    await tester.pumpAndSettle();
    await closePicker(tester);

    expect(posts(), isEmpty);
  });

  testWidgets('the default entry puts a pinned slot back on auto', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Chat titles'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('model-default')));
    await tester.pumpAndSettle();

    expect(posts().single, containsPair('provider', 'auto'));
    expect(posts().single, containsPair('model', ''));
    expect(posts().single, containsPair('task', 'title_generation'));
    expect(find.text('Same as main model (claude-opus-4)'), findsNWidgets(2));
  });

  group('an expensive model', () {
    setUp(() {
      server.onRequest('POST', '/api/model/set', (request) {
        final body = jsonBody(request)! as Map<String, Object?>;
        return body['confirm_expensive_model'] == true
            ? (status: 200, body: {'ok': true, 'scope': 'auxiliary'})
            : (
                status: 200,
                body: {
                  'ok': false,
                  'confirm_required': true,
                  'confirm_message': 'gpt-5-pro is expensive.',
                },
              );
      });
    });

    Future<void> pickPro(WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Vision'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('gpt-5-pro'));
      await tester.pump();
      await closePicker(tester);
    }

    testWidgets('is saved once confirmed', (tester) async {
      await pickPro(tester);
      expect(find.text('gpt-5-pro is expensive.'), findsOneWidget);

      await tester.tap(find.text('Use it'));
      await tester.pumpAndSettle();

      expect(posts(), hasLength(2));
      expect(posts().last, containsPair('confirm_expensive_model', true));
      expect(find.text('gpt-5-pro · openai'), findsOneWidget);
    });

    testWidgets('is not saved when declined', (tester) async {
      await pickPro(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(posts(), hasLength(1));
      expect(find.text('Same as main model (claude-opus-4)'), findsOneWidget);
    });
  });

  testWidgets('a failed save keeps the old model and says so', (tester) async {
    server.on('POST', '/api/model/set', {'detail': 'no'}, status: 500);
    await pumpScreen(tester);

    await tester.tap(find.text('Vision'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gpt-5-mini'));
    await tester.pump();
    await closePicker(tester);

    expect(find.text('Could not change Vision'), findsOneWidget);
    expect(find.text('Same as main model (claude-opus-4)'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    server.on('GET', '/api/model/auxiliary', {'detail': 'no'}, status: 500);
    await pumpScreen(tester);

    expect(find.text('Could not load the helper models'), findsOneWidget);

    server.on('GET', '/api/model/auxiliary', _auxiliary());
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Vision'), findsOneWidget);
  });

  group('mixture of agents', () {
    setUp(() {
      server
        ..on('GET', '/api/model/moa', moaConfigBody())
        ..on('PUT', '/api/model/moa', {'ok': true})
        ..on('GET', '/api/model/options', {
          ..._options,
          'providers': [
            ...(_options['providers']! as List),
            {
              'slug': 'moa',
              'name': 'Mixture of Agents',
              'models': ['default'],
            },
          ],
        });
    });

    List<Map<String, Object?>> puts() => [
      for (final r in server.requestsTo('PUT', '/api/model/moa'))
        jsonBody(r)! as Map<String, Object?>,
    ];

    Future<void> pickAggregator(WidgetTester tester) async {
      await tester.tap(find.text('Aggregator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('gpt-5-mini'));
      await tester.pump();
      await closePicker(tester);
    }

    testWidgets('lists the advisors and the aggregator', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Mixture of agents'), findsOneWidget);
      expect(find.text('gpt-5.5 · openai-codex'), findsOneWidget);
      expect(
        find.text('deepseek/deepseek-v4-pro · openrouter · High · off'),
        findsOneWidget,
      );
      expect(
        server.requestsTo('GET', '/api/model/moa').single.queryParameters,
        {'profile': 'work'},
      );
    });

    testWidgets('saves the whole config with the one slot changed', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Aggregator'));
      await tester.pumpAndSettle();
      expect(find.text('Mixture of Agents'), findsNothing);
      expect(find.byKey(const Key('model-default')), findsNothing);
      await tester.tap(find.text('gpt-5-mini'));
      await tester.pump();
      await closePicker(tester);

      final presets = puts().single['presets']! as Map;
      expect(presets.keys, ['default', 'cheap']);
      final preset = presets['default'] as Map;
      expect(preset['aggregator'], containsPair('model', 'gpt-5-mini'));
      expect(preset['reference_models'], hasLength(3));
      expect(
        server.requestsTo('PUT', '/api/model/moa').single.queryParameters,
        {'profile': 'work'},
      );
      expect(find.text('gpt-5-mini · openai'), findsOneWidget);
      expect(posts(), isEmpty);
    });

    testWidgets('keeps the MoA rows closed while a save runs', (tester) async {
      final answer = Completer<FakeResponse>();
      server.onRequest('PUT', '/api/model/moa', (_) => answer.future);
      await pumpScreen(tester);

      await tester.tap(find.text('Aggregator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('gpt-5-mini'));
      await tester.pump();
      await tester.tapAt(const Offset(4, 4));
      // The row's progress spins until the save answers, so nothing settles.
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Advisor 1'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(BottomSheet), findsNothing);
      answer.complete((status: 200, body: {'ok': true}));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advisor 1'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('a rejected config keeps the old model', (tester) async {
      server.on('PUT', '/api/model/moa', {
        'detail': 'Invalid MoA config',
      }, status: 422);
      await pumpScreen(tester);

      await pickAggregator(tester);

      expect(find.text('Could not change Aggregator'), findsOneWidget);
      expect(
        find.text('anthropic/claude-opus-4.8 · openrouter'),
        findsOneWidget,
      );
    });

    testWidgets('leaves the section out when MoA cannot be read', (
      tester,
    ) async {
      server.on('GET', '/api/model/moa', {'detail': 'no'}, status: 500);
      await pumpScreen(tester);

      expect(find.text('Vision'), findsOneWidget);
      expect(find.text('Mixture of agents'), findsNothing);
    });
  });
}
