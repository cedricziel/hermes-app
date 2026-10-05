import '../chat/gateway/gateway_rpc_client.dart';

typedef BotModeRequest = Future<Map<String, Object?>> Function(
  String method,
  Map<String, Object?> params,
);

/// A profile-backed specialist. The identity is server plus profile, never
/// the optional friendly title or the last session shown in the roster.
class BotModeBot {
  const BotModeBot({
    required this.serverId,
    required this.name,
    required this.revision,
    this.displayName = '',
    this.description = '',
    this.model,
    this.provider,
    this.metadata = const {},
    this.canonicalSessionId,
    this.preview,
  });

  final String serverId;
  final String name;
  final int revision;
  final String displayName;
  final String description;
  final String? model;
  final String? provider;
  final Map<String, Object?> metadata;
  final String? canonicalSessionId;
  final String? preview;

  String get title =>
      _nonEmpty(metadata['title']) ??
      (displayName.isNotEmpty ? displayName : name);

  String get identity => '$serverId/$name';
}

class BotModeRoster {
  const BotModeRoster({
    required this.supported,
    this.bots = const [],
    this.availableProfiles = const [],
  });

  final bool supported;
  final List<BotModeBot> bots;
  final List<BotModeBot> availableProfiles;
}

class BotModeSaveResult {
  const BotModeSaveResult(
    this.applied, {
    this.conflict = false,
    this.confirmRequired = false,
    this.confirmMessage,
  });

  final Map<String, bool> applied;
  final bool conflict;
  final bool confirmRequired;
  final String? confirmMessage;

  bool get succeeded =>
      !conflict && !confirmRequired && applied.values.every((value) => value);
  List<String> get failedSections => [
    for (final entry in applied.entries)
      if (!entry.value) entry.key,
  ];
}

class BotModeCreation {
  const BotModeCreation(this.name, this.mirrored);
  final String name;
  final Map<String, Object?> mirrored;
}

class BotModeDetails {
  const BotModeDetails({
    required this.name,
    required this.description,
    required this.soul,
    this.model,
    this.provider,
  });
  final String name;
  final String description;
  final String soul;
  final String? model;
  final String? provider;
}

/// Uses the authenticated gateway owned by the app. This repository never
/// opens another socket or stores provider credentials.
class BotModeRosterRepository {
  BotModeRosterRepository(this._request, {required this.serverId});

  final BotModeRequest _request;
  final String serverId;

  Future<BotModeRoster> load() async {
    final Map<String, Object?> response;
    try {
      response = await _request('profiles.list', const {
        'include_sessions': true,
      });
    } on GatewayRpcException catch (error) {
      if (error.code == kGatewayMethodNotFound) {
        return const BotModeRoster(supported: false);
      }
      rethrow;
    }
    final rows = response['profiles'];
    if (response['bot_mode_protocol'] != true || rows is! List) {
      return const BotModeRoster(supported: false);
    }
    final bots = <BotModeBot>[];
    final available = <BotModeBot>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final name = _nonEmpty(row['name']);
      if (name == null) continue;
      final revisions = _stringMap(row['ui_meta_revisions']);
      if (revisions == null) return const BotModeRoster(supported: false);
      final rawRevision = revisions['hermes-bots'];
      if (rawRevision != null && (rawRevision is! int || rawRevision < 0)) {
        return const BotModeRoster(supported: false);
      }
      final uiMeta = _stringMap(row['ui_meta']);
      final metadata = _stringMap(uiMeta?['hermes-bots']);
      final canonical = _stringMap(row['canonical_session']);
      final bot = BotModeBot(
        serverId: serverId,
        name: name,
        revision: rawRevision as int? ?? 0,
        displayName: _nonEmpty(row['display_name']) ?? '',
        description: row['description'] is String
            ? row['description'] as String
            : '',
        model: _nonEmpty(row['model']),
        provider: _nonEmpty(row['provider']),
        metadata: metadata ?? const {},
        canonicalSessionId: _nonEmpty(canonical?['id']),
        preview: _nonEmpty(canonical?['preview']),
      );
      (metadata == null ? available : bots).add(bot);
    }
    return BotModeRoster(
      supported: true,
      bots: bots,
      availableProfiles: available,
    );
  }

  Future<BotModeDetails> describe(String name) async {
    final response = await _request('profiles.describe', {'name': name});
    final model = _stringMap(response['model']);
    return BotModeDetails(
      name: _nonEmpty(response['name']) ?? name,
      description: response['description'] is String
          ? response['description'] as String
          : '',
      soul: response['soul'] is String ? response['soul'] as String : '',
      model: _nonEmpty(model?['default']),
      provider: _nonEmpty(model?['provider']),
    );
  }

  Future<BotModeCreation> create({
    required String name,
    String description = '',
    String? soul,
    String? model,
    String? provider,
    required bool mirrorCredentials,
  }) async {
    final response = await _request('profiles.create', {
      'name': name.trim(),
      'description': description,
      'soul': ?soul,
      'model': ?model,
      'provider': ?provider,
      'mirror_credentials': mirrorCredentials,
      'clone_channels': false,
    });
    if (response['ok'] != true || response['name'] != name.trim()) {
      throw StateError('The server did not confirm profile creation');
    }
    return BotModeCreation(
      name.trim(),
      _stringMap(response['mirrored']) ?? const {},
    );
  }

  /// Patches only requested sections. For presentation metadata the entire
  /// existing hermes-bots object is carried forward with a revision CAS.
  Future<BotModeSaveResult> save(
    BotModeBot bot, {
    String? title,
    String? summary,
    String? description,
    String? soul,
    String? model,
    String? provider,
    bool confirmExpensiveModel = false,
  }) async {
    final params = <String, Object?>{'name': bot.name};
    final requested = <String>[];
    if (title != null || summary != null) {
      params['ui_meta'] = {
        'hermes-bots': {
          ...bot.metadata,
          'title': ?title,
          'description': ?summary,
        },
      };
      params['ui_meta_expected_revisions'] = {'hermes-bots': bot.revision};
      requested.add('ui_meta');
    }
    if (description != null) {
      params['description'] = description;
      requested.add('description');
    }
    if (soul != null) {
      params['soul'] = soul;
      requested.add('soul');
    }
    if (model != null && provider != null) {
      params['model'] = model;
      params['provider'] = provider;
      params['confirm_expensive_model'] = confirmExpensiveModel;
      requested.add('model');
    }
    final response = await _request('profiles.configure', params);
    final rawApplied = _stringMap(response['applied']) ?? const {};
    return BotModeSaveResult(
      {for (final section in requested) section: rawApplied[section] == true},
      conflict:
          _stringMap(rawApplied['ui_meta_conflicts'])?.isNotEmpty ?? false,
      confirmRequired: response['confirm_required'] == true,
      confirmMessage: _nonEmpty(response['confirm_message']),
    );
  }
}

String? _nonEmpty(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

Map<String, Object?>? _stringMap(Object? value) {
  if (value is! Map) return null;
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}
