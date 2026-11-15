// Answers of the curator routes recorded from a throwaway Hermes d923a5eb on
// Linux (task 2.1, `scripts/install-hermes.sh` and `scripts/dev-backend.sh`,
// a state folder outside the working tree, stopped and deleted after). Shapes,
// status codes, header lines and the printed output lines are verbatim.
// Profile names (`demo-a`, `demo-b`, `demo-gone`) and skill names are
// invented, and the one server path in a message is replaced by `/srv/hermes`.
// `serveRecordedCurator` answers the routes with these on a
// [FakeHermesServer].

import '../support/fake_hermes_server.dart';

/// `GET /api/curator?profile=default` on a fresh home: never run, defaults.
const recordedCuratorNeverRun = <String, Object?>{
  'enabled': true,
  'paused': false,
  'interval_hours': 168,
  'last_run_at': null,
  'min_idle_hours': 2.0,
  'stale_after_days': 14,
  'archive_after_days': 30,
};

/// `GET /api/curator?profile=demo-a` after `PUT /api/curator/paused`.
const recordedCuratorPaused = <String, Object?>{
  'enabled': true,
  'paused': true,
  'interval_hours': 168,
  'last_run_at': null,
  'min_idle_hours': 2.0,
  'stale_after_days': 14,
  'archive_after_days': 30,
};

/// `GET /api/curator?profile=demo-b` after a pass that archived one skill.
/// `last_run_at` has an offset (`+00:00`) and microseconds.
const recordedCuratorRan = <String, Object?>{
  'enabled': true,
  'paused': false,
  'interval_hours': 168,
  'last_run_at': '2026-11-15T03:37:52.300226+00:00',
  'min_idle_hours': 2.0,
  'stale_after_days': 14,
  'archive_after_days': 30,
};

/// `GET /api/curator?profile=demo-a` after a pass ran while it was paused:
/// `hermes curator run` ignores `paused`.
const recordedCuratorPausedAfterRun = <String, Object?>{
  'enabled': true,
  'paused': true,
  'interval_hours': 168,
  'last_run_at': '2026-11-15T03:37:30.896880+00:00',
  'min_idle_hours': 2.0,
  'stale_after_days': 14,
  'archive_after_days': 30,
};

/// `GET /api/curator?profile=demo-b` with `curator.enabled: false`: the route
/// still answers 200 and keeps the last run time.
const recordedCuratorDisabled = <String, Object?>{
  'enabled': false,
  'paused': false,
  'interval_hours': 168,
  'last_run_at': '2026-11-15T03:37:52.300226+00:00',
  'min_idle_hours': 2.0,
  'stale_after_days': 14,
  'archive_after_days': 30,
};

/// `PUT /api/curator/paused` answers.
const recordedPausedOn = <String, Object?>{'ok': true, 'paused': true};
const recordedPausedOff = <String, Object?>{'ok': true, 'paused': false};

/// `POST /api/curator/run?profile=demo-a`.
const recordedRunStarted = <String, Object?>{
  'ok': true,
  'pid': 1063,
  'name': 'curator-run',
};

/// The action log's start header of the first recorded run.
const recordedRunHeader = '=== curator-run started 2026-11-15 03:37:29 ===';

/// `GET /api/actions/curator-run/status?lines=2000` before any run.
const recordedStatusNeverRun = <String, Object?>{
  'name': 'curator-run',
  'running': false,
  'exit_code': null,
  'pid': null,
  'lines': <String>[],
};

/// The same, a moment after the POST: the header and nothing else yet. Each
/// run's block starts with an empty line.
const recordedStatusRunning = <String, Object?>{
  'name': 'curator-run',
  'running': true,
  'exit_code': null,
  'pid': 1063,
  'lines': ['', recordedRunHeader],
};

const _firstRun = [
  '',
  recordedRunHeader,
  'curator: running review pass...',
  'curator: consolidation is off — running prune-only (deterministic '
      'stale/archive). Pass --consolidate or set `curator.consolidate: true` '
      'to enable the LLM merge pass.',
  'curator: auto: no changes; llm: skipped (consolidation off)',
  'auto: checked=0 stale=0 archived=0 reactivated=0',
];

const _archivingRun = [
  '',
  '=== curator-run started 2026-11-15 03:37:50 ===',
  'curator: running review pass...',
  'curator: consolidation is off — running prune-only (deterministic '
      'stale/archive). Pass --consolidate or set `curator.consolidate: true` '
      'to enable the LLM merge pass.',
  'curator: auto: 1 marked stale, 1 archived; llm: skipped (consolidation '
      'off)',
  'auto: checked=2 stale=1 archived=1 reactivated=0',
];

const _disabledRun = [
  '',
  '=== curator-run started 2026-11-15 03:38:11 ===',
  'curator: disabled via config; enable with `curator.enabled: true`',
];

const _consolidatingRun = [
  '',
  '=== curator-run started 2026-11-15 03:38:16 ===',
  'curator: running review pass...',
  'curator: snapshot created (2026-11-15T03-38-18Z)',
  'curator: auto: no changes; llm: skipped (no candidates)',
  'auto: checked=0 stale=0 archived=0 reactivated=0',
];

/// A finished prune-only pass that changed nothing.
const recordedStatusFinished = <String, Object?>{
  'name': 'curator-run',
  'running': false,
  'exit_code': 0,
  'pid': 1063,
  'lines': _firstRun,
};

