import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/hermes_update_run.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/update_run_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

const _key = 'hermes.server_care.update.v1.acct';

void main() {
  late FakeHermesServer server;
  late DateTime t0;
  late DateTime clock;
  late SharedPreferencesAsync prefs;

  int now() => clock.difference(t0).inSeconds;

  Map<String, dynamic> health(String commit) => {
    'ok': true,
    'version': commit == 'old' ? '0.22.2' : '0.23.0',
    'commit': commit,
  };

  Map<String, dynamic> action({bool running = false, int? exit}) => {
    'name': 'hermes-update',
    'running': running,
    'exit_code': exit,
    'lines': ['=== hermes-update started 2026-11-14 09:00:00 ==='],
  };

  HermesUpdateRun build({
    String account = 'acct',
    Future<void> Function(HermesUpdateRun run)? onDelay,
  }) {
    late final HermesUpdateRun run;
    run = HermesUpdateRun(
      repository: ServerCareRepository(server.client()),
      store: UpdateRunStore(accountKey: account, prefs: prefs),
      now: () => clock,
      delay: (d) async {
        clock = clock.add(d);
        await onDelay?.call(run);
      },
    );
    return run;
  }

  Future<UpdateRunRecord?> saved([String account = 'acct']) =>
      UpdateRunStore(accountKey: account, prefs: prefs).read();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    t0 = DateTime.utc(2026, 11, 14, 9);
    clock = t0;
    server = FakeHermesServer()
      ..on('POST', '/api/hermes/update', updateStarted())
      ..on('GET', '/api/hermes/update/receipt', receiptSuccess())
      ..onRequest(
        'GET',
        '/api/health',
        (o) => now() < 5
            ? (status: 200, body: health('old'))
            : throw DioException.connectionError(
                requestOptions: o,
                reason: 'down',
              ),
      )
      ..onRequest(
        'GET',
        '/api/actions/hermes-update/status',
        (o) => now() < 5
            ? (status: 200, body: action(running: true))
            : throw DioException.connectionError(
                requestOptions: o,
                reason: 'down',
              ),
      );
  });

  /// Runs an update that the app is killed in the middle of.
  Future<void> killedMidUpdate() async {
    final run = build(onDelay: (r) async => r.dispose());
    await run.start();
  }

  test(
    'the record is saved under the account key when the update starts',
    () async {
      await killedMidUpdate();
      final record = await saved();
      expect(record, isNotNull);
      expect(record!.actionId, 'a' * 32);
      expect(record.startedAt, t0);
      expect(record.versionBefore, '0.22.2');
      expect(record.commitBefore, 'old');
      expect(await prefs.getKeys(), {_key});
    },
  );

  test('a relaunch within an hour resumes and finishes', () async {
    await killedMidUpdate();
    clock = t0.add(const Duration(minutes: 10));
    server
      ..on('GET', '/api/health', health('new'))
      ..on('GET', '/api/actions/hermes-update/status', action());
    final run = build();
    final phases = <UpdatePhase>[];
    run.addListener(() => phases.add(run.phase));
    await run.resume();
    expect(run.phase, UpdatePhase.finished);
    expect(run.result, UpdateResult.success);
    expect(phases.first, UpdatePhase.updating);
    // Never sent again.
    expect(server.requestsTo('POST', '/api/hermes/update'), hasLength(1));
    await pumpEventQueue();
    expect(await saved(), isNull);
    run.dispose();
  });

  test('a record from an hour ago is read once and dropped', () async {
    await killedMidUpdate();
    clock = t0.add(const Duration(hours: 3));
    server
      ..on('GET', '/api/health', health('new'))
      ..on('GET', '/api/actions/hermes-update/status', action());
    final run = build();
    await run.resume();
    // The receipt names the action: its outcome is shown.
    expect(run.result, UpdateResult.success);
    expect(
      server.requestsTo('GET', '/api/hermes/update/receipt'),
      hasLength(1),
    );
    expect(
      server.requestsTo('GET', '/api/actions/hermes-update/status').length,
      1,
    );
    await pumpEventQueue();
    expect(await saved(), isNull);
    run.dispose();
  });

  test('an old record the receipt does not name is dropped silently', () async {
    await killedMidUpdate();
    clock = t0.add(const Duration(hours: 3));
    server
      ..on('GET', '/api/health', health('new'))
      ..on('GET', '/api/hermes/update/receipt', receiptSuccess(actionId: 'c'));
    final run = build();
    await run.resume();
    expect(run.phase, UpdatePhase.idle);
    expect(
      server.requestsTo('GET', '/api/hermes/update/receipt'),
      hasLength(1),
    );
    expect(await saved(), isNull);
    run.dispose();
  });

  test('sign-out and server change delete the record', () async {
    await killedMidUpdate();
    final run = build();
    await run.reset();
    expect(await saved(), isNull);
    expect(run.phase, UpdatePhase.idle);
    run.dispose();
  });

  test('another account reads nothing', () async {
    await killedMidUpdate();
    final before = server.requests.length;
    final other = build(account: 'other');
    await other.resume();
    expect(other.phase, UpdatePhase.idle);
    expect(server.requests.length, before);
    // The first account's record is untouched.
    expect(await saved(), isNotNull);
    other.dispose();
  });

  test('refused and resolved updates leave no record', () async {
    server.on('POST', '/api/hermes/update', updateRefused());
    final run = build();
    await run.start();
    await pumpEventQueue();
    expect(await saved(), isNull);
    run.dispose();
  });

  test('notBack keeps the record, Dismiss deletes it', () async {
    final run = build();
    server
      ..on('GET', '/api/health', {'x': 1}, status: 502)
      ..on('GET', '/api/actions/hermes-update/status', {'x': 1}, status: 502);
    await run.start();
    expect(run.phase, UpdatePhase.notBack);
    expect(await saved(), isNotNull);
    run.dismiss();
    await pumpEventQueue();
    expect(await saved(), isNull);
    run.dispose();
  });

  test('a record that cannot be read is no record', () async {
    await prefs.setString(_key, 'not json');
    expect(await saved(), isNull);
    await prefs.setString(_key, '{"startedAt": 5}');
    expect(await saved(), isNull);
    final run = build();
    await run.resume();
    expect(run.phase, UpdatePhase.idle);
    run.dispose();
  });

  test('the record is written before the request is sent', () async {
    UpdateRunRecord? duringPost;
    server.onRequest('POST', '/api/hermes/update', (o) async {
      duringPost = await saved();
      return (status: 200, body: updateStarted());
    });
    await killedMidUpdate();
    expect(duringPost, isNotNull);
    expect(duringPost!.actionId, isNull);
    expect(duringPost!.commitBefore, 'old');
  });

  test('a refused request leaves no record', () async {
    server.on('POST', '/api/hermes/update', {'detail': 'no'}, status: 401);
    final run = build();
    await run.start();
    await pumpEventQueue();
    expect(await saved(), isNull);
    run.dispose();
  });

  test('a record with no action id never credits an older receipt', () async {
    await UpdateRunStore(accountKey: 'acct', prefs: prefs).write(
      UpdateRunRecord(
        startedAt: t0,
        versionBefore: '0.22.2',
        commitBefore: 'old',
      ),
    );
    clock = t0.add(const Duration(minutes: 5));
    // An earlier update finished: its id, its success receipt, exit 0.
    server
      ..on('GET', '/api/health', health('old'))
      ..on('GET', '/api/actions/hermes-update/status', {
        ...action(exit: 0),
        'action_id': 'z' * 32,
      })
      ..on('GET', '/api/hermes/update/receipt', receiptSuccess(actionId: 'z'));
    final run = build();
    await run.resume();
    expect(run.result, isNull);
    expect(run.phase, UpdatePhase.idle);
    expect(await saved(), isNull);
    run.dispose();
  });

  test('a resumed run says so', () async {
    await killedMidUpdate();
    clock = t0.add(const Duration(minutes: 10));
    server
      ..on('GET', '/api/health', health('new'))
      ..on('GET', '/api/actions/hermes-update/status', action());
    final run = build();
    expect(run.resumedAfterLaunch, isFalse);
    await run.resume();
    expect(run.resumedAfterLaunch, isTrue);
    run.dispose();
    final fresh = build();
    await fresh.start();
    expect(fresh.resumedAfterLaunch, isFalse);
    fresh.dispose();
  });
}
