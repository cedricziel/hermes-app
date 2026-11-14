import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_api/hermes_api.dart';

import '../telemetry/telemetry.dart';
import 'provider_models.dart';
import 'provider_results.dart';

/// Reads and changes the model providers of a profile through the generated
/// [DefaultApi]. No route declares a response schema, so answers are parsed
/// by hand ([mergeProviders] for the lists).
///
/// Nothing here throws. A `DioException` is never returned, rethrown or made
/// into a string: its request holds the body, and a body can hold a key. A
/// refusal carries Hermes' own `detail` sentence when the server gave a usable
/// one, and a 422 body is never read at all, since FastAPI echoes the
/// submitted body (the key included) in it. Key arguments are plain strings
/// that no field or result keeps.
///
/// Every route that takes a profile gets `profile` explicitly (null for a
/// server without profiles); the two check routes take none. The generated
/// client puts path parameters into the URL as they are, and endpoint ids
/// keep dots and colons (`local-127.0.0.1:8283`), so they are encoded here.
///
/// `DELETE /api/credentials/pool/{provider}/{index}` is deliberately not
/// wrapped: it addresses an entry by a position that shifts when the pool
/// changes, so it cannot remove the entry the person confirmed.
class ProvidersRepository {
  ProvidersRepository(
    this._api, {
    this.telemetry = const ConnectionTelemetry(),
    this.checkBudget = const Duration(seconds: 6),
    this.recommendBudget = const Duration(seconds: 8),
  });

  final DefaultApi _api;
  final ConnectionTelemetry telemetry;

  /// How long the app waits for Hermes' key check before saving without it.
  final Duration checkBudget;

  /// How long it waits for the recommended default model.
  final Duration recommendBudget;

  // ---- reading ----

  /// The four answers (and the read-only pool) for [profile], in parallel.
  /// `GET /api/model/options` failing fails the snapshot, a 404 there is
  /// [ProvidersUnsupported]; the other sources degrade and a 404 on one reads
  /// as "not offered".
  Future<ProvidersSnapshot> load(String? profile) async {
    final span = _start('providers.load');
    final reads = await Future.wait([
      _read(
        () => _api.getModelOptionsApiModelOptionsGet(
          profile: profile,
          includeUnconfigured: true,
        ),
      ),
      _read(() => _api.getEnvVarsApiEnvGet(profile: profile)),
      _read(
        () => _api.listOauthProvidersApiProvidersOauthGet(profile: profile),
      ),
      _read(
        () => _api.listCustomEndpointsApiProvidersCustomEndpointsGet(
          profile: profile,
        ),
      ),
      _read(
        () => _api.listCredentialPoolApiCredentialsPoolGet(profile: profile),
      ),
    ]);
    final sources = {
      for (var i = 0; i < ProviderSource.values.length; i++)
        ProviderSource.values[i]: reads[i].state,
    };
    for (var i = 0; i < reads.length; i++) {
      final type = reads[i].errorType;
      if (type != null) {
        _log('providers.read_failed', {
          'source': ProviderSource.values[i].name,
          'error_type': type,
        });
      }
    }
    // Four sources count; the pool only explains a provider that stays
    // connected and is not part of the tally.
    final counted = sources.entries.where((e) => e.key != ProviderSource.pool);
    final ok = counted.where((e) => e.value is SourceOk).length;
    final failed = counted.where((e) => e.value is SourceFailed).length;
    final options = sources[ProviderSource.options]!;
    if (options is! SourceOk) {
      _end(span, {'sources_ok': ok, 'sources_failed': failed});
      return options is SourceFailed
          ? ProvidersFailed(options.reason)
          : const ProvidersUnsupported();
    }
    final catalog = mergeProviders(
      options: reads[0].data,
      env: reads[1].data,
      oauth: reads[2].data,
      endpoints: reads[3].data,
      pool: reads[4].data,
    );
    _end(span, {
      'sources_ok': ok,
      'sources_failed': failed,
      'connected': _bucket(catalog.connected.length),
    });
    return ProvidersLoaded(catalog, sources);
  }

