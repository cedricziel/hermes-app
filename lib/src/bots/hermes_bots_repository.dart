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

/// The dashboard refused a setup request and said why. The message names the
/// key at fault, never the value.
class BotSetupRejected implements Exception {
  const BotSetupRejected(this.message);

  final String message;
}

/// The reason to show for a failed setup request: the dashboard's own when it
/// gave one, otherwise [fallback].
String explainSetupError(Object error, String fallback) =>
    error is BotSetupRejected ? error.message : fallback;

/// A Telegram bot the dashboard's setup service created for this user, to be
/// claimed by opening [deepLink] in Telegram.
class TelegramPairing {
  const TelegramPairing({required this.id, required this.deepLink});

  final String id;
  final String deepLink;
}

class TelegramPairingStatus {
  const TelegramPairingStatus({
    required this.ready,
    this.botUsername,
    this.ownerUserId,
  });

  /// Whether the user has claimed the bot in Telegram.
  final bool ready;
  final String? botUsername;

  /// The Telegram account that claimed it, as a numeric user id.
  final String? ownerUserId;
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
  }) => _explaining(
    () => _api.updateMessagingPlatformApiMessagingPlatformsPlatformIdPut(
      platformId: id,
      messagingPlatformUpdate: MessagingPlatformUpdate(
        env: env,
        clearEnv: clear,
      ),
    ),
  );

  /// Asks the dashboard's setup service for a Telegram bot to pair with.
  Future<TelegramPairing> startTelegramPairing() async {
    final response = await _explaining(
      () => _api.startTelegramOnboardingApiMessagingTelegramOnboardingStartPost(
        telegramOnboardingStart: TelegramOnboardingStart(),
      ),
    );
    if (response.data case {
      'pairing_id': final String id,
      'deep_link': final String deepLink,
    }) {
      return TelegramPairing(id: id, deepLink: deepLink);
    }
    throw const FormatException('Incomplete Telegram pairing response');
  }

  Future<TelegramPairingStatus> telegramPairingStatus(String id) async {
    final response = await _explaining(
      () => _api
          .getTelegramOnboardingStatusApiMessagingTelegramOnboardingPairingIdGet(
            pairingId: id,
          ),
    );
    final body = response.data is Map ? response.data! as Map : const {};
    return TelegramPairingStatus(
      ready: body['status'] == 'ready',
      botUsername: body['bot_username'] as String?,
      ownerUserId: body['owner_user_id'] as String?,
    );
  }

  /// Saves the paired bot's token and the [allowedUserIds] on the dashboard
  /// and switches Telegram on. The token itself never reaches the app.
  Future<void> applyTelegramPairing(
    String id,
    List<String> allowedUserIds,
  ) => _explaining(
    () => _api
        .applyTelegramOnboardingApiMessagingTelegramOnboardingPairingIdApplyPost(
          pairingId: id,
          telegramOnboardingApply: TelegramOnboardingApply(
            allowedUserIds: allowedUserIds,
          ),
        ),
  );

  Future<void> cancelTelegramPairing(String id) async {
    await _api
        .cancelTelegramOnboardingApiMessagingTelegramOnboardingPairingIdDelete(
          pairingId: id,
        );
  }

  /// The dashboard answers a refused request with a `detail` fit to show a
  /// user; a failure of any other kind stays a [DioException].
  static Future<T> _explaining<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.response case Response(
        statusCode: 400 || 404 || 409 || 410 || 502,
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
