import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import 'hermes_skills_repository.dart';

/// What the server's security scan says may be done with a skill. Anything it
/// does not say in so many words counts as [block].
enum InstallPolicy { allow, ask, block }

class HubSkill {
  const HubSkill({
    required this.name,
    required this.identifier,
    this.description = '',
    this.source = '',
    this.trustLevel = 'community',
    this.tags = const [],
    this.category = '',
    this.installed = false,
  });

  final String name;
  final String identifier;
  final String description;
  final String source;
  final String trustLevel;
  final List<String> tags;
  final String category;
  final bool installed;

  HubSkill markInstalled(Set<String> identifiers) => HubSkill(
    name: name,
    identifier: identifier,
    description: description,
    source: source,
    trustLevel: trustLevel,
    tags: tags,
    category: category,
    installed: installed || identifiers.contains(identifier),
  );
}

class HubSource {
  const HubSource({required this.id, required this.label});

  final String id;
  final String label;
}

class HubOverview {
  const HubOverview({
    this.featured = const [],
    this.official = const [],
    this.sources = const [],
    this.installed = const {},
  });

  final List<HubSkill> featured;
  final List<HubSkill> official;
  final List<HubSource> sources;
  final Set<String> installed;
}

class HubSearchResult {
  const HubSearchResult({
    this.results = const [],
    this.timedOut = const [],
    this.installed = const {},
  });

  final List<HubSkill> results;
  final List<String> timedOut;
  final Set<String> installed;
}

class HubPreview {
  const HubPreview({required this.skillMd, this.files = const []});

  final String skillMd;
  final List<String> files;
}

class ScanFinding {
  const ScanFinding({
    required this.severity,
    required this.description,
    this.file = '',
    this.line,
  });

  final String severity;
  final String description;
  final String file;
  final int? line;
}

class HubScan {
  const HubScan({
    required this.policy,
    this.verdict = '',
    this.summary = '',
    this.policyReason = '',
    this.findings = const [],
    this.severityCounts = const {},
  });

  final InstallPolicy policy;
  final String verdict;
  final String summary;
  final String policyReason;
  final List<ScanFinding> findings;
  final Map<String, int> severityCounts;
}

/// A background job the server started, named so its log can be followed.
class StartedJob {
  const StartedJob({required this.name, this.pid});

  final String name;
  final int? pid;
}

class JobStatus {
  const JobStatus({
    required this.running,
    this.exitCode,
    this.pid,
    this.lines = const [],
  });

  final bool running;
  final int? exitCode;
  final int? pid;
  final List<String> lines;
}

/// Searches, previews, scans and installs skills from the Hermes skills hub
/// through the generated [DefaultApi].
///
/// The hub routes declare no response schema in the spec, so envelopes are
/// parsed by hand, skipping rows that don't fit. A 404 on a hub route means
/// the connected Hermes has no hub and is reported as [SkillsUnsupported].
class HermesSkillsHubRepository {
  HermesSkillsHubRepository(this._api);

  final DefaultApi _api;

  Future<HubOverview> overview({String? profile}) async {
    final official = await _hub(
      () => _api.listOfficialSkillsApiSkillsHubOfficialGet(profile: profile),
    );
    HubOverview? sources;
    try {
      sources = _sources(
        (await _api.listSkillsHubSourcesApiSkillsHubSourcesGet(
          profile: profile,
        )).data,
      );
    } on Object {
      // The catalog is still useful without the featured list.
    }
    final installed = sources?.installed ?? const <String>{};
    return HubOverview(
      featured: [
        for (final s in sources?.featured ?? const <HubSkill>[])
          s.markInstalled(installed),
      ],
      official: [
        for (final row in _rows(official.data, 'skills'))
          ?_skill(row, installed),
      ],
      sources: sources?.sources ?? const [],
      installed: installed,
    );
  }

  HubOverview _sources(Object? data) {
    final map = data is Map ? data : const {};
    final installed = _identifiers(map['installed']);
    return HubOverview(
      featured: [
        for (final row in _rows(data, 'featured')) ?_skill(row, installed),
      ],
      sources: [
        for (final row in _rows(data, 'sources'))
          if (row['id'] case final String id when id.isNotEmpty)
            HubSource(id: id, label: row['label'] as String? ?? id),
      ],
      installed: installed,
    );
  }

  Future<HubSearchResult> search(
    String query, {
    String? source,
    String? profile,
  }) async {
    final response = await _hub(
      () => _api.searchSkillsHubApiSkillsHubSearchGet(
        q: query,
        source_: source ?? 'all',
        profile: profile,
      ),
    );
    final data = response.data;
    final installed = _identifiers(data is Map ? data['installed'] : null);
    return HubSearchResult(
      results: [
        for (final row in _rows(data, 'results')) ?_skill(row, installed),
      ],
      timedOut: [
        if (data is Map && data['timed_out'] is List)
          ...(data['timed_out'] as List).whereType<String>(),
      ],
      installed: installed,
    );
  }