  static String _bucket(int count) => switch (count) {
    0 => '0',
    1 => '1',
    <= 5 => '2-5',
    _ => '>5',
  };

  Future<_Read> _read(Future<Response<Object>> Function() call) async {
    try {
      final data = (await call()).data;
      return data is Map
          ? _Read(const SourceOk(), data: data)
          : const _Read(
              SourceFailed(ReadFailure.malformed),
              errorType: 'malformed',
            );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) return const _Read(SourceNotOffered());
      final restart =
          status == 503 && (_detail(e) ?? '').startsWith('Restart required');
      return _Read(
        SourceFailed(
          restart
              ? ReadFailure.restartRequired
              : status == null
              ? ReadFailure.unreachable
              : ReadFailure.server,
        ),
        errorType: e.type.name,
      );
    } on Object {
      return const _Read(
        SourceFailed(ReadFailure.malformed),
        errorType: 'malformed',
      );
    }
  }

  // ---- connecting with a key ----

  /// Asks Hermes to check [value] for the variable [keyEnv]. Writes nothing.
  /// Hermes probes a handful of providers; any other answers "cannot check".
  Future<KeyCheck> checkKey(String keyEnv, String value) async {
    try {
      final data = (await _within(
        checkBudget,
        (cancel) => _api.validateProviderCredentialApiProvidersValidatePost(
          envVarUpdate: EnvVarUpdate(
            key: keyEnv,
            value: value,
            apiKey: null,
            providerSetup: null,
          ),
          cancelToken: cancel,
        ),
      )).data;
      if (data is! Map) return const KeyUnreachable();
      if (data['ok'] == true) {
        return data['reachable'] == true
            ? const KeyAccepted()
            : const KeyUnchecked();
      }
      if (data['reachable'] != true) return const KeyUnreachable();
      final raw = data['message'];
      final message = _safe(raw, value) ?? '';
      return raw is String && raw.startsWith('Provider returned HTTP')
          ? KeyProviderError(message)
          : KeyRejected(message);
    } on DioException catch (e) {
      // An older server without the check cannot say anything about the key.
      return e.response?.statusCode == 404
          ? const KeyUnchecked()
          : const KeyUnreachable();
    } on Object {
      return const KeyUnreachable();
    }
  }

  /// Writes [value] to the variable [keyEnv] of [profile] (`PUT /api/env`
  /// with `provider_setup: true`). An answer that is lost is [KeySaveUnknown]
  /// and the request is never sent again.
  Future<KeySave> saveKey(String? profile, String keyEnv, String value) =>
      _guard(
        () => _api.setEnvVarApiEnvPut(
          envVarUpdate: EnvVarUpdate(
            key: keyEnv,
            value: value,
            apiKey: null,
            providerSetup: true,
          ),
          profile: profile,
        ),
        secret: value,
        ok: (data) => data is Map && data['ok'] == true
            ? const KeySaved()
            : data is Map
            ? const KeyRefused("Hermes didn't save the key")
            : const KeySaveUnknown(),
        failed: (f) => f.status == null || f.status! >= 500
            ? const KeySaveUnknown()
            : KeyRefused(f.message ?? "Hermes didn't save the key"),
      );

  // ---- removing ----

  /// Clears the key variable [keyEnv] of [profile] (`DELETE /api/env`).
  Future<RemoveResult> removeKey(String? profile, String keyEnv) => _guard(
    () => _api.removeEnvVarApiEnvDelete(
      envVarDelete: EnvVarDelete(key: keyEnv),
      profile: profile,
    ),
    ok: _removed,
    failed: _removalFailed,
  );

  /// Signs [providerId] out. 404 is [AlreadyGone]; 400 (Hermes cannot remove
  /// it) and 409 (nothing stored) are [RemoveRefused] with Hermes' sentence.
  Future<RemoveResult> signOut(String? profile, String providerId) => _guard(
    () => _api.disconnectOauthProviderApiProvidersOauthProviderIdDelete(
      providerId: Uri.encodeComponent(providerId),
      profile: profile,
    ),
    ok: _removed,
    failed: _removalFailed,
  );

  Future<RemoveResult> deleteEndpoint(String? profile, String endpointId) =>
      _guard(
        () => _api
            .deleteCustomEndpointApiProvidersCustomEndpointsEndpointIdDelete(
              endpointId: Uri.encodeComponent(endpointId),
              profile: profile,
            ),
        ok: _removed,
        failed: _removalFailed,
      );

  static RemoveResult _removed(Object? data) =>
      data is Map && data['ok'] == false
      ? RemoveRefused(_text(data['message']))
      : const Removed();

  static RemoveResult _removalFailed(_Failure f) {
    final status = f.status;
    if (status == 404) return const AlreadyGone();
    if (status != null && status >= 400 && status < 500) {
      return RemoveRefused(f.message);
    }
    return const RemoveUnknown();
  }

  // ---- the default model ----

  /// The model Hermes suggests as [provider]'s default, or null when it
  /// suggests none or the call fails or runs out of time. The app never falls
  /// back to the provider's first listed model.
  Future<RecommendedModel?> recommendedDefault(
    String? profile,
    String provider,
  ) async {
    try {
      final data = (await _within(
        recommendBudget,
        (cancel) =>
            _api.getRecommendedDefaultModelApiModelRecommendedDefaultGet(
              provider: provider,
              profile: profile,
              cancelToken: cancel,
            ),
      )).data;
      final model = data is Map ? _text(data['model']) : null;
      return model == null
          ? null
          : RecommendedModel(
              model,
              freeTier: (data! as Map)['free_tier'] == true,
            );
    } on Object {
      return null;
    }
  }

  /// Saves [model] as the profile's main default (`POST /api/model/set`).
  /// An expensive model answers [DefaultModelConfirmRequired] and saves
  /// nothing; send it again with [confirmExpensive] only once the person
  /// agreed.
  Future<DefaultModelResult> setDefaultModel(
    String? profile,
    String provider,
    String model, {
    bool confirmExpensive = false,
  }) => _guard(
    () => _api.setModelAssignmentApiModelSetPost(
      modelAssignment: ModelAssignment(
        scope: 'main',
        provider: provider,
        model: model,
        task: null,
        baseUrl: null,
        apiKey: null,
        confirmExpensiveModel: confirmExpensive ? true : null,
      ),
      profile: profile,
    ),
    ok: (data) {
      if (data is! Map) return const DefaultModelFailed();
      if (data['ok'] == true) return const DefaultModelSaved();
      if (data['confirm_required'] == true) {
        return DefaultModelConfirmRequired(
          _text(data['confirm_message']) ?? '',
        );
      }
      return DefaultModelRefused(_text(data['message']));
    },
    failed: (f) => f.status == null || (f.status! >= 500 && f.status != 503)
        ? const DefaultModelFailed()
        : DefaultModelRefused(f.message),
  );

  // ---- account sign-in ----

  /// Starts the device-code sign-in of [providerId] (`…/oauth/{id}/start`).
  Future<SignInStart> startSignIn(String? profile, String providerId) => _guard(
    () => _api.startOauthLoginApiProvidersOauthProviderIdStartPost(
      providerId: Uri.encodeComponent(providerId),
      profile: profile,
    ),
    serverDetail: true,
    ok: (data) {
      final map = data is Map ? data : const {};
      final id = _text(map['session_id']);
      final code = _text(map['user_code']);
      final url = _text(map['verification_url']);
      if (id == null || code == null || url == null) {
        return const SignInStartRefused(null);
      }
      return SignInStarted(
        SignInSession(
          sessionId: id,
          userCode: code,
          verificationUrl: url,
          expiresIn: _seconds(map['expires_in']) ?? 900,
          pollInterval: _seconds(map['poll_interval']) ?? 5,
        ),
      );
    },
    failed: (f) => f.status == null
        ? const SignInStartFailed()
        : SignInStartRefused(f.message),
  );

  /// One poll of a sign-in. 404 means the session is gone.
  Future<SignInPoll> pollSignIn(
    String? profile,
    String providerId,
    String sessionId,
  ) => _guard(
    () => _api.pollOauthSessionApiProvidersOauthProviderIdPollSessionIdGet(
      providerId: Uri.encodeComponent(providerId),
      sessionId: Uri.encodeComponent(sessionId),
      profile: profile,
    ),
    ok: (data) {
      if (data is! Map) return const SignInPollFailed();
      return SignInPolled(
        switch (data['status']) {
          'approved' => SignInStatus.approved,
          'denied' => SignInStatus.denied,
          'expired' => SignInStatus.expired,
          'error' => SignInStatus.error,
          'cancelled' => SignInStatus.cancelled,
          _ => SignInStatus.pending,
        },
        errorMessage: _text(data['error_message']),
        accountEmail: _text(data['account_email']),
        retryAfter: _seconds(data['retry_after']),
      );
    },
    failed: (f) =>
        f.status == 404 ? const SignInGone() : const SignInPollFailed(),
  );

  /// Stops the server's poller so a later approval saves nothing.
  Future<SignInCancel> cancelSignIn(String? profile, String sessionId) =>
      _guard(
        () => _api.cancelOauthSessionApiProvidersOauthSessionsSessionIdDelete(
          sessionId: Uri.encodeComponent(sessionId),
          profile: profile,
        ),
        ok: (data) => data is Map && data['ok'] == false
            ? SignInCancel.notFound
            : SignInCancel.cancelled,
        failed: (f) =>
            f.status == 404 ? SignInCancel.notFound : SignInCancel.failed,
      );

  // ---- custom endpoints ----

  /// Asks the server to probe [baseUrl] (no profile, nothing written). A
  /// blank [apiKey] or [apiMode] is not sent.
  Future<EndpointCheck> checkEndpoint({
    required String name,
    required String baseUrl,
    String model = '',
    String? apiKey,
    String? apiMode,
  }) => _guard(
    () => _api.validateCustomEndpointApiProvidersCustomEndpointsValidatePost(
      customEndpointUpdate: CustomEndpointUpdate(
        name: name,
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey == null || apiKey.isEmpty ? null : apiKey,
        apiMode: apiMode == null || apiMode.isEmpty ? null : apiMode,
      ),
    ),
    secret: apiKey,
    ok: (data) {
      if (data is! Map) return const EndpointCheckFailed();
      if (data['reachable'] != true) return const EndpointUnreachable();
      final message = _safe(data['message'], apiKey);
      return EndpointChecked(
        models: _strings(data['models']),
        resolvedBaseUrl: _text(data['resolved_base_url']),
        warning: data['ok'] == true ? null : message ?? '',
      );
    },
    failed: (_) => const EndpointCheckFailed(),
  );

  /// Saves an endpoint (`POST /api/providers/custom-endpoints`). Every
  /// required field is sent, `model: ""` before one is picked. [apiKey] null
  /// keeps the stored key, `""` clears it, anything else replaces it; [apiMode]
  /// null keeps a hand-written one, `""` is Automatic.
  Future<EndpointSave> saveEndpoint(
    String? profile, {
    String? id,
    required String name,
    required String baseUrl,
    String model = '',
    String? apiKey,
    String? apiMode,
    int? contextLength,
    bool? discoverModels,
    bool? makeDefault,
    List<String>? models,
  }) => _guard(
    () => _api.upsertCustomEndpointApiProvidersCustomEndpointsPost(
      customEndpointUpdate: CustomEndpointUpdate(
        id: id,
        name: name,
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
        apiMode: apiMode,
        contextLength: contextLength,
        discoverModels: discoverModels,
        makeDefault: makeDefault,
        models: models,
      ),
      profile: profile,
    ),
    secret: apiKey,
    ok: (data) {
      if (data is! Map) return const EndpointSaveUnknown();
      return data['ok'] == false
          ? const EndpointRefused("Hermes didn't save the endpoint")
          : EndpointSaved(_text(data['id']));
    },
    failed: (f) => f.status == null || f.status! >= 500
        ? const EndpointSaveUnknown()
        : EndpointRefused(f.message ?? "Hermes didn't save the endpoint"),
  );

  /// Makes [endpointId] the profile's default.
  Future<EndpointActivation> activateEndpoint(
    String? profile,
    String endpointId,
  ) => _guard(
    () => _api
        .activateCustomEndpointApiProvidersCustomEndpointsEndpointIdActivatePost(
          endpointId: Uri.encodeComponent(endpointId),
          profile: profile,
        ),
    ok: (data) => data is Map && data['ok'] == false
        ? EndpointActivationRefused(_text(data['message']))
        : const EndpointActivated(),
    failed: (f) => f.status != null && f.status! < 500
        ? EndpointActivationRefused(f.message)
        : const EndpointActivationFailed(),
  );

  // ---- plumbing ----

  /// Runs [call], mapping its answer with [ok] and every failure with
  /// [failed]. The failure keeps the status and Hermes' sentence only.
  Future<T> _guard<T>(
    Future<Response<Object>> Function() call, {
    required T Function(Object? data) ok,
    required T Function(_Failure failure) failed,
    String? secret,
    bool serverDetail = false,
  }) async {
    final Response<Object> response;
    try {
      response = await call();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      return failed(
        _Failure(
          status,
          status == 422
              ? kNotAcceptedMessage
              : _safe(_detail(e, serverDetail: serverDetail), secret),
        ),
      );
    } on Object {
      return failed(const _Failure(null, null));
    }
    try {
      return ok(response.data);
    } on Object {
      return failed(const _Failure(null, null));
    }
  }

  /// Hermes' `detail` sentence of a refusal. A 422 is never read: it echoes
  /// the body that was sent.
  static String? _detail(DioException e, {bool serverDetail = false}) {
    final status = e.response?.statusCode ?? 0;
    final readable =
        (status >= 400 && status < 500 && status != 422) ||
        status == 503 ||
        (serverDetail && status >= 500);
    if (!readable) return null;
    return switch (e.response?.data) {
      {'detail': final String detail} when detail.isNotEmpty => detail,
      _ => null,
    };
  }

  /// [text] unless it is empty, not a string, or contains [secret].
  static String? _safe(Object? text, String? secret) {
    if (text is! String || text.isEmpty) return null;
    if (secret != null && secret.isNotEmpty && text.contains(secret)) {
      return null;
    }
    return text;
  }

  Future<Response<Object>> _within(
    Duration budget,
    Future<Response<Object>> Function(CancelToken cancel) call,
  ) {
    final cancel = CancelToken();
    return call(cancel).timeout(
      budget,
      onTimeout: () {
        cancel.cancel();
        throw TimeoutException('budget');
      },
    );
  }

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int? _seconds(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.round() : null;

  static List<String> _strings(Object? value) => [
    if (value is List)
      for (final item in value)
        if (item is String && item.isNotEmpty) item,
  ];

  Span? _start(String name) {
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        name,
        attributes: telemetry.serverAttributes,
      ),
    );
    return span;
  }

  void _end(Span? span, Map<String, Object> attributes) => _quiet(() {
    for (final e in attributes.entries) {
      span?.setAttribute(e.key, e.value);
    }
    span?.end();
  });

  void _log(String name, Map<String, Object> attributes) =>
      _quiet(() => telemetry.events(name, attributes));

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}

/// A failed call reduced to what is safe to keep: the status and Hermes' own
/// sentence, or the fixed [kNotAcceptedMessage] for a 422.
class _Failure {
  const _Failure(this.status, this.message);

  /// Null when no answer came back.
  final int? status;
  final String? message;
}

class _Read {
  const _Read(this.state, {this.data, this.errorType});

  final SourceState state;
  final Object? data;

  /// Set for a failed read only: the Dio error kind or `malformed`.
  final String? errorType;
}
