import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/job_form_controller.dart';
import 'package:hermes_app/src/schedules/job_form_screen.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';

const _options = {
  'model': 'claude-opus-4',
  'provider': 'anthropic',
  'providers': [
    {
      'slug': 'anthropic',
      'name': 'Anthropic',
      'authenticated': true,
      'models': ['claude-opus-4', 'claude-haiku-4-5'],
      'capabilities': {
        'claude-opus-4': {'reasoning': true},
      },
    },
  ],
};

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/cron/delivery-targets', cronDeliveryTargets)
      ..on('GET', '/api/model/options', _options, query: {'profile': 'work'});
  });

  Map<String, Object?> lastBody() =>
      jsonDecode(server.requests.last.data as String) as Map<String, Object?>;

  final field = find.byKey(const Key('job-model'));

  Future<void> pumpForm(
    WidgetTester tester, {
    CronJob? editing,
    List<String> profileNames = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(1400, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = server.client().raw;
    await tester.pumpWidget(
      MaterialApp(
        home: JobFormScreen(
          controller: JobFormController(
            repository: HermesCronRepository(api),
            editing: editing,
            profile: 'work',
          ),
          models: HermesModelsRepository(api),
          profileNames: profileNames,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (editing == null) {
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('a picked model goes out with its provider on create', (
    tester,
  ) async {
    server.on('POST', '/api/cron/jobs', cronJobRow());
    await pumpForm(tester);
    await tester.enterText(find.byKey(const Key('job-prompt')), 'Check it');

    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('model-anthropic-claude-opus-4')));
    await tester.pumpAndSettle();
    expect(find.text('Reasoning effort'), findsNothing);
    expect(
      find.descendant(of: field, matching: find.text('claude-opus-4')),
      findsOneWidget,
    );
    await save(tester);

    expect(lastBody(), containsPair('model', 'claude-opus-4'));
    expect(lastBody(), containsPair('provider', 'anthropic'));
  });

  testWidgets('without a pick, create sends no model or provider', (
    tester,
  ) async {
    server.on('POST', '/api/cron/jobs', cronJobRow());
    await pumpForm(tester);
    await tester.enterText(find.byKey(const Key('job-prompt')), 'Check it');

    expect(
      find.descendant(of: field, matching: find.text('Profile default')),
      findsOneWidget,
    );
    await save(tester);

    expect(lastBody().keys, isNot(contains('model')));
    expect(lastBody().keys, isNot(contains('provider')));
  });

  testWidgets('going back to the default on edit clears both', (tester) async {
    server.on('PUT', '/api/cron/jobs/job1', cronJobRow());
    final job = CronJob.fromJson(
      cronJobRow(model: 'claude-opus-4', provider: 'anthropic'),
    )!;
    await pumpForm(tester, editing: job);

    expect(find.text('Anthropic'), findsOneWidget);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('model-default')));
    await tester.pumpAndSettle();
    await save(tester);

    expect(lastBody(), {
      'updates': {'model': '', 'provider': ''},
    });
  });

  testWidgets('keeps a saved model the server does not list', (tester) async {
    server.on('PUT', '/api/cron/jobs/job1', cronJobRow());
    final job = CronJob.fromJson(
      cronJobRow(model: 'my-finetune', provider: 'custom:lab'),
    )!;
    await pumpForm(tester, editing: job);

    expect(
      find.descendant(of: field, matching: find.text('my-finetune')),
      findsOneWidget,
    );
    expect(find.text('custom:lab · Not in the server’s list'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('job-name')), 'Renamed');
    await save(tester);

    expect(lastBody(), {
      'updates': {'name': 'Renamed'},
    });
  });

  testWidgets(
    'without the list, shows the saved model and offers only the default',
    (tester) async {
      server.on(
        'GET',
        '/api/model/options',
        {'detail': 'boom'},
        status: 500,
        query: {'profile': 'work'},
      );
      final job = CronJob.fromJson(
        cronJobRow(model: 'claude-opus-4', provider: 'anthropic'),
      )!;
      await pumpForm(tester, editing: job);

      expect(
        find.descendant(of: field, matching: find.text('claude-opus-4')),
        findsOneWidget,
      );
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('model-default')), findsOneWidget);
      expect(
        find.byKey(const Key('model-anthropic-claude-opus-4')),
        findsNothing,
      );
    },
  );

  testWidgets('a new job lists the models of the profile chosen', (
    tester,
  ) async {
    server.on(
      'GET',
      '/api/model/options',
      const {
        'providers': [
          {
            'slug': 'openrouter',
            'models': ['openai/gpt-5.1'],
          },
        ],
      },
      query: {'profile': 'home'},
    );
    await pumpForm(tester, profileNames: const ['work', 'home']);

    await tester.tap(find.byKey(const Key('job-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home').last);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('model-openrouter-openai/gpt-5.1')),
      findsOneWidget,
    );
    expect(
      server
          .requestsTo('GET', '/api/model/options')
          .map((r) => r.queryParameters['profile']),
      ['work', 'home'],
    );
  });
}
