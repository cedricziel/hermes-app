import 'package:dio/dio.dart' show DioException, Response;
import 'package:hermes_api/hermes_api.dart';

import '../chat/gateway/gateway_rpc_client.dart';
import '../surfaces/surface_snapshot.dart' show kDefaultProfile;
import 'workspace_models.dart';
import 'workspace_paths.dart';

/// How long a gateway call here may go unanswered. A move that gets no answer
/// in that time is a lost answer: the caller reads the chat again and never
/// sends it twice.
const kWorkspaceRpcTimeout = Duration(seconds: 10);

/// The gateway request that gives up on one call without closing the
/// connection that running replies share (`GatewayRpcClient.requestWithin`,
/// `HermesGatewayTransport.requestKeepingConnection`).
typedef WorkspaceRpc = Future<Map<String, Object?>> Function(
  String method,
  Map<String, Object?> params, {
  required Duration timeout,
});

/// `detail` of a 403 that says the dashboard's managed read boundary
/// (`HERMES_DASHBOARD_FILES_ROOT`) does not include the path.
const _boundaryDetail = 'path is outside the managed read boundary';

/// `detail` of a 403 an SSH profile answers for `EACCES`.
const _unreadableDetail = 'file is not readable';

/// The 30 items `complete.path` stops at.
const _completionCap = 30;

/// Reads the server's projects and folders, and moves a chat to another
/// folder.
///
/// Every call names its profile (`default` for none), since Hermes answers
/// for its launch home otherwise. Every call yields a [WorkspacesResult]
/// instead of throwing, and a failure is only a kind: the request URL (which
/// carries a path), a path and the server's own error text (a `4017` echoes
/// the raw path) are dropped where the error is caught, so nothing a caller
/// logs or shows can carry them. Nothing here writes to the device.
///
/// The REST routes declare no response schema, so bodies are parsed by hand,
/// skipping rows that do not fit.
class HermesWorkspacesRepository {
  HermesWorkspacesRepository(
    this._api,
    this._rpc, {
    this.timeout = kWorkspaceRpcTimeout,
  });

  final DefaultApi _api;
  final WorkspaceRpc _rpc;
  final Duration timeout;

  /// The projects and git roots of [profile], and the folder a chat runs in
  /// when none is picked. With [scan] the server also walks the profile's
  /// scan folders first.
  Future<WorkspacesResult<WorkspaceCatalog>> catalog({
    String? profile,
    bool scan = false,
  }) => _rest(
    () => _api.getChatWorkspacesApiChatWorkspacesGet(
      profile: profile ?? kDefaultProfile,
      scan: scan,
    ),
    (body) => body is Map ? _catalog(body) : null,
    onStatus: (status, detail) => switch (status) {
      404 when detail != null && detail.toLowerCase().contains('exist') =>
        const WorkspacesFailed(WorkspacesFailure.unknownProfile),
      404 || 405 => const WorkspacesUnsupported(),
      _ => null,
    },
  );

  /// The folders (not the files) directly inside [path].
  ///
  /// A 404 means a missing folder once the route is known to exist
  /// ([routeKnown], after an earlier read answered); before that it means a
  /// server without the route, which answers the same status.
  Future<WorkspacesResult<FolderListing>> listFolders(
    String path, {
    String? profile,
    bool routeKnown = false,
  }) => _rest(
    () => _api.fsListApiFsListGet(
      path: path,
      profile: profile ?? kDefaultProfile,
    ),
    (body) {
      if (body is! Map) return null;
      final error = body['error'];
      if (error is String && error.isNotEmpty) {
        return WorkspacesFailed(switch (error) {
          'ENOENT' => WorkspacesFailure.notFound,
          'ENOTDIR' => WorkspacesFailure.notADirectory,
          'EACCES' => WorkspacesFailure.notAllowed,
          _ => WorkspacesFailure.unknown,
        });
      }
      return _listing(body);
    },
    onStatus: (status, detail) => switch (status) {
      400 => const WorkspacesFailed(WorkspacesFailure.notADirectory),
      403 => WorkspacesFailed(_forbidden(detail)),
      404 =>
        routeKnown
            ? const WorkspacesFailed(WorkspacesFailure.notFound)
            : const WorkspacesUnsupported(),
      405 => const WorkspacesUnsupported(),
      _ => null,
    },
  );

  /// The folders the server completes the typed [word] to. [word] must start
  /// with `/` or `~`; anything else answers an empty list without asking.
  Future<WorkspacesResult<PathSuggestions>> complete(
    String word, {
    String? profile,
  }) async {
    if (!isServerPath(word)) {
      return const WorkspacesOk(PathSuggestions(folders: [], capped: false));
    }
    return _gateway('complete.path', {
      'word': word,
      'profile': profile ?? kDefaultProfile,
    }, (result) => _suggestions(word, result));
  }