  Future<HubPreview> preview(String identifier, {String? profile}) async {
    final response = await _hub(
      () => _api.previewSkillHubApiSkillsHubPreviewGet(
        identifier: identifier,
        profile: profile,
      ),
    );
    final data = response.data;
    if (data is! Map || data['skill_md'] is! String) {
      throw const FormatException('preview missing');
    }
    return HubPreview(
      skillMd: data['skill_md'] as String,
      files: [
        if (data['files'] is List)
          ...(data['files'] as List).whereType<String>(),
      ],
    );
  }

  Future<HubScan> scan(String identifier, {String? profile}) async {
    final response = await _hub(
      () => _api.scanSkillHubApiSkillsHubScanGet(
        identifier: identifier,
        profile: profile,
      ),
    );
    final data = response.data;
    if (data is! Map) throw const FormatException('scan missing');
    final counts = <String, int>{
      if (data['severity_counts'] is Map)
        for (final e in (data['severity_counts'] as Map).entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toInt(),
    };
    return HubScan(
      policy: switch (data['policy']) {
        'allow' => InstallPolicy.allow,
        'ask' => InstallPolicy.ask,
        _ => InstallPolicy.block,
      },
      verdict: data['verdict'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      policyReason: data['policy_reason'] as String? ?? '',
      severityCounts: counts,
      findings: [
        for (final row in _rows(data, 'findings'))
          ScanFinding(
            severity: row['severity'] as String? ?? '',
            description:
                row['description'] as String? ??
                row['category'] as String? ??
                '',
            file: row['file'] as String? ?? '',
            line: (row['line'] as num?)?.toInt(),
          ),
      ],
    );
  }

  Future<StartedJob> install(String identifier, {String? profile}) => _start(
    () => _api.installSkillHubApiSkillsHubInstallPost(
      skillInstallRequest: SkillInstallRequest(
        identifier: identifier,
        profile: profile,
      ),
      profile: profile,
    ),
  );

  Future<StartedJob> uninstall(String name, {String? profile}) => _start(
    () => _api.uninstallSkillHubApiSkillsHubUninstallPost(
      skillUninstallRequest: SkillUninstallRequest(
        name: name,
        profile: profile,
      ),
      profile: profile,
    ),
  );

  Future<StartedJob> update({String? profile}) => _start(
    () => _api.updateSkillsHubApiSkillsHubUpdatePost(
      profile: profile,
      skillsUpdateRequest: SkillsUpdateRequest(profile: profile),
    ),
  );

  /// The state of a job the server started; null when the server does not
  /// know it (any more).
  Future<JobStatus?> status(String name) async {
    final Response<Object> response;
    try {
      response = await _api.getActionStatusApiActionsNameStatusGet(name: name);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
    final data = response.data;
    if (data is! Map) return null;
    return JobStatus(
      running: data['running'] as bool? ?? false,
      exitCode: (data['exit_code'] as num?)?.toInt(),
      pid: (data['pid'] as num?)?.toInt(),
      lines: [
        if (data['lines'] is List)
          ...(data['lines'] as List).whereType<String>(),
      ],
    );
  }

  Future<StartedJob> _start(Future<Response<Object>> Function() call) async {
    final response = await _hub(call);
    final data = response.data;
    if (data is Map && data['name'] is String) {
      return StartedJob(
        name: data['name'] as String,
        pid: (data['pid'] as num?)?.toInt(),
      );
    }
    throw const FormatException('job name missing');
  }

  Future<Response<Object>> _hub(
    Future<Response<Object>> Function() call,
  ) async {
    try {
      return await call();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 && !_isDetailed404(e.response?.data)) {
        throw const SkillsUnsupported();
      }
      final detail = switch (e.response?.data) {
        {'detail': final String d} when code != null && code < 500 => d,
        _ => null,
      };
      if (detail != null) throw SkillsRejected(detail);
      rethrow;
    }
  }

  /// A router that lacks the hub answers a bare `Not Found`; a hub that does
  /// not know the skill says so in words, and that is not "unsupported".
  bool _isDetailed404(Object? data) =>
      data is Map && data['detail'] is String && data['detail'] != 'Not Found';

  Iterable<Map<String, dynamic>> _rows(Object? data, String key) {
    final rows = data is Map ? data[key] : null;
    return rows is List ? rows.whereType<Map<String, dynamic>>() : const [];
  }

  Set<String> _identifiers(Object? installed) => switch (installed) {
    final Map m => m.keys.whereType<String>().toSet(),
    final List l => l.whereType<String>().toSet(),
    _ => const {},
  };

  HubSkill? _skill(Map<String, dynamic> row, Set<String> installed) {
    final name = row['name'];
    final identifier = row['identifier'];
    if (name is! String || name.isEmpty) return null;
    if (identifier is! String || identifier.isEmpty) return null;
    return HubSkill(
      name: name,
      identifier: identifier,
      description: row['description'] as String? ?? '',
      source: row['source'] as String? ?? '',
      trustLevel: row['trust_level'] as String? ?? 'community',
      tags: [
        if (row['tags'] is List) ...(row['tags'] as List).whereType<String>(),
      ],
      category: row['category'] as String? ?? '',
      installed: row['installed'] as bool? ?? installed.contains(identifier),
    );
  }
}
