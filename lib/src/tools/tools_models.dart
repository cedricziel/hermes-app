/// What Hermes answers about a profile's toolsets, parsed leniently.
///
/// None of the `/api/tools/*` routes declares a response schema, so every
/// parser here reads untyped JSON: a row that does not fit is skipped and
/// counted, a flag that is not a boolean is false, and nothing throws on
/// input of the wrong shape. Text from Hermes (`label`, `description`,
/// `prompt`, `detail`, log lines) is kept as given; it is shown to the user
/// and never logged.
library;

String? _text(Object? value) => value is String ? value : null;

bool _flag(Object? value) => value is bool && value;

bool? _tri(Object? value) => value is bool ? value : null;

List<String> _strings(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is String) item,
      ]
    : const [];

Iterable<Map<String, Object?>> _maps(Object? value) => value is List
    ? value.whereType<Map<Object?, Object?>>().map(
        (row) => row.map((k, v) => MapEntry('$k', v)),
      )
    : const [];

/// One toolset of a profile. `available` is a copy of `enabled` on the
/// server, so it is deliberately not read.
class Toolset {
  const Toolset({
    required this.name,
    required this.label,
    required this.description,
    required this.platform,
    required this.enabled,
    required this.configured,
    required this.tools,
  });

  final String name;
  final String label;

  /// Usually a list of tool names, sometimes a sentence.
  final String description;

  /// The platform list the switch writes: `cli` for nearly everything.
  final String platform;
  final bool enabled;

  /// False when no provider of the toolset has what it needs.
  final bool configured;
  final List<String> tools;

  static Toolset? tryParse(Object? row) {
    if (row is! Map<Object?, Object?>) return null;
    final name = row['name'];
    if (name is! String || name.isEmpty) return null;
    final label = _text(row['label']);
    final platform = _text(row['platform']);
    return Toolset(
      name: name,
      label: label == null || label.isEmpty ? name : label,
      description: _text(row['description']) ?? '',
      platform: platform == null || platform.isEmpty ? 'cli' : platform,
      enabled: _flag(row['enabled']),
      configured: _flag(row['configured']),
      tools: _strings(row['tools']),
    );
  }

  Toolset copyWith({bool? enabled, bool? configured}) => Toolset(
    name: name,
    label: label,
    description: description,
    platform: platform,
    enabled: enabled ?? this.enabled,
    configured: configured ?? this.configured,
    tools: tools,
  );
}

/// The list route's answer: the rows that fit, and how many did not.
class ToolsetList {
  const ToolsetList(this.toolsets, {this.skipped = 0});

  factory ToolsetList.parse(Object? json) {
    if (json is! List) return const ToolsetList([]);
    final rows = <Toolset>[];
    var skipped = 0;
    for (final row in json) {
      final parsed = Toolset.tryParse(row);
      if (parsed == null) {
        skipped++;
      } else {
        rows.add(parsed);
      }
    }
    return ToolsetList(List.unmodifiable(rows), skipped: skipped);
  }

  final List<Toolset> toolsets;
  final int skipped;
}

/// Whether a provider can work now. An unknown value from a newer server is
/// [needsSetup]: shown plainly, never as ready.
enum ToolsetProviderStatus {
  ready,
  needsKeys,
  needsAuth,
  needsSetup;

  static ToolsetProviderStatus parse(Object? value) => switch (value) {
    'ready' => ready,
    'needs_keys' => needsKeys,
    'needs_auth' => needsAuth,
    _ => needsSetup,
  };
}

/// A key a provider needs. Only whether it is set is known: the server never
/// returns a value.
class ToolsetEnvVar {
  const ToolsetEnvVar({
    required this.key,
    required this.prompt,
    required this.isSet,
    this.url,
  });

  final String key;

  /// Hermes' label for the key; the key itself when it gave none.
  final String prompt;
  final String? url;
  final bool isSet;
}