  /// Moves the stored chat [storedId] to [cwd], once. Nothing is sent for a
  /// path that does not start with `/` or `~`. A failure that may still have
  /// happened ([WorkspacesFailure.unreachable], [WorkspacesFailure.busy]) is
  /// for the caller to settle by reading the chat with [sessionFolder].
  Future<WorkspacesResult<MovedWorkspace>> moveWorkspace(
    String storedId,
    String cwd, {
    String? profile,
  }) async {
    if (!isServerPath(cwd)) {
      return const WorkspacesFailed(WorkspacesFailure.notFound);
    }
    return _gateway(
      'session.workspace.move',
      {
        'session_key': storedId,
        'cwd': cwd,
        'profile': profile ?? kDefaultProfile,
      },
      _moved,
      codes: const {
        4007: WorkspacesFailure.sessionGone,
        4017: WorkspacesFailure.notFound,
        5007: WorkspacesFailure.busy,
      },
      // An answer that does not fit may be one the server gave after moving.
      malformed: WorkspacesFailure.unreachable,
    );
  }

  /// The folder fields of the stored chat [id], to learn what a lost answer
  /// to a move came to.
  Future<WorkspacesResult<SessionFolder>> sessionFolder(
    String id, {
    String? profile,
  }) => _rest(
    () => _api.getSessionDetailApiSessionsSessionIdGet(
      sessionId: id,
      profile: profile ?? kDefaultProfile,
    ),
    (body) => body is Map
        ? SessionFolder(
            cwd: _text(body['cwd']),
            branch: _text(body['git_branch']),
            gitRepoRoot: _text(body['git_repo_root']),
          )
        : null,
    onStatus: (status, detail) => status == 404
        ? const WorkspacesFailed(WorkspacesFailure.sessionGone)
        : null,
  );

  /// The folders the profile scans for projects (`desktop.repo_scan_roots`),
  /// empty when none are set.
  Future<WorkspacesResult<List<String>>> scanRoots({String? profile}) => _rest(
    () => _api.getConfigApiConfigGet(profile: profile ?? kDefaultProfile),
    (body) {
      if (body is! Map) return null;
      final desktop = body['desktop'];
      var roots = desktop is Map ? desktop['repo_scan_roots'] : null;
      if (roots is Map) roots = roots['roots'];
      if (roots == null) return const <String>[];
      if (roots is! List) return null;
      return [for (final root in roots) ?_text(root)];
    },
    onStatus: (status, detail) => status == 404
        ? const WorkspacesFailed(WorkspacesFailure.unknownProfile)
        : null,
  );

  /// Runs a REST call. [parse] gives null for a body that does not fit, and
  /// may itself return a failure; [onStatus] reads an error status, with the
  /// string `detail` when there is one, and gives null to fall through to the
  /// general mapping. Whatever is thrown is dropped here: a `DioException`
  /// carries the request URI.
  Future<WorkspacesResult<T>> _rest<T>(
    Future<Response<Object>> Function() call,
    Object? Function(Object? body) parse, {
    required WorkspacesResult<T>? Function(int status, String? detail) onStatus,
  }) async {
    try {
      final response = await call();
      final parsed = parse(response.data);
      return switch (parsed) {
        WorkspacesFailed(:final kind) => WorkspacesFailed<T>(kind),
        WorkspacesUnsupported() => WorkspacesUnsupported<T>(),
        final T value => WorkspacesOk<T>(value),
        _ => WorkspacesFailed<T>(WorkspacesFailure.unknown),
      };
    } on DioException catch (error) {
      final response = error.response;
      final status = response?.statusCode;
      if (status == null) {
        return const WorkspacesFailed(WorkspacesFailure.unreachable);
      }
      final data = response?.data;
      final detail = data is Map && data['detail'] is String
          ? data['detail'] as String
          : null;
      final mapped = onStatus(status, detail);
      if (mapped != null) return mapped;
      return WorkspacesFailed(
        status == 503 || status == 502 || status == 504
            ? WorkspacesFailure.unreachable
            : WorkspacesFailure.unknown,
      );
    } on Object {
      return const WorkspacesFailed(WorkspacesFailure.unknown);
    }
  }

