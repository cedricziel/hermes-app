import 'dart:async';

import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import '../api/hermes_api_client.dart';
import 'action_status.dart';
import 'care_result.dart';
import 'json_read.dart';
import 'log_line.dart';
import 'server_status.dart';
import 'update_check.dart';
import 'update_receipt.dart';
import 'usage_report.dart';

/// The detached actions whose progress `GET /api/actions/{name}/status` reports.
enum CareAction {
  hermesUpdate('hermes-update'),
  gatewayRestart('gateway-restart'),
  gatewayStart('gateway-start'),
  doctor('doctor');

  const CareAction(this.routeName);

  final String routeName;
}

/// Hermes' log files, as `GET /api/logs?file=` names them.
enum CareLogFile { agent, errors, gateway }

/// The answer to `GET /api/health`: only the fields an update run compares.
class ServerHealth {
  const ServerHealth({this.version, this.commit});

  final String? version;
  final String? commit;
}

/// The answer to a POST that starts a detached action.
class ActionStarted {
  const ActionStarted({this.name, this.pid});

  final String? name;
  final int? pid;
}

/// Reads the server-care routes through the generated client.
///
/// Every route is in the OpenAPI spec without a response schema, so the
/// generated methods return untyped JSON that is parsed leniently here. A
/// call never throws: it answers a [CareResult].
class ServerCareRepository {
  ServerCareRepository(HermesApiClient api) : _api = api.raw;

  final DefaultApi _api;

  /// `GET /api/status`, for [profile]'s gateway. The profile is always sent:
  /// without it Hermes answers for whichever profile it has active, which may
  /// not be the one the person is looking at.
  Future<CareResult<ServerStatus>> status({required String profile}) => _run(
    () => _api.getStatusApiStatusGet(profile: profile),
    ServerStatus.parse,
  );

  /// `GET /api/health`: HTTP 200 with `ok: true`. A reverse proxy's 502 or an
  /// HTML page in front of a dead backend is a failure or [CareUnsupported],
  /// never a health answer.
  Future<CareResult<ServerHealth>> health() =>
      _run(() => _api.getHealthApiHealthGet(), (json) {
        final root = readMap(json);
        if (root == null || readBool(root['ok']) != true) return null;
        return ServerHealth(
          version: readString(root['version']),
          commit: readString(root['commit']),
        );
      });

  /// `GET /api/hermes/update/check`. The update is server-wide, so no
  /// profile is sent.
  Future<CareResult<UpdateCheck>> checkUpdate({bool force = false}) => _run(
    () => _api.checkHermesUpdateApiHermesUpdateCheckGet(force: force),
    UpdateCheck.parse,
  );

  /// `POST /api/hermes/update`. Destructive: tests against a real backend
  /// never call it.
  Future<CareResult<UpdateStart>> startUpdate() =>
      _run(() => _api.updateHermesApiHermesUpdatePost(), UpdateStart.parse);

  /// `GET /api/actions/{name}/status`.
  Future<CareResult<ActionStatus>> actionStatus(
    CareAction action, {
    int lines = 200,
  }) => _run(
    () => _api.getActionStatusApiActionsNameStatusGet(
      name: action.routeName,
      lines: lines,
    ),
    ActionStatus.parse,
  );

  /// `GET /api/hermes/update/receipt`. [CareOk] with null when no update has
  /// run since receipts landed (HTTP 404 "No update receipt found…"), which is
  /// not the route being missing.
  Future<CareResult<UpdateReceiptSummary?>> updateReceipt() async {
    final result = await _run<UpdateReceiptSummary?>(
      () => _api.getUpdateReceiptApiHermesUpdateReceiptGet(),
      UpdateReceiptSummary.parse,
      noReceipt: true,
    );
    return result;
  }

  /// `POST /api/gateway/restart` for [profile]. Destructive.
  Future<CareResult<ActionStarted>> restartGateway({required String profile}) =>
      _run(
        () => _api.restartGatewayApiGatewayRestartPost(profile: profile),
        _actionStarted,
      );

