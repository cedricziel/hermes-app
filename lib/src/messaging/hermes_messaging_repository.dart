import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import 'whatsapp/whatsapp_pairing.dart';
import 'whatsapp/whatsapp_pairing_parsing.dart';

/// One credential or setting a platform reads from its environment.
///
/// The dashboard only ever sends [redactedValue], never the value itself.
class HermesMessagingEnvVar {
  const HermesMessagingEnvVar({
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
class HermesMessagingPlatform {
  const HermesMessagingPlatform({
    required this.id,
    required this.name,
    this.description = '',
    this.enabled = false,
    this.configured = false,
    this.errorMessage,
    this.envVars = const [],
  });

  final String id;
  final String name;
  final String description;
  final bool enabled;

  /// Whether every credential the platform requires is set.
  final bool configured;
  final String? errorMessage;
  final List<HermesMessagingEnvVar> envVars;
}

/// The dashboard refused a setup request and said why. The message names the
/// key at fault, never the value.
class MessagingSetupRejected implements Exception {
  const MessagingSetupRejected(this.message);

  final String message;
}

/// The reason to show for a failed setup request: the dashboard's own when it
/// gave one, otherwise [fallback].
String explainSetupError(Object error, String fallback) =>
    error is MessagingSetupRejected ? error.message : fallback;

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
class HermesMessagingRepository {
  HermesMessagingRepository(this._api, {this.profile});

  final DefaultApi _api;

  /// The profile whose platforms are read and changed; the one the dashboard
  /// is scoped to when null.
  final String? profile;

  /// This repository for the platforms of [profile].
  HermesMessagingRepository forProfile(String? profile) =>
      HermesMessagingRepository(_api, profile: profile);

  Future<List<HermesMessagingPlatform>> load() async {
    final response = await _api.getMessagingPlatformsApiMessagingPlatformsGet(
      profile: profile,
    );
    final rows = switch (response.data) {
      {'platforms': final List<dynamic> rows} => rows,
      _ => const <dynamic>[],
    };
    return [
      for (final row in rows.whereType<Map<String, dynamic>>())
        if (row case {'id': final String id, 'name': final String name})
          HermesMessagingPlatform(
            id: id,
            name: name,
            description: row['description'] as String? ?? '',
            enabled: row['enabled'] as bool? ?? false,
            configured: row['configured'] as bool? ?? false,
            errorMessage: row['error_message'] as String?,
            envVars: _envVars(row['env_vars']),
          ),
    ];
  }

  static List<HermesMessagingEnvVar> _envVars(Object? rows) => [
    if (rows is List)
      for (final row in rows.whereType<Map<String, dynamic>>())
        if (row case {'key': final String key})
          HermesMessagingEnvVar(
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
  /// as it was. Throws [MessagingSetupRejected] when the dashboard refuses a value.
  Future<void> saveSetup(
    String id, {
    Map<String, String> env = const {},
    List<String> clear = const [],
  }) => _explaining(
    () => _api.updateMessagingPlatformApiMessagingPlatformsPlatformIdPut(
      platformId: id,
      profile: profile,
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
          profile: profile,
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

  /// Asks the dashboard to link a WhatsApp account for [profile] (the
  /// repository's), with the numbers allowed to talk to it in [allowedUsers]
  /// (comma-separated; left out when null). Sent once: a lost answer is a
  /// [WhatsAppPairingFailure] of kind `lostAnswer`, and starting again
  /// supersedes whatever began.
  ///
  /// Throws [WhatsAppPairingFailure], or the [DioException] of a 401.
  Future<WhatsAppPairingStart> startWhatsAppPairing({
    required WhatsAppMode mode,
    String? allowedUsers,
  }) async {
    _checkWhatsAppProfile();
    final Response<Object> response;
    try {
      response = await _api
          .startWhatsappOnboardingApiMessagingWhatsappOnboardingStartPost(
            whatsAppOnboardingStart: WhatsAppOnboardingStart(
              mode: mode.wire,
              allowedUsers: allowedUsers,
              profile: profile,
            ),
          );
    } on DioException catch (e) {
      throw whatsAppFailureFor(e, WhatsAppRoute.start) ?? e;
    }
    final data = response.data;
    final id = data is Map ? data['pairing_id'] : null;
    final snapshot = whatsAppSnapshotFrom(data);
    if (id is! String || id.isEmpty || snapshot == null) {
      throw const WhatsAppPairingFailure(WhatsAppPairingFailureKind.malformed);
    }
    return WhatsAppPairingStart(id: WhatsAppPairingId(id), snapshot: snapshot);
  }

  /// Reads one pairing. The route takes no profile. A body that names another
  /// pairing is malformed. A 410 is a state
  /// ([WhatsAppPairingExpired]), not a failure.
  ///
  /// Throws [WhatsAppPairingFailure], or the [DioException] of a 401.
  Future<WhatsAppPairingSnapshot> whatsAppPairingStatus(
    WhatsAppPairingId id,
  ) async {
    final segment = _whatsAppSegment(id);
    final Response<Object> response;
    try {
      response = await _api
          .getWhatsappOnboardingStatusApiMessagingWhatsappOnboardingPairingIdGet(
            pairingId: segment,
          );
    } on DioException catch (e) {
      if (e.response?.statusCode == 410) {
        return const WhatsAppPairingSnapshot(state: WhatsAppPairingExpired());
      }
      throw whatsAppFailureFor(e, WhatsAppRoute.status) ?? e;
    }
    final data = response.data;
    final answered = data is Map ? data['pairing_id'] : null;
    // A body about another pairing is not this one's state; never echo ids.
    if (data is Map && data.containsKey('pairing_id') && answered != id.value) {
      throw const WhatsAppPairingFailure(WhatsAppPairingFailureKind.malformed);
    }
    return whatsAppSnapshotFrom(data) ??
        (throw const WhatsAppPairingFailure(
          WhatsAppPairingFailureKind.malformed,
        ));
  }

  /// Saves the linked account's setup for the repository's profile and asks
  /// the dashboard to restart the messaging gateway. [mode] and [allowedUsers]
  /// default to what start stored (left out when null). The profile goes in
  /// the query and in the body, as the route reads either. Sent once: the
  /// record is gone after a success, so a resend would only 404; a lost answer
  /// is `lostAnswer` and the caller checks the platform list instead.
  ///
  /// Throws [WhatsAppPairingFailure], or the [DioException] of a 401.
  Future<WhatsAppApplyResult> applyWhatsAppPairing(
    WhatsAppPairingId id, {
    WhatsAppMode? mode,
    String? allowedUsers,
  }) async {
    final segment = _whatsAppSegment(id);
    _checkWhatsAppProfile();
    final Response<Object> response;
    try {
      response = await _api
          .applyWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdApplyPost(
            pairingId: segment,
            profile: profile,
            whatsAppOnboardingApply: WhatsAppOnboardingApply(
              mode: mode?.wire,
              allowedUsers: allowedUsers,
              profile: profile,
            ),
          );
    } on DioException catch (e) {
      throw whatsAppFailureFor(e, WhatsAppRoute.apply) ?? e;
    }
    return whatsAppApplyResultFrom(response.data);
  }

  /// Drops a pairing and stops its bridge. The server answers ok (200) for an
  /// unknown id and spawns nothing, so this is also the probe for "is the route
  /// there" (an old server answers 405 here: `unsupported`). A 404 counts as
  /// done. Credentials of an account that
  /// already linked stay on the server.
  ///
  /// Throws [WhatsAppPairingFailure], or the [DioException] of a 401.
  Future<void> cancelWhatsAppPairing(WhatsAppPairingId id) async {
    final segment = _whatsAppSegment(id);
    try {
      await _api
          .cancelWhatsappOnboardingApiMessagingWhatsappOnboardingPairingIdDelete(
            pairingId: segment,
          );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return;
      throw whatsAppFailureFor(e, WhatsAppRoute.cancel) ?? e;
    }
  }

  /// The generated client pastes the id into the path as it is, so an id with
  /// `/`, `?`, `#` or `..` would reach another route. Refused before anything
  /// is sent.
  static String _whatsAppSegment(WhatsAppPairingId id) {
    if (!isSafeWhatsAppToken(id.value)) {
      throw const WhatsAppPairingFailure(WhatsAppPairingFailureKind.badRequest);
    }
    return Uri.encodeComponent(id.value);
  }

  void _checkWhatsAppProfile() {
    final name = profile;
    if (name != null && !isSafeWhatsAppToken(name)) {
      throw const WhatsAppPairingFailure(WhatsAppPairingFailureKind.badRequest);
    }
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
        throw MessagingSetupRejected(detail);
      }
      rethrow;
    }
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await _api.updateMessagingPlatformApiMessagingPlatformsPlatformIdPut(
      platformId: id,
      profile: profile,
      messagingPlatformUpdate: MessagingPlatformUpdate(enabled: enabled),
    );
  }
}
