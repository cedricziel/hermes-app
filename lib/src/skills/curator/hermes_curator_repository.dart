import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import '../../api/hermes_api_client.dart';
import '../../api/request_timeout.dart';
import '../../server_care/action_status.dart';
import '../../server_care/care_result.dart';
import '../../server_care/json_read.dart';
import '../../server_care/server_care_repository.dart';
import 'curator_result.dart';
import 'curator_status.dart';

/// How many lines of the action log a status read asks for (the most the
/// route gives), so the `=== curator-run started` header of a long run is
/// still in the tail.
const kCuratorStatusLines = 2000;

/// How long a curator request may go unanswered before it ends as a timeout
/// (a read) or a lost answer (a pause or a run).
const kCuratorTimeout = Duration(seconds: 10);

enum _Call { read, pause, run }

/// Reads and drives the skill curator through the generated client:
/// `GET /api/curator`, `PUT /api/curator/paused`, `POST /api/curator/run` and,
/// through the server-care path, `GET /api/actions/curator-run/status`.
///
/// Every call names its profile (a blank one sends nothing: Hermes would act
/// on its own). A call answers a [CuratorResult] and never throws; a failure
/// is a kind only, so the profile, the server's words and the address in a
/// `DioException` go no further. A pause or a run is sent once: no answer is
/// [CuratorFailure.lostAnswer], settled by reading, never by sending again.
/// The routes declare no response schema, so answers are parsed by hand.
class HermesCuratorRepository {
  HermesCuratorRepository(
    HermesApiClient client, {
    this.timeout = kCuratorTimeout,
  }) : _api = client.raw,
       _care = ServerCareRepository(client);

  final DefaultApi _api;
  final ServerCareRepository _care;
  final Duration timeout;

  /// `GET /api/curator?profile=`.
  Future<CuratorResult<CuratorStatus>> status({required String profile}) =>
      _send(
        profile,
        _Call.read,
        (name) => _api.getCuratorStatusApiCuratorGet(
          profile: name,
          extra: receiveTimeoutExtra(timeout),
        ),
        (json) => CuratorStatus.parse(json),
      );

  /// `PUT /api/curator/paused?profile=`. The value is what Hermes answers,
  /// which wins over [paused].
  Future<CuratorResult<bool>> setPaused(
    bool paused, {
    required String profile,
  }) => _send(
    profile,
    _Call.pause,
    (name) => _api.setCuratorPausedApiCuratorPausedPut(
      curatorPause: CuratorPause(paused: paused),
      profile: name,
      extra: receiveTimeoutExtra(timeout),
    ),
    (json) {
      final root = readMap(json);
      if (root == null || readBool(root['ok']) == false) return null;
      return readBool(root['paused']);
    },
  );

  /// `POST /api/curator/run?profile=`. The pass changes files on the server
  /// and Hermes does not guard a second one: call it once per confirmation.
  Future<CuratorResult<CuratorRunStarted>> run({required String profile}) =>
      _send(
        profile,
        _Call.run,
        (name) => _api.runCuratorApiCuratorRunPost(
          profile: name,
          extra: receiveTimeoutExtra(timeout),
        ),
        (json) => readBool(readMap(json)?['ok']) == true
            ? const CuratorRunStarted()
            : null,
      );

  /// `GET /api/actions/curator-run/status?lines=2000`. The log is shared by
  /// every profile of the server.
  Future<CuratorResult<ActionStatus>> runStatus() async {
    final result = await _care.actionStatus(
      CareAction.curatorRun,
      lines: kCuratorStatusLines,
      timeout: timeout,
    );
    return switch (result) {
      CareOk(:final value) => CuratorOk(value),
      CareUnsupported() => const CuratorUnsupported(),
      CareFailed(:final kind, :final timedOut) => CuratorFailed(switch (kind) {
        // A poll that left and got no answer is a read that timed out; only
        // one that never connected is offline.
        CareFailureKind.offline when timedOut => CuratorFailure.timeout,
        CareFailureKind.offline => CuratorFailure.offline,
        CareFailureKind.unauthorized => CuratorFailure.unauthorized,
        CareFailureKind.unreadable => CuratorFailure.unreadable,
        // A read that Hermes refused or failed is only a read that failed.
        CareFailureKind.refused ||
        CareFailureKind.server ||
        CareFailureKind.storeUnreadable => CuratorFailure.server,
      }),
    };
  }

