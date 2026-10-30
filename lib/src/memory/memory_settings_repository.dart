import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_api/hermes_api.dart';

import '../telemetry/telemetry.dart';
import 'memory_provider.dart';
import 'memory_repository.dart';
import 'memory_settings.dart';

/// The memory settings of a profile, its provider and its reset, on the
/// generated config and memory calls. Spans and logs carry fixed slugs and
/// outcomes only, never a profile name or a value.
class MemorySettingsRepository {
  MemorySettingsRepository(
    this._api, {
    this.telemetry = const ConnectionTelemetry(),
  });
  final DefaultApi _api;
  final ConnectionTelemetry telemetry;

  Future<MemorySettings> read(String profile) async {
    final span = _start('memory.settings.fetch');
    var outcome = 'success';
    try {
      final data = (await _api.getConfigApiConfigGet(profile: profile)).data;
      if (data is! Map) throw MemoryFailure.malformed;
      return MemorySettings.fromConfig(data);
    } on Object catch (error) {
      final failure = error is MemoryFailure ? error : MemoryFailure.transport;
      outcome = failure.name;
      throw failure;
    } finally {
      _end(span, outcome);
    }
  }

  /// Saves [value] for [setting] alone: Hermes merges the body into the
  /// saved config, so nothing else changes. Throws [MemoryWriteFailure],
  /// `uncertain` when no answer came back.
  Future<void> write(
    String profile,
    MemorySetting setting,
    Object value,
  ) async {
    final span = _start('memory.settings.write', {'key': setting.key});
    var outcome = 'saved';
    try {
      await _api.updateConfigApiConfigPut(
        profile: profile,
        configUpdate: ConfigUpdate(
          config: {
            setting.section: {setting.key: value},
          },
          profile: profile,
        ),
      );
    } on DioException catch (error) {
      final refused = error.response != null;
      outcome = refused ? 'refused' : 'failed';
      throw MemoryWriteFailure(
        !refused,
        refused
            ? 'The server rejected the change.'
            : 'The change may not have been saved.',
      );
    } finally {
      _end(span, outcome);
      _quiet(
        () => telemetry.events('memory.setting_changed', {
          'key': setting.key,
          'outcome': outcome,
        }),
      );
    }
  }

  Future<MemoryProviderStatus> status(String profile) async {
    final span = _start('memory.status.fetch');
    var outcome = 'success';
    try {
      final data = (await _api.getMemoryStatusApiMemoryGet(profile: profile))
          .data;
      final active = data is Map ? data['active'] : null;
      final providers = data is Map ? data['providers'] : null;
      if (active is! String || providers is! List) {
        throw MemoryFailure.malformed;
      }
      final status = _provider(active, providers);
      _quiet(() => span?.setAttribute('provider_status', status.state.wire));
      return status;
    } on Object catch (error) {
      final failure = error is MemoryFailure ? error : MemoryFailure.transport;
      outcome = failure.name;
      throw failure;
    } finally {
      _end(span, outcome);
    }
  }

  static MemoryProviderStatus _provider(String active, List<Object?> rows) {
    if (active.isEmpty) return MemoryProviderStatus.builtin;
    for (final row in rows) {
      if (row is! Map || row['name'] != active) continue;
      final description = row['description'];
      return MemoryProviderStatus(
        MemoryProviderState.values.firstWhere(
          (state) => state.wire == row['status'],
          orElse: () => MemoryProviderState.ready,
        ),
        name: active,
        description: description is String && description.isNotEmpty
            ? description
            : null,
      );
    }
    return MemoryProviderStatus(MemoryProviderState.ready, name: active);
  }

  /// Deletes the memory files [target] names and answers how many went. The
  /// profile always goes along, since a multi-profile server refuses a reset
  /// without one. Throws [MemoryWriteFailure], `uncertain` when the answer
  /// did not confirm it; the request is never sent again.
  Future<int> reset(String profile, MemoryResetTarget target) async {
    final span = _start('memory.reset', {'target': target.wire});
    var outcome = 'reset';
    var deleted = 0;
    try {
      final data = (await _api.resetMemoryApiMemoryResetPost(
        profile: profile,
        memoryReset: MemoryReset(target: target.wire),
      )).data;
      if (data is! Map || data['ok'] is! bool) {
        throw const MemoryWriteFailure(
          true,
          'The server did not confirm the reset.',
        );
      }
      if (data['ok'] != true) {
        throw const MemoryWriteFailure(false, 'The server refused the reset.');
      }
      final files = data['deleted'];
      return deleted = files is List ? files.length : 0;
    } on DioException catch (error) {
      final body = error.response?.data;
      final detail = body is Map ? body['detail'] : null;
      final refused = error.response != null;
      outcome = refused ? 'refused' : 'uncertain';
      throw MemoryWriteFailure(
        !refused,
        refused
            ? (detail is String ? detail : 'The server refused the reset.')
            : 'The reset may have happened.',
      );
    } on MemoryWriteFailure catch (failure) {
      outcome = failure.uncertain ? 'uncertain' : 'refused';
      rethrow;
    } finally {
      _end(span, outcome);
      _quiet(
        () => telemetry.events('memory.reset_outcome', {
          'target': target.wire,
          'outcome': outcome,
          'deleted': deleted,
        }),
      );
    }
  }

  Span? _start(String name, [Map<String, Object> attributes = const {}]) {
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        name,
        attributes: {...telemetry.serverAttributes, ...attributes},
      ),
    );
    return span;
  }

  void _end(Span? span, String outcome) => _quiet(() {
    span?.setAttribute('outcome', outcome);
    span?.end();
  });

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