class ToolsetProvider {
  const ToolsetProvider({
    required this.name,
    required this.status,
    required this.isActive,
    this.badge,
    this.tag,
    this.envVars = const [],
    this.postSetup,
    this.requiresNousAuth = false,
    this.capabilities = const [],
    this.webBackend,
  });

  final String name;
  final ToolsetProviderStatus status;
  final bool isActive;
  final String? badge;
  final String? tag;
  final List<ToolsetEnvVar> envVars;

  /// The install step's key (`hermes tools post-setup <key>`), if it has one.
  final String? postSetup;
  final bool requiresNousAuth;

  /// `search` and `extract` for a `web` provider, else empty.
  final List<String> capabilities;
  final String? webBackend;

  static ToolsetProvider? tryParse(Object? row) {
    if (row is! Map<Object?, Object?>) return null;
    final name = row['name'];
    if (name is! String || name.isEmpty) return null;
    final postSetup = _text(row['post_setup']);
    return ToolsetProvider(
      name: name,
      status: ToolsetProviderStatus.parse(row['status']),
      isActive: _flag(row['is_active']),
      badge: _text(row['badge']),
      tag: _text(row['tag']),
      envVars: [
        for (final env in _maps(row['env_vars']))
          if (env['key'] case final String key when key.isNotEmpty)
            ToolsetEnvVar(
              key: key,
              prompt: switch (_text(env['prompt'])) {
                final prompt? when prompt.isNotEmpty => prompt,
                _ => key,
              },
              url: _text(env['url']),
              isSet: _flag(env['is_set']),
            ),
      ],
      postSetup: postSetup == null || postSetup.isEmpty ? null : postSetup,
      requiresNousAuth: _flag(row['requires_nous_auth']),
      capabilities: _strings(row['capabilities']),
      webBackend: _text(row['web_backend']),
    );
  }
}

/// A toolset's provider matrix (`GET …/config`).
class ToolsetConfig {
  const ToolsetConfig({
    required this.name,
    required this.hasCategory,
    this.activeProvider,
    this.providers = const [],
    this.skipped = 0,
    this.activeSearchBackend,
    this.activeExtractBackend,
    this.searchViaNous = false,
    this.extractViaNous = false,
  });

  factory ToolsetConfig.parse(Object? json) {
    final map = json is Map<Object?, Object?> ? json : const {};
    final providers = <ToolsetProvider>[];
    var skipped = 0;
    final rows = map['providers'];
    if (rows is List) {
      for (final row in rows) {
        final parsed = ToolsetProvider.tryParse(row);
        if (parsed == null) {
          skipped++;
        } else {
          providers.add(parsed);
        }
      }
    }
    return ToolsetConfig(
      name: _text(map['name']) ?? '',
      hasCategory: _flag(map['has_category']),
      activeProvider: _text(map['active_provider']),
      providers: List.unmodifiable(providers),
      skipped: skipped,
      activeSearchBackend: _text(map['active_search_backend']),
      activeExtractBackend: _text(map['active_extract_backend']),
      searchViaNous: _flag(map['search_via_nous']),
      extractViaNous: _flag(map['extract_via_nous']),
    );
  }

  final String name;

  /// False for toolsets with nothing to set up (file, todo and the like).
  final bool hasCategory;
  final String? activeProvider;
  final List<ToolsetProvider> providers;
  final int skipped;
  final String? activeSearchBackend;
  final String? activeExtractBackend;
  final bool searchViaNous;
  final bool extractViaNous;
}

class ToolsetModel {
  const ToolsetModel({
    required this.id,
    required this.display,
    this.speed,
    this.strengths,
    this.price,
  });

  final String id;
  final String display;

  /// Free text from the provider, shown as given.
  final String? speed;
  final String? strengths;
  final String? price;
}

/// A toolset's model catalog; only `image_gen` and `video_gen` have one.
class ToolsetModels {
  const ToolsetModels({
    required this.hasModels,
    this.models = const [],
    this.current,
    this.defaultModel,
    this.provider,
    this.skipped = 0,
  });