  Future<CuratorResult<T>> _send<T>(
    String profile,
    _Call call,
    Future<Response<Object>> Function(String profile) send,
    T? Function(Object? json) parse,
  ) async {
    if (profile.trim().isEmpty) {
      return const CuratorFailed(CuratorFailure.refused);
    }
    final write = call != _Call.read;
    try {
      final data = (await send(profile)).data;
      // A page where JSON was expected: the route is not here (a GET falls
      // through to the single-page app). A POST or PUT is not served by that
      // fallback, so there the answer is not Hermes' and the change may have
      // happened.
      if (data is! Map && data is! List) {
        return write
            ? const CuratorFailed(CuratorFailure.lostAnswer)
            : const CuratorUnsupported();
      }
      final value = parse(data);
      if (value != null) return CuratorOk(value);
      return CuratorFailed(
        write ? CuratorFailure.lostAnswer : CuratorFailure.unreadable,
      );
    } on DioException catch (error) {
      return _failure(error, call);
    } on Object {
      // Dropped on purpose: whatever was thrown may hold the request URL.
      return CuratorFailed(
        write ? CuratorFailure.lostAnswer : CuratorFailure.unreadable,
      );
    }
  }

  static CuratorResult<T> _failure<T>(DioException error, _Call call) {
    final write = call != _Call.read;
    final status = error.response?.statusCode;
    if (status == null) {
      // Only a failure to connect proves a write was not sent.
      return CuratorFailed(switch (error.type) {
        DioExceptionType.connectionTimeout => CuratorFailure.offline,
        DioExceptionType.connectionError when error.error is SocketException =>
          CuratorFailure.offline,
        _ when write => CuratorFailure.lostAnswer,
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => CuratorFailure.timeout,
        _ => CuratorFailure.offline,
      });
    }
    final detail = readString(readMap(error.response?.data)?['detail']);
    if (status == 401 || status == 403) {
      return const CuratorFailed(CuratorFailure.unauthorized);
    }
    if (status == 404 && (detail?.startsWith(_profileGone) ?? false)) {
      return const CuratorProfileGone();
    }
    if (status == 404 || status == 405) return const CuratorUnsupported();
    if (status >= 400 && status < 500) {
      return const CuratorFailed(CuratorFailure.refused);
    }
    if (call == _Call.run) return _runFailure(status, detail);
    if (call == _Call.pause &&
        (status == 502 || status == 503 || status == 504)) {
      return const CuratorFailed(CuratorFailure.lostAnswer);
    }
    return CuratorFailed(
      status == 500 && (detail?.startsWith('Curator unavailable') ?? false)
          ? CuratorFailure.unavailable
          : CuratorFailure.server,
    );
  }

  /// A run's 5xx. Hermes wraps a failed spawn, and the 404 or 400 of a bad
  /// profile, as `500 "Failed to run curator: ..."`: those are definite, the
  /// pass did not start. Any other 5xx (a proxy's, a crash) may have followed
  /// the spawn.
  static CuratorResult<T> _runFailure<T>(int status, String? detail) {
    if (status == 500 && detail != null && detail.startsWith(_runPrefix)) {
      final rest = detail.substring(_runPrefix.length);
      if (rest.startsWith("404: $_profileGone")) {
        return const CuratorProfileGone();
      }
      return CuratorFailed(
        rest.startsWith('400:')
            ? CuratorFailure.refused
            : CuratorFailure.spawnFailed,
      );
    }
    return const CuratorFailed(CuratorFailure.lostAnswer);
  }

  static const _profileGone = "Profile '";
  static const _runPrefix = 'Failed to run curator: ';
}