  Future<WorkspacesResult<T>> _gateway<T>(
    String method,
    Map<String, Object?> params,
    T? Function(Map<String, Object?> result) parse, {
    Map<int, WorkspacesFailure> codes = const {},
    WorkspacesFailure malformed = WorkspacesFailure.unknown,
  }) async {
    try {
      final result = await _rpc(method, params, timeout: timeout);
      final value = parse(result);
      return value == null ? WorkspacesFailed(malformed) : WorkspacesOk(value);
    } on GatewayRpcException catch (error) {
      if (error.code == kGatewayMethodNotFound) {
        return const WorkspacesUnsupported();
      }
      if (error.code == kGatewayProfileUnavailable) {
        return const WorkspacesFailed(WorkspacesFailure.unknownProfile);
      }
      return WorkspacesFailed(codes[error.code] ?? WorkspacesFailure.unknown);
    } on Object {
      // No answer: a timeout, a closed socket, no connection.
      return const WorkspacesFailed(WorkspacesFailure.unreachable);
    }
  }

  /// Reads a 403 by its `detail`: the boundary and any text that is not
  /// recognised (or not a string) are the least capable reading.
  static WorkspacesFailure _forbidden(String? detail) {
    final text = detail?.toLowerCase() ?? '';
    if (text.contains(_boundaryDetail)) {
      return WorkspacesFailure.outsideBoundary;
    }
    return text.contains(_unreadableDetail)
        ? WorkspacesFailure.notAllowed
        : WorkspacesFailure.outsideBoundary;
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static WorkspaceCatalog _catalog(Map<Object?, Object?> body) {
    final projects = <WorkspaceProject>[];
    if (body['projects'] case final List rows) {
      for (final row in rows) {
        if (row is! Map) continue;
        final id = _text(row['id']);
        final name = _text(row['name']);
        if (id == null || name == null) continue;
        final folders = <WorkspaceFolder>[];
        if (row['folders'] case final List entries) {
          for (final entry in entries) {
            if (entry is! Map) continue;
            final path = _text(entry['path']);
            if (path == null) continue;
            folders.add(
              WorkspaceFolder(
                path: path,
                label: _text(entry['label']),
                isPrimary: entry['is_primary'] == true,
              ),
            );
          }
        }
        // The primary folder first, the others as the server listed them.
        folders.sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));
        projects.add(
          WorkspaceProject(
            id: id,
            name: name,
            slug: _text(row['slug']),
            folders: folders,
            archived: row['archived'] == true,
          ),
        );
      }
    }
    final repos = <WorkspaceRepo>[];
    if (body['repos'] case final List rows) {
      for (final row in rows) {
        if (row is! Map) continue;
        final root = _text(row['root']);
        if (root == null) continue;
        repos.add(
          WorkspaceRepo(
            root: root,
            label: _text(row['label']),
            sessions: row['sessions'] is num
                ? (row['sessions'] as num).toInt()
                : 0,
            lastActive: row['last_active'] is num
                ? (row['last_active'] as num).toDouble()
                : null,
          ),
        );
      }
    }
    return WorkspaceCatalog(
      projects: projects,
      repos: repos,
      defaultCwd: _text(body['default_cwd']),
      home: _text(body['home']),
      scanEnabled: body['scan_enabled'] == true,
    );
  }

  static FolderListing _listing(Map<Object?, Object?> body) {
    final folders = <FolderEntry>[];
    if (body['entries'] case final List rows) {
      for (final row in rows) {
        if (row is! Map || row['isDirectory'] != true) continue;
        final path = _text(row['path']);
        if (path == null) continue;
        final name =
            _text(row['name']) ??
            path.split('/').lastWhere((s) => s.isNotEmpty, orElse: () => path);
        folders.add(FolderEntry(name: name, path: path));
      }
    }
    return FolderListing(folders);
  }

  /// Builds each next text from what was typed and the entry's `display`,
  /// never from `text`: for an absolute word Hermes answers `text` relative
  /// to its own completion root.
  static PathSuggestions? _suggestions(
    String word,
    Map<String, Object?> result,
  ) {
    final items = result['items'];
    if (items is! List) return null;
    final slash = word.lastIndexOf('/');
    final directory = slash >= 0
        ? word.substring(0, slash + 1)
        : (word == '~' ? '~/' : '');
    final folders = <PathSuggestion>[];
    for (final item in items) {
      if (item is! Map || item['meta'] != 'dir') continue;
      final display = _text(item['display']);
      if (display == null) continue;
      final shown = display.endsWith('/') ? display : '$display/';
      folders.add(PathSuggestion(text: '$directory$shown', display: shown));
    }
    return PathSuggestions(
      folders: folders,
      capped: items.length >= _completionCap,
    );
  }

  static MovedWorkspace? _moved(Map<String, Object?> result) {
    final cwd = _text(result['cwd']);
    if (cwd == null) return null;
    return MovedWorkspace(
      cwd: cwd,
      branch: _text(result['branch']),
      gitRepoRoot: _text(result['git_repo_root']),
    );
  }
}
