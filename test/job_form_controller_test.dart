import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/job_draft.dart';
import 'package:hermes_app/src/schedules/job_form_controller.dart';
import 'package:hermes_app/src/schedules/job_form_screen.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesCronRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesCronRepository(server.client().raw);
  });

  Map<String, Object?> lastBody() =>
      jsonDecode(server.requests.last.data as String) as Map<String, Object?>;

  group('JobFormController', () {
    JobFormController create({String? profile = 'work'}) => JobFormController(
      repository: repository,
      profile: profile,
      now: () => DateTime(2026, 9, 20, 12),
    );

    test('does not save without a prompt, a skill or a script', () async {
      final form = create();

      final job = await form.save();

      expect(job, isNull);
      expect(form.error, 'A task needs a prompt, a skill or a script');
      expect(server.requests, isEmpty);
    });

    test(
      'does not start protected work while session activity is paused',
      () async {
        final activity = ValueNotifier(false);
        final form = JobFormController(
          repository: repository,
          profile: 'work',
          activity: activity,
        )..draft.prompt = 'Keep this draft';

        await form.loadTargets();
        await expectLater(
          form.save(),
          throwsA(isA<JobFormActivityCancelled>()),
        );

        expect(form.active, isFalse);
        expect(form.draft.prompt, 'Keep this draft');
        expect(server.requests, isEmpty);
        activity.dispose();
        form.dispose();
      },
    );

    test(
      'drops pending metadata and reloads it after activity resumes',
      () async {
        final targetsGate = Completer<FakeResponse>();
        final modelsGate = Completer<FakeResponse>();
        var targetCalls = 0;
        var modelCalls = 0;
        final targetReloaded = Completer<void>();
        final modelReloaded = Completer<void>();
        final resumedMetadataLoaded = Completer<void>();
        server
          ..onRequest('GET', '/api/cron/delivery-targets', (_) {
            if (++targetCalls == 1) return targetsGate.future;
            targetReloaded.complete();
            return (
              status: 200,
              body: {
                'targets': [
                  {'id': 'slack', 'name': 'Slack'},
                ],
              },
            );
          })
          ..onRequest('GET', '/api/model/options', (_) {
            if (++modelCalls == 1) return modelsGate.future;
            modelReloaded.complete();
            return (
              status: 200,
              body: {
                'providers': [
                  {
                    'slug': 'anthropic',
                    'authenticated': true,
                    'models': ['claude-opus-4'],
                  },
                ],
              },
            );
          });
        final activity = ValueNotifier(true);
        final form = JobFormController(
          repository: repository,
          profile: 'work',
          activity: activity,
        )..draft.prompt = 'Keep this draft';
        form.addListener(() {
          if (form.targets.any((target) => target.id == 'slack') &&
              form.modelOptions != null &&
              !resumedMetadataLoaded.isCompleted) {
            resumedMetadataLoaded.complete();
          }
        });
        final models = HermesModelsRepository(server.client().raw);

        final targetsRead = form.loadTargets();
        final modelsRead = form.loadModels(models);
        await Future<void>.delayed(Duration.zero);
        activity.value = false;
        targetsGate.complete((
          status: 200,
          body: {
            'targets': [
              {'id': 'stale', 'name': 'Stale'},
            ],
          },
        ));
        modelsGate.complete((status: 200, body: {'providers': <Object?>[]}));
        await Future.wait<void>([targetsRead, modelsRead]);

        expect(form.targets.map((target) => target.id), ['local']);
        expect(form.modelOptions, isNull);
        expect(form.draft.prompt, 'Keep this draft');

        activity.value = true;
        await Future.wait([targetReloaded.future, modelReloaded.future]);
        await resumedMetadataLoaded.future;

        expect(
          form.targets.map((target) => target.id),
          containsAll(['local', 'slack']),
        );
        expect(form.modelOptions, isNotNull);
        expect(form.draft.prompt, 'Keep this draft');
        activity.dispose();
        form.dispose();
      },
    );

    test('rejects a save result from an earlier activity epoch', () async {
      final gate = Completer<FakeResponse>();
      server.onRequest('POST', '/api/cron/jobs', (_) => gate.future);
      final activity = ValueNotifier(true);
      final form =
          JobFormController(
              repository: repository,
              profile: 'work',
              activity: activity,
            )
            ..draft.prompt = 'Keep this draft'
            ..draft.spec = const EverySpec(6, EveryUnit.hours);

      final save = form.save();
      activity.value = false;
      gate.complete((status: 200, body: cronJobRow(id: 'created')));

      await expectLater(save, throwsA(isA<JobFormActivityCancelled>()));
      expect(form.draft.prompt, 'Keep this draft');
      expect(form.error, isNull);
      expect(server.requestsTo('POST', '/api/cron/jobs'), hasLength(1));

      activity.value = true;
      await Future<void>.delayed(Duration.zero);
      expect(server.requestsTo('POST', '/api/cron/jobs'), hasLength(1));
      activity.dispose();
      form.dispose();
    });

    test(
      'a stale save cancellation does not clear a newer save barrier',
      () async {
        final oldSaveGate = Completer<FakeResponse>();
        final newSaveGate = Completer<FakeResponse>();
        final newPostStarted = Completer<void>();
        var postCount = 0;
        server.onRequest('POST', '/api/cron/jobs', (_) {
          postCount++;
          if (postCount == 2) newPostStarted.complete();
          return postCount == 1 ? oldSaveGate.future : newSaveGate.future;
        });
        final activity = ValueNotifier(true);
        final form =
            JobFormController(
                repository: repository,
                profile: 'work',
                activity: activity,
                now: () => DateTime(2026, 9, 20, 12),
              )
              ..draft.prompt = 'Keep this draft'
              ..draft.spec = const EverySpec(6, EveryUnit.hours);
        final newSaveStarted = Completer<void>();
        late Future<CronJob?> newSave;
        form.addListener(() {
          if (!form.saving && form.active && !newSaveStarted.isCompleted) {
            newSave = form.save();
            newSaveStarted.complete();
          }
        });

        final oldSave = form.save();
        activity.value = false;
        activity.value = true;
        oldSaveGate.complete((status: 200, body: cronJobRow(id: 'old')));

        await expectLater(oldSave, throwsA(isA<JobFormActivityCancelled>()));
        await newSaveStarted.future;
        await newPostStarted.future;
        expect(form.saving, isTrue);
        expect(await form.save(), isNull);
        expect(postCount, 2);

        newSaveGate.complete((status: 200, body: cronJobRow(id: 'new')));
        expect((await newSave)?.id, 'new');
        expect(form.saving, isFalse);
        activity.dispose();
        form.dispose();
      },
    );

    test('creates in the chosen profile', () async {
      server.on(
        'POST',
        '/api/cron/jobs',
        cronJobRow(id: 'new'),
        query: {'profile': 'work'},
      );
      final form = create()
        ..draft.prompt = 'Check it'
        ..draft.spec = const EverySpec(6, EveryUnit.hours);

      final job = await form.save();

      expect(job?.id, 'new');
      expect(lastBody(), containsPair('schedule', 'every 6h'));
    });

    test(
      'keeps the values and shows the reason when the server refuses',
      () async {
        server.on('POST', '/api/cron/jobs', {
          'detail': 'script must be inside /x/scripts',
        }, status: 400);
        final form = create()
          ..draft.prompt = 'x'
          ..draft.script = '../evil.sh';

        expect(await form.save(), isNull);

        expect(form.error, 'script must be inside /x/scripts');
        expect(form.draft.script, '../evil.sh');
        expect(form.saving, isFalse);
      },
    );

    test('sends one request for two quick saves', () async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', '/api/cron/jobs', (_) => answer.future);
      final form = create()..draft.prompt = 'x';

      final first = form.save();
      final second = await form.save();
      answer.complete((status: 200, body: cronJobRow()));
      await first;

      expect(second, isNull);
      expect(server.requests.where((r) => r.method == 'POST'), hasLength(1));
    });

    test(
      'editing sends only what changed and leaves the schedule alone',
      () async {
        final job = CronJob.fromJson(cronJobRow(prompt: 'Old'))!;
        server.on('PUT', '/api/cron/jobs/job1', cronJobRow());
        final form = JobFormController(repository: repository, editing: job)
          ..draft.prompt = 'New';

        await form.save();

        expect(lastBody(), {
          'updates': {'prompt': 'New'},
        });
      },
    );

    test('editing sends the schedule once "when" was touched', () async {
      final job = CronJob.fromJson(cronJobRow())!;
      server.on('PUT', '/api/cron/jobs/job1', cronJobRow());
      final form = JobFormController(repository: repository, editing: job);
      form.draft.spec = const DailySpec(7, 0);
      form.changed(when: true);

      await form.save();

      expect(lastBody(), {
        'updates': {'schedule': '0 7 * * *'},
      });
    });

    test('is dirty only once something changed', () {
      final job = CronJob.fromJson(cronJobRow())!;
      final form = JobFormController(repository: repository, editing: job);
      expect(form.isDirty, isFalse);
      form.draft.name = 'Renamed';
      expect(form.isDirty, isTrue);
      expect(create().isDirty, isFalse);
    });

    test('offers the server targets and a stored one that is gone', () async {
      server.on('GET', '/api/cron/delivery-targets', {
        'targets': [
          {'id': 'local', 'name': 'Local (save only)', 'home_target_set': true},
          {'id': 'discord', 'name': 'Discord', 'home_target_set': false},
        ],
      });
      final job = CronJob.fromJson(cronJobRow(deliver: 'matrix'))!;
      final form = JobFormController(repository: repository, editing: job);

      await form.loadTargets();

      expect(form.targets.map((t) => t.id), ['local', 'discord', 'matrix']);
      expect(form.selectedTarget?.name, 'matrix (unavailable)');
    });

    test('loads the targets of the job\'s profile', () async {
      server.on('GET', '/api/cron/delivery-targets', cronDeliveryTargets);
      final job = CronJob.fromJson(cronJobRow(profile: 'home'))!;

      await create().loadTargets();
      await JobFormController(
        repository: repository,
        editing: job,
      ).loadTargets();

      expect(
        server
            .requestsTo('GET', '/api/cron/delivery-targets')
            .map((r) => r.queryParameters['profile']),
        ['work', 'home'],
      );
    });

    test('drops targets a newer load overtook', () async {
      final gate = Completer<FakeResponse>();
      server
        ..onRequest(
          'GET',
          '/api/cron/delivery-targets',
          (_) => gate.future,
          query: {'profile': 'work'},
        )
        ..on(
          'GET',
          '/api/cron/delivery-targets',
          {
            'targets': [
              {'id': 'local', 'name': 'Local (save only)'},
              {'id': 'slack', 'name': 'Slack'},
            ],
          },
          query: {'profile': 'home'},
        );
      final form = create();

      final first = form.loadTargets();
      form.draft.profile = 'home';
      await form.loadTargets();
      gate.complete((
        status: 200,
        body: {
          'targets': [
            {'id': 'discord', 'name': 'Discord'},
          ],
        },
      ));
      await first;

      expect(form.targets.map((t) => t.id), ['local', 'slack']);
    });

    test('offers local only when the targets cannot be loaded', () async {
      server.on('GET', '/api/cron/delivery-targets', {}, status: 500);
      final form = create();

      await form.loadTargets();

      expect(form.targets.map((t) => t.id), ['local']);
      expect(form.targetsFailed, isTrue);
    });
  });

  group('BlueprintFormController', () {
    const blueprint = Blueprint(
      key: 'morning-brief',
      title: 'Morning briefing',
      fields: [
        BlueprintField(
          name: 'time',
          type: 'time',
          label: 'What time?',
          defaultValue: '08:00',
        ),
        BlueprintField(
          name: 'note',
          type: 'text',
          label: 'Note',
          optional: true,
        ),
      ],
    );

    BlueprintFormController form() => BlueprintFormController(
      repository: repository,
      blueprint: blueprint,
      profile: 'work',
    );

    test('starts from the defaults and creates through the server', () async {
      server.on(
        'POST',
        '/api/cron/blueprints/instantiate',
        cronJobRow(id: 'b'),
        query: {'profile': 'work'},
      );

      final job = await form().save();

      expect(job?.id, 'b');
      expect(lastBody(), {
        'blueprint': 'morning-brief',
        'values': {'time': '08:00'},
      });
    });

    test('a required slot cannot be emptied', () async {
      final f = form()..set('time', '');

      expect(await f.save(), isNull);

      expect(f.fieldErrors['time'], 'Required');
      expect(server.requests, isEmpty);
    });

    test(
      'a 422 is shown against the slot it names and the values stay',
      () async {
        server.on('POST', '/api/cron/blueprints/instantiate', {
          'detail': "invalid time '25:00' — use HH:MM (24h)",
        }, status: 422);
        final f = form()..set('time', '25:00');

        expect(await f.save(), isNull);

        expect(f.fieldErrors['time'], contains('invalid time'));
        expect(f.values['time'], '25:00');
        expect(f.error, isNull);
      },
    );

    test('a refusal that names no slot goes on the form', () async {
      server.on('POST', '/api/cron/blueprints/instantiate', {
        'detail': 'nope',
      }, status: 400);
      final f = form();

      await f.save();

      expect(f.error, 'nope');
    });
  });

  test('delivery targets arriving after dispose do not notify', () async {
    final gate = Completer<FakeResponse>();
    server.onRequest('GET', '/api/cron/delivery-targets', (_) => gate.future);
    final form = JobFormController(repository: repository, profile: 'work');
    final load = form.loadTargets();
    form.dispose();
    gate.complete((status: 200, body: {}));

    await expectLater(load, completes);
  });

  testWidgets('the form screen disposes its controller', (tester) async {
    server.on('GET', '/api/cron/delivery-targets', {});
    final form = JobFormController(repository: repository, profile: 'work');
    await tester.pumpWidget(MaterialApp(home: JobFormScreen(controller: form)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    expect(() => form.addListener(() {}), throwsFlutterError);
  });

  testWidgets('activity cancellation leaves the form open with its draft', (
    tester,
  ) async {
    final gate = Completer<FakeResponse>();
    server.onRequest('POST', '/api/cron/jobs', (_) => gate.future);
    final activity = ValueNotifier(true);
    final earlySaveCancelled = Completer<bool>();
    var targetCalls = 0;
    final resumedTargetsLoaded = Completer<void>();
    server.onRequest('GET', '/api/cron/delivery-targets', (_) {
      if (++targetCalls == 2) resumedTargetsLoaded.complete();
      return (
        status: 200,
        body: {
          'targets': [
            {'id': 'local', 'name': 'Local (save only)'},
          ],
        },
      );
    });
    late JobFormController form;
    var nestedResume = false;
    activity.addListener(() {
      if (!nestedResume && !activity.value) {
        nestedResume = true;
        form.save().then<void>(
          (_) => earlySaveCancelled.complete(false),
          onError: (Object error) =>
              earlySaveCancelled.complete(error is JobFormActivityCancelled),
        );
        activity.value = true;
      }
    });
    form =
        JobFormController(
            repository: repository,
            profile: 'work',
            activity: activity,
            now: () => DateTime(2026, 9, 20, 12),
          )
          ..draft.prompt = 'Keep this draft'
          ..draft.spec = const EverySpec(6, EveryUnit.hours);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => JobFormScreen(controller: form),
                ),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();

    activity.value = false;
    gate.complete((status: 200, body: cronJobRow(id: 'created')));
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(find.byKey(const Key('job-error')), findsNothing);
    expect(await earlySaveCancelled.future, isTrue);
    await resumedTargetsLoaded.future;
    expect(targetCalls, 2);
    expect(server.requestsTo('POST', '/api/cron/jobs'), hasLength(1));
    activity.dispose();
  });
}
