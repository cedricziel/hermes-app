import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;
import 'package:hermes_api/hermes_api.dart';

import '../telemetry/telemetry.dart';
import 'tools_models.dart';

/// Why a call to the tools routes did not give an answer.
enum ToolsFailure {
  /// The device could not reach the server; nothing was sent.
  offline,

  /// A read took too long.
  timeout,

  /// `401` or `403`: this account may not change tools here.
  unauthorized,

  /// A `5xx`, a body that did not validate (`422`) or any other status.
  server,

  /// A write was sent and its answer never came. The change may have been
  /// made: read again, never send it again.
  unknownOutcome,
}

/// The outcome of a call. Callers get one of these, never an exception.
sealed class ToolsResult<T> {
  const ToolsResult();

  /// The span and log outcome: ok, refused, failed, unknown or unsupported.
  String get outcome => switch (this) {
    ToolsOk() => 'ok',
    ToolsRefused() => 'refused',
    ToolsUnsupported() => 'unsupported',
    ToolsFailed(kind: ToolsFailure.unknownOutcome) => 'unknown',
    ToolsFailed() || ToolsProfileGone() => 'failed',
  };
}

class ToolsOk<T> extends ToolsResult<T> {
  const ToolsOk(this.value);

  final T value;
}

/// `404` or `405` on the route: the server has no such feature. Not an error.
class ToolsUnsupported<T> extends ToolsResult<T> {
  const ToolsUnsupported();
}

/// `400`: Hermes refused the value. [detail] is its own wording, shown to the
/// user and never logged.
class ToolsRefused<T> extends ToolsResult<T> {
  const ToolsRefused(this.detail);

  final String? detail;
}

/// `404` naming a profile that no longer exists. It is not "no Tools on this
/// server": the caller reads the profile list again.
class ToolsProfileGone<T> extends ToolsResult<T> {
  const ToolsProfileGone();
}

class ToolsFailed<T> extends ToolsResult<T> {
  const ToolsFailed(this.kind);

  final ToolsFailure kind;
}

/// Reads and changes the toolsets of one profile through the generated
/// [DefaultApi].
///
/// No `/api/tools/*` route declares a response schema, so the generated
/// methods return untyped JSON and [tools_models.dart] parses it leniently.
/// Every call sends [profile], in the query and in the body where the route
/// takes one, because Hermes answers for its launch profile otherwise. The
/// action status routes take none.
///
/// A key passed to [saveEnv] goes into the request body and nowhere else:
/// nothing here keeps it, logs it or puts it into a result, and a caught
/// [DioException] is mapped to a [ToolsFailure] and dropped, so no exception
/// text carries the body.
class HermesToolsRepository {
  HermesToolsRepository(
    this._api, {
    required this.profile,
    this.telemetry = const ConnectionTelemetry(),
  });

  final DefaultApi _api;

  /// The profile every call acts on.
  final String profile;
  final ConnectionTelemetry telemetry;

  /// This repository for [profile].
  HermesToolsRepository forProfile(String profile) =>
      HermesToolsRepository(_api, profile: profile, telemetry: telemetry);

