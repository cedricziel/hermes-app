import 'package:hermes_api/hermes_api.dart';

class HermesProfile {
  const HermesProfile({
    required this.name,
    this.displayName = '',
    this.description = '',
    this.model,
    this.provider,
    this.isDefault = false,
    this.skillCount = 0,
    this.gatewayRunning = false,
  });

  final String name;
  final String displayName;
  final String description;
  final String? model;
  final String? provider;
  final bool isDefault;
  final int skillCount;
  final bool gatewayRunning;

  String get label => displayName.isNotEmpty ? displayName : name;
}

class ProfilesOverview {
  const ProfilesOverview({
    required this.profiles,
    required this.active,
    required this.current,
  });

  final List<HermesProfile> profiles;

  /// The sticky default that new CLI invocations pick up.
  final String active;

  /// The profile the running dashboard is scoped to.
  final String current;
}

/// Reads and switches Hermes profiles through the generated [DefaultApi].
///
/// The profile routes declare no response schema in the spec, so the
/// envelopes (`{"profiles": [...]}`, `{"active", "current"}`) are parsed by
/// hand, skipping rows that don't fit.
class HermesProfilesRepository {
  HermesProfilesRepository(this._api);

  final DefaultApi _api;

  Future<({String active, String current})> loadActive() async {
    final response = await _api.getActiveProfileEndpointApiProfilesActiveGet();
    final body = response.data is Map ? response.data as Map : const {};
    final active = body['active'] as String? ?? '';
    return (active: active, current: body['current'] as String? ?? active);
  }

  Future<ProfilesOverview> load() async {
    final list = await _api.listProfilesEndpointApiProfilesGet();
    final (:active, :current) = await loadActive();
    final rows = switch (list.data) {
      {'profiles': final List<dynamic> rows} => rows,
      _ => const <dynamic>[],
    };
    return ProfilesOverview(
      profiles: [
        for (final row in rows.whereType<Map<String, dynamic>>())
          if (row['name'] case final String name when name.isNotEmpty)
            HermesProfile(
              name: name,
              displayName: row['display_name'] as String? ?? '',
              description: row['description'] as String? ?? '',
              model: row['model'] as String?,
              provider: row['provider'] as String?,
              isDefault: row['is_default'] as bool? ?? false,
              skillCount: (row['skill_count'] as num?)?.toInt() ?? 0,
              gatewayRunning: row['gateway_running'] as bool? ?? false,
            ),
      ],
      active: active,
      current: current,
    );
  }

  Future<void> setActive(String name) async {
    await _api.setActiveProfileEndpointApiProfilesActivePost(
      profileActiveUpdate: ProfileActiveUpdate(name: name),
    );
  }
}
