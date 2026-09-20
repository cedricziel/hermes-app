import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

/// Where a skill came from, which decides what the app lets the user do to it.
enum SkillSource { hub, bundled, agent }

class HermesSkill {
  const HermesSkill({
    required this.name,
    this.description = '',
    this.category = '',
    this.enabled = true,
    this.usage = 0,
    this.source = SkillSource.bundled,
  });

  final String name;
  final String description;
  final String category;
  final bool enabled;
  final int usage;
  final SkillSource source;

  bool get editable => source == SkillSource.agent;

  HermesSkill copyWith({bool? enabled}) => HermesSkill(
    name: name,
    description: description,
    category: category,
    enabled: enabled ?? this.enabled,
    usage: usage,
    source: source,
  );
}

/// The dashboard refused a write and said why in words fit for the user.
class SkillsRejected implements Exception {
  const SkillsRejected(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The connected Hermes has no skills routes.
class SkillsUnsupported implements Exception {
  const SkillsUnsupported();
}

/// Reads and changes the skills of a profile through the generated
/// [DefaultApi].
///
/// The skills routes declare no response schema in the spec, so rows and
/// envelopes are parsed by hand, skipping rows that don't fit.
class HermesSkillsRepository {
  HermesSkillsRepository(this._api);

  final DefaultApi _api;

  Future<List<HermesSkill>> list({String? profile}) async {
    final Response<Object> response;
    try {
      response = await _api.getSkillsApiSkillsGet(profile: profile);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw const SkillsUnsupported();
      rethrow;
    }
    final rows = response.data is List ? response.data as List : const [];
    return [
      for (final row in rows.whereType<Map<String, dynamic>>())
        if (row['name'] case final String name when name.isNotEmpty)
          HermesSkill(
            name: name,
            description: row['description'] as String? ?? '',
            category: row['category'] as String? ?? '',
            enabled: row['enabled'] as bool? ?? true,
            usage: (row['usage'] as num?)?.toInt() ?? 0,
            source: switch (row['provenance']) {
              'hub' => SkillSource.hub,
              'agent' => SkillSource.agent,
              _ => SkillSource.bundled,
            },
          ),
    ];
  }

  Future<String> content(String name, {String? profile}) async {
    final response = await _api.getSkillContentApiSkillsContentGet(
      name: name,
      profile: profile,
    );
    return switch (response.data) {
      {'content': final String content} => content,
      _ => throw const FormatException('skill content missing'),
    };
  }

  Future<void> setEnabled(String name, bool enabled, {String? profile}) async {
    await _api.toggleSkillApiSkillsTogglePut(
      skillToggle: SkillToggle(name: name, enabled: enabled, profile: profile),
    );
  }

  Future<void> save(String name, String content, {String? profile}) => _writing(
    () => _api.updateSkillContentApiSkillsContentPut(
      skillContentUpdate: SkillContentUpdate(
        name: name,
        content: content,
        profile: profile,
      ),
    ),
  );

  Future<void> create(
    String name,
    String content, {
    String? category,
    String? profile,
  }) => _writing(
    () => _api.createSkillApiSkillsPost(
      skillCreate: SkillCreate(
        name: name,
        content: content,
        category: category == null || category.isEmpty ? null : category,
        profile: profile,
      ),
    ),
  );

  /// The dashboard answers a refused write with a `detail` fit to show a
  /// user; a failure of any other kind stays a [DioException].
  Future<void> _writing(Future<Object?> Function() call) async {
    try {
      await call();
    } on DioException catch (e) {
      final detail = switch (e.response) {
        Response(statusCode: final int code, data: {'detail': final String d})
            when code >= 400 && code < 500 =>
          d,
        _ => null,
      };
      if (detail != null) throw SkillsRejected(detail);
      rethrow;
    }
  }
}
