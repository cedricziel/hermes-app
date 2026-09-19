import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

/// One credential or setting a platform reads from its environment.
///
/// The dashboard only ever sends [redactedValue], never the value itself.
class HermesBotEnvVar {
  const HermesBotEnvVar({
    required this.key,
    required this.label,
    this.description = '',
    this.help = '',
    this.required = false,
    this.isSet = false,
    this.redactedValue,
    this.isPassword = false,
    this.advanced = false,
  });

  final String key;
  final String label;
  final String description;
  final String help;
  final bool required;
  final bool isSet;
  final String? redactedValue;
  final bool isPassword;
  final bool advanced;
}

/// A messaging platform Hermes can run as a bot (Telegram, Discord, ...).
class HermesBot {
  const HermesBot({
    required this.id,
    required this.name,
    this.description = '',
    this.enabled = false,
    this.configured = false,
    this.state = '',
    this.errorMessage,
    this.envVars = const [],
  });

  final String id;
  final String name;
  final String description;
  final bool enabled;

  /// Whether every credential the platform requires is set.
  final bool configured;
  final String state;
  final String? errorMessage;
  final List<HermesBotEnvVar> envVars;
}

/// The dashboard refused a setup value and said why. The message names the
/// key at fault, never the value.
class BotSetupRejected implements Exception {
  const BotSetupRejected(this.message);

  final String message;
}

/// Reads and toggles the dashboard's messaging platforms through the
/// generated [DefaultApi].
///
/// The route declares no response schema in the spec, so the
/// `{"platforms": [...]}` envelope is parsed by hand, skipping rows that
/// don't fit.
class HermesBotsRepository {
  HermesBotsRepository(this._api);

  final DefaultApi _api;

  Future<List<HermesBot>> load() async {
    final response = await _api.getMessagingPlatformsApiMessagingPlatformsGet();
    final rows = switch (response.data) {
      {'platforms': final List<dynamic> rows} => rows,
      _ => const <dynamic>[],
    };
    return [
      for (final row in rows.whereType<Map<String, dynamic>>())
        if (row case {'id': final String id, 'name': final String name})
          HermesBot(
            id: id,
            name: name,
            description: row['description'] as String? ?? '',
            enabled: row['enabled'] as bool? ?? false,
            configured: row['configured'] as bool? ?? false,
            state: row['state'] as String? ?? '',
            errorMessage: row['error_message'] as String?,
            envVars: _envVars(row['env_vars']),
          ),
    ];
  }

  static List<HermesBotEnvVar> _envVars(Object? rows) => [
    if (rows is List)
      for (final row in rows.whereType<Map<String, dynamic>>())
        if (row case {'key': final String key})
          HermesBotEnvVar(
            key: key,
            label: row['prompt'] as String? ?? key,
            description: row['description'] as String? ?? '',
            help: row['help'] as String? ?? '',
            required: row['required'] as bool? ?? false,
            isSet: row['is_set'] as bool? ?? false,
            redactedValue: row['redacted_value'] as String?,
            isPassword: row['is_password'] as bool? ?? false,
            advanced: row['advanced'] as bool? ?? false,
          ),
  ];

  /// Writes [env] and removes the [clear] keys, leaving the platform switched
  /// as it was. Throws [BotSetupRejected] when the dashboard refuses a value.
  Future<void> saveSetup(
    String id, {
    Map<String, String> env = const {},
    List<String> clear = const [],
  }) async {
    try {
      await _api.updateMessagingPlatformApiMessagingPlatformsPlatformIdPut(
        platformId: id,
        messagingPlatformUpdate: MessagingPlatformUpdate(
          env: env,
          clearEnv: clear,
        ),
      );
    } on DioException catch (e) {
      if (e.response case Response(
        statusCode: 400,
        data: {'detail': final String detail},
      )) {
        throw BotSetupRejected(detail);
      }
      rethrow;
    }
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await _api.updateMessagingPlatformApiMessagingPlatformsPlatformIdPut(
      platformId: id,
      messagingPlatformUpdate: MessagingPlatformUpdate(enabled: enabled),
    );
  }
}
