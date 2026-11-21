import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/curator/curator_config.dart';
import 'package:hermes_app/src/skills/curator/curator_controller.dart';
import 'package:hermes_app/src/skills/curator/curator_section_adapter.dart';
import 'package:hermes_app/src/skills/curator/curator_status.dart';
import 'package:hermes_app/src/skills/curator/hermes_curator_repository.dart';
import 'package:hermes_app/src/skills/widgets/curator_section.dart';

import '../support/fake_hermes_server.dart';
import 'curator_fixtures.dart';

/// The adapter that turns a [CuratorController] into the section's model: the
/// enums map one to one, and nothing is decided here.
void main() {
  group('enums', () {
    test('every load state has a view of the same name', () {
      for (final load in CuratorLoad.values) {
        if (load == CuratorLoad.unsupported) continue; // hides the section
        expect(curatorLoadView(load).name, load.name);
      }
      expect(CuratorLoad.values.map((l) => l.name), contains('lost'));
    });

    test('every pause state has a view of the same name', () {
      for (final pause in CuratorPause.values) {
        expect(curatorPauseView(pause).name, pause.name);
      }
    });

    test('every run phase has a view of the same name', () {
      for (final phase in CuratorRunPhase.values) {
        expect(curatorRunView(phase).name, phase.name);
      }
      expect(
        CuratorRunView.values.map((v) => v.name),
        containsAll(CuratorRunPhase.values.map((p) => p.name)),
      );
    });

    test('every reason a run did not start has a view', () {
      for (final why in CuratorNotStarted.values) {
        expect(curatorNotStartedView(why).name, why.name);
      }
    });

    test('a status maps every field, unknown ones stay unknown', () {
      final view = curatorStatusView(
        CuratorStatus(
          enabled: false,
          paused: true,
          intervalHours: 24,
          lastRun: CuratorLastRun.at,
          lastRunAt: DateTime.utc(2026, 11, 12, 9),
          staleAfterDays: 14,
          archiveAfterDays: 30,
        ),
      );
      expect(view.enabled, isFalse);
      expect(view.paused, isTrue);
      expect(view.intervalHours, 24);
      expect(view.lastRun, CuratorLastRunView.at);
      expect(view.lastRunAt, DateTime.utc(2026, 11, 12, 9));
      expect(view.staleAfterDays, 14);
      expect(view.archiveAfterDays, 30);

      final unknown = curatorStatusView(const CuratorStatus());
      expect(unknown.enabled, isNull);
      expect(unknown.intervalHours, isNull);
      expect(unknown.lastRun, CuratorLastRunView.unknown);
      expect(unknown.isOn, isTrue, reason: 'unknown counts as on');
      expect(
        curatorStatusView(const CuratorStatus(lastRun: CuratorLastRun.never))
            .lastRun,
        CuratorLastRunView.never,
      );
    });
  });

  group('a controller', () {
    late FakeHermesServer server;

    CuratorController build() => CuratorController(
      repository: HermesCuratorRepository(
        server.client(),
        timeout: const Duration(seconds: 5),
      ),
      readConfig: CuratorConfigReader(server.client()).call,
      profile: 'demo-a',
      delay: (_) async {},
    );

    Future<CuratorController> opened() async {
      final c = build()..start();
      addTearDown(c.dispose);
      for (var i = 0; i < 400; i++) {
        if (c.phase != CuratorRunPhase.opening &&
            c.load != CuratorLoad.loading) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }
      return c;
    }

    setUp(() {
      server = FakeHermesServer();
      serveRecordedCurator(server, status: recordedCuratorRan);
      server.on('GET', '/api/config', recordedConfigCurator);
    });

    test('loaded and idle: Run now is on, nothing is blanked', () async {
      final c = await opened();
      final model = curatorSectionModel(c);

      expect(model.load, CuratorLoadView.loaded);
      expect(model.run, CuratorRunView.idle);
      expect(model.canRunNow, isTrue);
      expect(model.canCheck, isFalse);
      expect(model.status?.lastRun, CuratorLastRunView.at);
      expect(model.paused, isFalse);
      expect(model.outputLines, isEmpty);
      expect(model.hasOutput, isFalse);
      expect(model.outputBlanked, isFalse);
      expect(model.outputDropped, isFalse);
      // Hermes' own words never reach the view.
      expect(model.failureLine, isNull);
      expect(model.notStartedDetail, isNull);
      expect(model.pauseDetail, isNull);
    });

    test('a status read with no answer is the lost view', () async {
      server.onRequest(
        'GET',
        '/api/curator',
        (r) => throw DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      final model = curatorSectionModel(await opened());

      expect(model.load, CuratorLoadView.lost);
      expect(model.status, isNull);
      expect(model.canRunNow, isFalse);
    });

    test('profile gone, unavailable and offline keep their views', () async {
      server.on(
        'GET',
        '/api/curator',
        recordedProfileMissing.body,
        status: recordedProfileMissing.status,
      );
      expect(
        curatorSectionModel(await opened()).load,
        CuratorLoadView.profileGone,
      );
      server.on(
        'GET',
        '/api/curator',
        recordedCuratorUnavailable.body,
        status: recordedCuratorUnavailable.status,
      );
      expect(
        curatorSectionModel(await opened()).load,
        CuratorLoadView.unavailable,
      );
    });

    test(
      'a finished pass shows its lines and blanks them under lock',
      () async {
        // The log on open and just before the POST, then the finished pass.
        final answers = [
          recordedStatusFinished,
          recordedStatusFinished,
          recordedStatusArchived,
        ];
        var read = 0;
        server.onRequest(
          'GET',
          '/api/actions/curator-run/status',
          (_) => (status: 200, body: answers[read < 2 ? read++ : 2]),
        );
        final c = await opened();
        c.beginRun();
        await c.confirmRun();
        for (var i = 0; i < 200 && c.phase != CuratorRunPhase.finished; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(curatorSectionModel(c).run, CuratorRunView.finished);
        expect(curatorSectionModel(c).outputLines, isNotEmpty);

        c.setInactive(true);
        var model = curatorSectionModel(c);
        expect(model.outputLines, isEmpty);
        expect(model.outputBlanked, isTrue);
        expect(model.hasOutput, isTrue, reason: 'hidden, not gone');
        expect(model.outputDropped, isFalse);

        c.setInactive(false);
        c.lock();
        model = curatorSectionModel(c);
        expect(model.outputLines, isEmpty);
        expect(model.outputBlanked, isTrue);
        expect(model.outputDropped, isTrue);
        expect(model.hasOutput, isFalse);
      },
    );

    test(
      'the confirmation reads days from the status, flags from config',
      () async {
        final c = await opened();
        c.beginRun();
        var model = curatorConfirmationModel(c);
        expect(model.staleAfterDays, 14);
        expect(model.archiveAfterDays, 30);
        expect(model.consolidate, isNull, reason: 'not read yet');
        for (var i = 0; i < 200 && c.confirmation?.consolidate == null; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        model = curatorConfirmationModel(c);
        expect(model.consolidate, isFalse);
        expect(model.pruneBuiltins, isFalse);
      },
    );
  });
}