/// The log after a second run: the first run's block stays above it (the log
/// is append-only and shared by every profile).
const recordedStatusArchived = <String, Object?>{
  'name': 'curator-run',
  'running': false,
  'exit_code': 0,
  'pid': 1195,
  'lines': [..._firstRun, ..._archivingRun],
};

/// A pass on a profile with `curator.enabled: false`: exit 1, no "running
/// review pass" line.
const recordedStatusDisabled = <String, Object?>{
  'name': 'curator-run',
  'running': false,
  'exit_code': 1,
  'pid': 1350,
  'lines': [..._firstRun, ..._archivingRun, ..._disabledRun],
};

/// A pass with `curator.consolidate: true` and nothing to merge: no
/// "consolidation is off" line, but a snapshot of the whole tree was made.
const recordedStatusConsolidating = <String, Object?>{
  'name': 'curator-run',
  'running': false,
  'exit_code': 0,
  'pid': 1418,
  'lines': [
    ..._firstRun,
    ..._archivingRun,
    ..._disabledRun,
    ..._consolidatingRun,
  ],
};

/// The same log after the dashboard restarted: the lines are on disk, the
/// process handle is not, so there is no exit code and no pid.
const recordedStatusAfterRestart = <String, Object?>{
  'name': 'curator-run',
  'running': false,
  'exit_code': null,
  'pid': null,
  'lines': [
    ..._firstRun,
    ..._archivingRun,
    ..._disabledRun,
    ..._consolidatingRun,
  ],
};

/// `GET /api/config?profile=` has the keys the confirmation reads, at the
/// top level (the answer holds many more).
const recordedConfigCurator = <String, Object?>{
  'curator': {
    'enabled': true,
    'interval_hours': 168,
    'min_idle_hours': 2,
    'stale_after_days': 14,
    'archive_after_days': 30,
    'consolidate': false,
    'prune_builtins': false,
    'archive_ttl_days': 0,
    'backup': {'enabled': true, 'keep': 2},
  },
};

/// One recorded error answer.
typedef RecordedError = ({int status, Object? body});

/// 404 for a profile that does not exist, on GET and PUT. The detail names
/// the profile.
const recordedProfileMissing = (
  status: 404,
  body: {'detail': "Profile 'demo-gone' does not exist."},
);

/// 400 for a name that is not a valid profile name, on GET and PUT. The
/// detail echoes the name.
const recordedProfileInvalid = (
  status: 400,
  body: {
    'detail':
        "'bad name' is not a valid profile name. Use lowercase letters, "
        "numbers, '-' or '_', starting with a letter or number, up to 64 "
        'characters (for example: bad-name). Then run `hermes profile create '
        "bad-name`.",
  },
);

/// 404 of a server with no such route (a GET).
const recordedRouteMissing404 = (
  status: 404,
  body: {'detail': 'No such API endpoint: /api/curatorx'},
);

/// 405 of a PUT or POST to a route that does not exist: the single-page
/// fallback answers GET only.
const recordedRouteMissing405 = (
  status: 405,
  body: {'detail': 'Method Not Allowed'},
);

/// 404 of the action status for a name the server does not know.
const recordedActionUnknown = (
  status: 404,
  body: {'detail': 'Unknown action: nope-run'},
);

/// 422 of a PUT without `paused`.
const recordedPauseBodyInvalid = (
  status: 422,
  body: {
    'detail': [
      {
        'type': 'missing',
        'loc': ['body', 'paused'],
        'msg': 'Field required',
        'input': <String, Object?>{},
      },
    ],
  },
);

/// 500 of a GET when the curator module cannot be imported (forced by hiding
/// it from the interpreter). Not a 404, so not "unsupported".
const recordedCuratorUnavailable = (
  status: 500,
  body: {'detail': 'Curator unavailable: blocked for the recording'},
);

/// 500 of the same PUT: a plain-text body, not JSON.
const recordedPauseUnavailable = (status: 500, body: 'Internal Server Error');

/// 400 of a run without a profile on a backend with several profiles.
const recordedRunUnnamed = (
  status: 400,
  body: {
    'detail':
        'POST /api/curator/run requires an explicit profile: this backend '
        "serves several profiles, so an unnamed target would act on the wrong "
        "profile's data.",
  },
);

/// A run for a profile deleted a moment ago answers 500, not 404.
const recordedRunProfileGone = (
  status: 500,
  body: {
    'detail': "Failed to run curator: 404: Profile 'demo-gone' does not exist.",
  },
);

/// A run for an invalid name answers 500 too, with the 400 inside.
const recordedRunProfileInvalid = (
  status: 500,
  body: {
    'detail':
        "Failed to run curator: 400: 'bad name' is not a valid profile name. "
        "Use lowercase letters, numbers, '-' or '_', starting with a letter or "
        'number, up to 64 characters (for example: bad-name). Then run '
        "`hermes profile create bad-name`.",
  },
);

/// A real spawn failure (the action log path made unwritable): 500 with the
/// exception text, which holds a server path.
const recordedRunSpawnFailed = (
  status: 500,
  body: {
    'detail':
        'Failed to run curator: [Errno 21] Is a directory: '
        "'/srv/hermes/logs/action-curator-run.log'",
  },
);

/// Serves the happy-path answers of the curator routes for any profile.
void serveRecordedCurator(
  FakeHermesServer server, {
  Object? status = recordedCuratorNeverRun,
}) {
  server
    ..on('GET', '/api/curator', status)
    ..on('PUT', '/api/curator/paused', recordedPausedOn)
    ..on('POST', '/api/curator/run', recordedRunStarted)
    ..on('GET', '/api/actions/curator-run/status', recordedStatusFinished);
}