  Future<ToolsResult<ToolsetList>> list() async {
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        'tools.list',
        attributes: telemetry.serverAttributes,
      ),
    );
    final result = await _call(
      () => _api.getToolsetsApiToolsToolsetsGet(profile: profile),
      ToolsetList.parse,
    );
    final skipped = switch (result) {
      ToolsOk(:final value) => value.skipped,
      _ => 0,
    };
    _noteSkipped(skipped);
    _quiet(() {
      if (result case ToolsOk(:final value)) {
        span?.setAttribute('count', value.toolsets.length);
      }
      span?.setAttribute('outcome', result.outcome);
      span?.end();
    });
    return result;
  }

  Future<ToolsResult<ToolsetConfig>> config(String name) => _call(
    () => _api.getToolsetConfigApiToolsToolsetsNameConfigGet(
      name: _segment(name),
      profile: profile,
    ),
    ToolsetConfig.parse,
  ).then((r) => _skipped(r, (v) => v.skipped));

  Future<ToolsResult<ToolsetModels>> models(String name, {String? provider}) =>
      _call(
        () => _api.getToolsetModelsApiToolsToolsetsNameModelsGet(
          name: _segment(name),
          provider: provider,
          profile: profile,
        ),
        ToolsetModels.parse,
      ).then((r) => _skipped(r, (v) => v.skipped));

  Future<ToolsResult<TerminalBackends>> terminalBackends() => _call(
    () => _api.getTerminalBackendsApiToolsTerminalBackendsGet(profile: profile),
    TerminalBackends.parse,
  ).then((r) => _skipped(r, (v) => v.skipped));

  Future<ToolsResult<ComputerUseStatus>> computerUseStatus() => _call(
    () =>
        _api.getComputerUseStatusApiToolsComputerUseStatusGet(profile: profile),
    ComputerUseStatus.parse,
  );

  /// Switches a toolset. On a lost answer the result is
  /// [ToolsFailure.unknownOutcome]: read the list again, never resend.
  Future<ToolsResult<ToolsetSwitched>> switchToolset(
    String name, {
    required bool enabled,
  }) => _call(
    () => _api.toggleToolsetApiToolsToolsetsNamePut(
      name: _segment(name),
      toolsetToggle: ToolsetToggle(enabled: enabled, profile: profile),
      profile: profile,
    ),
    (json) => ToolsetSwitched.parse(json, name: name),
    write: true,
  );

  /// Picks the provider of a toolset; [capability] (`search` or `extract`) is
  /// for `web` only.
  Future<ToolsResult<ToolsetProviderPicked>> pickProvider(
    String name,
    String provider, {
    String? capability,
  }) => _call(
    () => _api.selectToolsetProviderApiToolsToolsetsNameProviderPut(
      name: _segment(name),
      toolsetProviderSelect: ToolsetProviderSelect(
        provider: provider,
        capability: capability,
        profile: profile,
      ),
      profile: profile,
    ),
    ToolsetProviderPicked.parse,
    write: true,
  );

  /// Saves keys into the profile's `.env`. [env] maps a key name to the typed
  /// value; blank values are the caller's to leave out. The values leave in
  /// the request body only.
  Future<ToolsResult<ToolsetEnvSaved>> saveEnv(
    String name,
    Map<String, String> env,
  ) => _call(
    () => _api.saveToolsetEnvApiToolsToolsetsNameEnvPut(
      name: _segment(name),
      toolsetEnvUpdate: ToolsetEnvUpdate(env: env, profile: profile),
      profile: profile,
    ),
    ToolsetEnvSaved.parse,
    write: true,
  );

  Future<ToolsResult<void>> pickModel(
    String name,
    String model, {
    String? provider,
  }) => _call(
    () => _api.selectToolsetModelApiToolsToolsetsNameModelPut(
      name: _segment(name),
      toolsetModelSelect: ToolsetModelSelect(
        model: model,
        provider: provider,
        profile: profile,
      ),
      profile: profile,
    ),
    (_) {},
    write: true,
  );

  /// Starts a provider's install step (`hermes tools post-setup <key>`) on
  /// the server. Hermes keeps one log for the whole dashboard and does not
  /// refuse a second run; the caller runs one at a time.
  Future<ToolsResult<ToolsActionStarted>> startPostSetup(
    String name,
    String key,
  ) => _call(
    () => _api.runToolsetPostSetupApiToolsToolsetsNamePostSetupPost(
      name: _segment(name),
      toolsetPostSetup: ToolsetPostSetup(key: key, profile: profile),
      profile: profile,
    ),
    ToolsActionStarted.parse,
    write: true,
  );

  Future<ToolsResult<void>> pickTerminalBackend(String backend) => _call(
    () => _api.selectTerminalBackendApiToolsTerminalBackendPut(
      terminalBackendSelect: TerminalBackendSelect(
        backend: backend,
        profile: profile,
      ),
      profile: profile,
    ),
    (_) {},
    write: true,
  );

  /// Starts the macOS permission grant on the server's Mac.
  Future<ToolsResult<ToolsActionStarted>> grantComputerUse() => _call(
    () =>
        _api.grantComputerUsePermissionsApiToolsComputerUsePermissionsGrantPost(
          profile: profile,
        ),
    ToolsActionStarted.parse,
    write: true,
  );

  /// The log of the install step Hermes runs for `tools-post-setup`. It
  /// takes no profile: the slot is shared by the whole dashboard.
  Future<ToolsResult<ToolsActionStatus>> postSetupStatus({int lines = 200}) =>
      _actionStatus('tools-post-setup', lines);

  /// The log of the macOS permission grant.
  Future<ToolsResult<ToolsActionStatus>> grantStatus({int lines = 200}) =>
      _actionStatus('computer-use-grant', lines);

  Future<ToolsResult<ToolsActionStatus>> _actionStatus(
    String name,
    int lines,
  ) => _call(
    () => _api.getActionStatusApiActionsNameStatusGet(name: name, lines: lines),
    ToolsActionStatus.parse,
  );

  static String _segment(String name) => Uri.encodeComponent(name);

  ToolsResult<T> _skipped<T>(ToolsResult<T> result, int Function(T) count) {
    if (result case ToolsOk(:final value)) _noteSkipped(count(value));
    return result;
  }

  void _noteSkipped(int skipped) {
    if (skipped == 0) return;
    _quiet(() => telemetry.events('tools.parse_lenient', {'skipped': skipped}));
  }

  Future<ToolsResult<T>> _call<T>(
    Future<Response<Object>> Function() send,
    T Function(Object? body) parse, {
    bool write = false,
  }) async {
    try {
      final response = await send();
      return ToolsOk(parse(response.data));
    } on DioException catch (error) {
      return _failure(error, write: write);
    }
  }

  static ToolsResult<T> _failure<T>(DioException error, {required bool write}) {
    final status = error.response?.statusCode;
    if (status == null) {
      // A write that never got an answer may have been made. Only a failure
      // to connect proves nothing was sent.
      return ToolsFailed(switch (error.type) {
        DioExceptionType.connectionTimeout => ToolsFailure.offline,
        _ when write => ToolsFailure.unknownOutcome,
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => ToolsFailure.timeout,
        _ => ToolsFailure.offline,
      });
    }
    final detail = _detail(error.response?.data);
    return switch (status) {
      400 => ToolsRefused(detail),
      401 || 403 => const ToolsFailed(ToolsFailure.unauthorized),
      404 when detail != null && _profileGone.hasMatch(detail) =>
        const ToolsProfileGone(),
      404 || 405 => const ToolsUnsupported(),
      _ => const ToolsFailed(ToolsFailure.server),
    };
  }

  static final _profileGone = RegExp(
    r"^Profile '.*' does not exist",
    caseSensitive: false,
  );

  static String? _detail(Object? body) {
    if (body is Map<Object?, Object?> && body['detail'] is String) {
      final text = (body['detail'] as String).trim();
      return text.isEmpty ? null : text;
    }
    return null;
  }

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
