import '../../api/hermes_api_client.dart';
import '../../api/request_timeout.dart';
import '../../server_care/json_read.dart';

/// The two config switches the run confirmation words itself by, read from
/// `GET /api/config` (a top-level `curator` map). A value that cannot be read
/// is null, and the confirmation then uses its hedged wording.
class CuratorConfig {
  const CuratorConfig({this.consolidate, this.pruneBuiltins});

  /// Never throws; an answer with no `curator` map reads as all unknown.
  factory CuratorConfig.parse(Object? json) {
    final curator = readMap(readMap(json)?['curator']);
    return CuratorConfig(
      consolidate: readBool(curator?['consolidate']),
      pruneBuiltins: readBool(curator?['prune_builtins']),
    );
  }

  /// A pass may merge and rewrite skills.
  final bool? consolidate;

  /// A pass also manages bundled skills.
  final bool? pruneBuiltins;
}

/// `GET /api/config?profile=`, read only for [CuratorConfig]. Answers null
/// when it cannot be read (the caller keeps the hedged wording); never throws.
class CuratorConfigReader {
  CuratorConfigReader(
    HermesApiClient client, {
    this.timeout = const Duration(seconds: 10),
  }) : _client = client;

  final HermesApiClient _client;
  final Duration timeout;

  Future<CuratorConfig?> call(String profile) async {
    if (profile.trim().isEmpty) return null;
    try {
      final data = (await _client.raw.getConfigApiConfigGet(
        profile: profile,
        extra: receiveTimeoutExtra(timeout),
      )).data;
      return data is Map ? CuratorConfig.parse(data) : null;
    } on Object {
      return null;
    }
  }
}