  /// `POST /api/gateway/start` for [profile].
  Future<CareResult<ActionStarted>> startGateway({required String profile}) =>
      _run(
        () => _api.startGatewayApiGatewayStartPost(profile: profile),
        _actionStarted,
      );

  /// `POST /api/ops/doctor` for [profile]: the read-only check, without
  /// `--fix`.
  Future<CareResult<ActionStarted>> startDoctor({required String profile}) =>
      _run(
        () => _api.runDoctorApiOpsDoctorPost(profile: profile),
        _actionStarted,
      );

  /// `GET /api/logs`: up to [lines] entries of [file], oldest first, grouped
  /// into entries. [level] is a minimum such as `WARNING` and [search] a
  /// case-insensitive substring, both applied by the server.
  Future<CareResult<List<LogLine>>> logs({
    required String profile,
    CareLogFile file = CareLogFile.errors,
    int lines = 200,
    String? level,
    String? search,
  }) => _run(
    () => _api.getLogsApiLogsGet(
      file: file.name,
      lines: lines,
      level: level,
      search: search == null || search.isEmpty ? null : search,
      profile: profile,
    ),
    (json) {
      final root = readMap(json);
      if (root == null) return null;
      return LogLine.parseAll(readStrings(root['lines']));
    },
  );

  /// `GET /api/analytics/usage` for a window of [days] ending [today] (the
  /// server's calendar day). A 503 is [CareFailureKind.storeUnreadable].
  Future<CareResult<UsageReport>> usage({
    required String profile,
    required int days,
    required DateTime today,
  }) => _run(
    () => _api.getUsageAnalyticsApiAnalyticsUsageGet(
      days: days,
      profile: profile,
    ),
    (json) => UsageReport.parse(json, days: days, today: today),
    storeStatus: 503,
  );

  static ActionStarted? _actionStarted(Object? json) {
    final root = readMap(json);
    if (root == null || readBool(root['ok']) == false) return null;
    return ActionStarted(
      name: readString(root['name']),
      pid: readInt(root['pid']),
    );
  }

  Future<CareResult<T>> _run<T>(
    Future<Response<Object>> Function() call,
    T? Function(Object? json) parse, {
    bool noReceipt = false,
    int? storeStatus,
  }) async {
    try {
      final response = await call();
      final data = response.data;
      // A page or a proxy's error text answered where JSON was expected: the
      // route is not here.
      if (data is! Map && data is! List) return const CareUnsupported();
      final T? value;
      try {
        value = parse(data);
      } on Object {
        return const CareFailed(CareFailureKind.unreadable);
      }
      if (value == null) {
        return const CareFailed(CareFailureKind.unreadable);
      }
      return CareOk(value);
    } on DioException catch (e) {
      return _failure<T>(e, noReceipt: noReceipt, storeStatus: storeStatus);
    } on TimeoutException {
      return const CareFailed(CareFailureKind.offline);
    }
  }

  CareResult<T> _failure<T>(
    DioException e, {
    required bool noReceipt,
    int? storeStatus,
  }) {
    final status = e.response?.statusCode;
    if (status == null) return const CareFailed(CareFailureKind.offline);
    final detail = _detail(e.response?.data);
    if (status == 404 &&
        noReceipt &&
        (detail?.startsWith('No update receipt') ?? false)) {
      return CareOk<T>(null as T);
    }
    if (status == 404 || status == 405) return const CareUnsupported();
    if (status == storeStatus) {
      return const CareFailed(CareFailureKind.storeUnreadable);
    }
    if (status == 401 || status == 403) {
      return const CareFailed(CareFailureKind.unauthorized);
    }
    if (status >= 500) {
      // Hermes explains some 500s itself (a restart that needs root); those
      // are shown, not retried.
      return detail == null
          ? const CareFailed(CareFailureKind.server)
          : CareFailed(CareFailureKind.refused, message: detail);
    }
    return CareFailed(CareFailureKind.refused, message: detail);
  }

  static String? _detail(Object? data) {
    final detail = readMap(data)?['detail'];
    return detail is String && detail.isNotEmpty ? detail : null;
  }
}