  factory ToolsetModels.parse(Object? json) {
    final map = json is Map<Object?, Object?> ? json : const {};
    final models = <ToolsetModel>[];
    var skipped = 0;
    final rows = map['models'];
    if (rows is List) {
      for (final row in rows) {
        if (row is Map<Object?, Object?> &&
            row['id'] is String &&
            (row['id'] as String).isNotEmpty) {
          final id = row['id'] as String;
          final display = _text(row['display']);
          models.add(
            ToolsetModel(
              id: id,
              display: display == null || display.isEmpty ? id : display,
              speed: _text(row['speed']),
              strengths: _text(row['strengths']),
              price: _text(row['price']),
            ),
          );
        } else {
          skipped++;
        }
      }
    }
    return ToolsetModels(
      hasModels: _flag(map['has_models']) && models.isNotEmpty,
      models: List.unmodifiable(models),
      current: _text(map['current']),
      defaultModel: _text(map['default']),
      provider: _text(map['provider']),
      skipped: skipped,
    );
  }

  final bool hasModels;
  final List<ToolsetModel> models;
  final String? current;
  final String? defaultModel;
  final String? provider;
  final int skipped;
}

/// Whether a terminal backend can run commands now; a probe failure is a
/// status, never an error. Unknown values read as [unavailable].
enum BackendStatus {
  ready,
  needsSetup,
  unavailable;

  static BackendStatus parse(Object? value) => switch (value) {
    'ready' => ready,
    'needs_setup' => needsSetup,
    _ => unavailable,
  };
}

class TerminalBackend {
  const TerminalBackend({
    required this.name,
    required this.label,
    required this.description,
    required this.active,
    required this.status,
    this.detail,
  });

  final String name;
  final String label;
  final String description;
  final bool active;
  final BackendStatus status;

  /// Hermes' own text about why a backend is not ready.
  final String? detail;
}

class TerminalBackends {
  const TerminalBackends({
    this.active,
    this.backends = const [],
    this.skipped = 0,
  });

  factory TerminalBackends.parse(Object? json) {
    final map = json is Map<Object?, Object?> ? json : const {};
    final backends = <TerminalBackend>[];
    var skipped = 0;
    final rows = map['backends'];
    if (rows is List) {
      for (final row in rows) {
        if (row is Map<Object?, Object?> &&
            row['name'] is String &&
            (row['name'] as String).isNotEmpty) {
          final name = row['name'] as String;
          final label = _text(row['label']);
          backends.add(
            TerminalBackend(
              name: name,
              label: label == null || label.isEmpty ? name : label,
              description: _text(row['description']) ?? '',
              active: _flag(row['active']),
              status: BackendStatus.parse(row['status']),
              detail: _text(row['detail']),
            ),
          );
        } else {
          skipped++;
        }
      }
    }
    return TerminalBackends(
      active: _text(map['active']),
      backends: List.unmodifiable(backends),
      skipped: skipped,
    );
  }

  final String? active;
  final List<TerminalBackend> backends;
  final int skipped;
}

class ComputerUseCheck {
  const ComputerUseCheck({required this.label, this.status, this.message});

  final String label;
  final String? status;
  final String? message;
}

/// The server's readiness for Computer use (`platform` is the server's).
class ComputerUseStatus {
  const ComputerUseStatus({
    this.platform,
    this.platformSupported = false,
    this.installed = false,
    this.version,
    this.ready,
    this.canGrant = false,
    this.checks = const [],
    this.error,
    this.accessibility,
    this.screenRecording,
  });

