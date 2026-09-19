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

  Future<ProfilesOverview> load() async {
    final list = await _api.listProfilesEndpointApiProfilesGet();
    final active = await _api.getActiveProfileEndpointApiProfilesActiveGet();
    final rows = switch (list.data) {
      {'profiles': final List<dynamic> rows} => rows,
      _ => const <dynamic>[],
    };
    final activeBody = active.data is Map ? active.data as Map : const {};
    final activeName = activeBody['active'] as String? ?? '';
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
      active: activeName,
      current: activeBody['current'] as String? ?? activeName,
    );
  }

  Future<void> setActive(String name) async {
    await _api.setActiveProfileEndpointApiProfilesActivePost(
      profileActiveUpdate: ProfileActiveUpdate(name: name),
    );
  }
}
