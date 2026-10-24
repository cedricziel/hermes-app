import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_api/hermes_api.dart';

import '../telemetry/telemetry.dart';
import 'memory_repository.dart';
import 'memory_settings.dart';

/// The memory settings of a profile, on the generated config calls. Spans and
/// logs carry fixed slugs and outcomes only, never a profile name or a value.
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
