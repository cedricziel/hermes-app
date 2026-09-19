import 'package:hermes_api/hermes_api.dart';

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
  });

  final String id;
  final String name;
  final String description;
  final bool enabled;

  /// Whether every credential the platform requires is set.
  final bool configured;
  final String state;
  final String? errorMessage;
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
          ),
    ];
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await _api.updateMessagingPlatformApiMessagingPlatformsPlatformIdPut(
      platformId: id,
      messagingPlatformUpdate: MessagingPlatformUpdate(enabled: enabled),
    );
  }
}