  factory ComputerUseStatus.parse(Object? json) {
    final map = json is Map<Object?, Object?> ? json : const {};
    return ComputerUseStatus(
      platform: _text(map['platform']),
      platformSupported: _flag(map['platform_supported']),
      installed: _flag(map['installed']),
      version: _text(map['version']),
      ready: _tri(map['ready']),
      canGrant: _flag(map['can_grant']),
      checks: [
        for (final check in _maps(map['checks']))
          if (_text(check['label']) case final String label
              when label.isNotEmpty)
            ComputerUseCheck(
              label: label,
              status: _text(check['status']),
              message: _text(check['message']),
            ),
      ],
      error: _text(map['error']),
      accessibility: _tri(map['accessibility']),
      screenRecording: _tri(map['screen_recording']),
    );
  }

  final String? platform;
  final bool platformSupported;
  final bool installed;
  final String? version;

  /// Null means unknown (the driver is missing or the probe failed).
  final bool? ready;
  final bool canGrant;
  final List<ComputerUseCheck> checks;
  final String? error;

  /// Null when it cannot be read; only an exact `false` is a missing grant.
  final bool? accessibility;
  final bool? screenRecording;

  /// "Allow access" is offered only when the driver is there and a
  /// permission is known to be missing.
  bool get canOfferGrant =>
      canGrant &&
      installed &&
      (accessibility == false || screenRecording == false);
}

/// The answer to switching a toolset.
class ToolsetSwitched {
  const ToolsetSwitched({
    required this.name,
    required this.enabled,
    this.postSetupStarted,
  });

  factory ToolsetSwitched.parse(Object? json, {required String name}) {
    final map = json is Map<Object?, Object?> ? json : const {};
    final started = _text(map['post_setup_started']);
    return ToolsetSwitched(
      name: _text(map['name']) ?? name,
      enabled: _flag(map['enabled']),
      postSetupStarted: started == null || started.isEmpty ? null : started,
    );
  }

  final String name;
  final bool enabled;

  /// The install step Hermes started because of the switch, if any.
  final String? postSetupStarted;
}

/// The answer to picking a provider.
class ToolsetProviderPicked {
  const ToolsetProviderPicked({this.needsNousAuth = false});

  factory ToolsetProviderPicked.parse(Object? json) => ToolsetProviderPicked(
    needsNousAuth:
        json is Map<Object?, Object?> && _flag(json['needs_nous_auth']),
  );

  /// Hermes wrote the config, but the row works only after a sign-in to the
  /// Nous Portal on the server.
  final bool needsNousAuth;
}

/// The answer to saving keys: names only, never values.
class ToolsetEnvSaved {
  const ToolsetEnvSaved({this.saved = const [], this.skipped = const []});

  factory ToolsetEnvSaved.parse(Object? json) {
    final map = json is Map<Object?, Object?> ? json : const {};
    return ToolsetEnvSaved(
      saved: _strings(map['saved']),
      skipped: _strings(map['skipped']),
    );
  }

  final List<String> saved;
  final List<String> skipped;
}

/// An install or grant Hermes started on the server.
class ToolsActionStarted {
  const ToolsActionStarted({this.pid});

  factory ToolsActionStarted.parse(Object? json) {
    final pid = json is Map<Object?, Object?> ? json['pid'] : null;
    return ToolsActionStarted(pid: pid is int ? pid : null);
  }

  final int? pid;
}

/// A background action's log (`GET /api/actions/<name>/status`).
/// `running: false` with a null [exitCode] means "can't tell".
class ToolsActionStatus {
  const ToolsActionStatus({
    required this.running,
    this.exitCode,
    this.pid,
    this.lines = const [],
  });

  factory ToolsActionStatus.parse(Object? json) {
    final map = json is Map<Object?, Object?> ? json : const {};
    final code = map['exit_code'];
    final pid = map['pid'];
    return ToolsActionStatus(
      running: _flag(map['running']),
      exitCode: code is int ? code : null,
      pid: pid is int ? pid : null,
      lines: _strings(map['lines']),
    );
  }

  final bool running;
  final int? exitCode;
  final int? pid;
  final List<String> lines;
}
