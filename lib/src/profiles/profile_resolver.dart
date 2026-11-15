import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';

/// A profile name that a request may carry: the chat's own, or else the
/// profile the dashboard was launched with. Only [ProfileResolver] makes one,
/// so a repository that asks for it cannot be handed a bare string, a
/// literal `default` or the server's sticky `active` profile.
///
/// It is a [String] at runtime and in use (`implements String`); the type
/// only closes the way in.
extension type const ResolvedProfile._(String name) implements String {}

/// Where a chat with no profile of its own works: the dashboard's launch
/// profile, `current` of `GET /api/profiles/active` (not `active`, the sticky
/// default that new CLI runs pick up). Read once per connection and kept.
class ProfileResolver extends ChangeNotifier {
  /// Resolves through [read], the answer of `GET /api/profiles/active`.
  ProfileResolver(this._read);

  /// A resolver that already knows the launch profile [name]; for tests and
  /// for code that has no connection to ask.
  ProfileResolver.known(String name)
    : _read = null,
      _launch = name.isEmpty ? null : name;

  final Future<({String active, String current})> Function()? _read;
  String? _launch;
  Future<String?>? _loading;

  /// The launch profile; null until [load] has read it, or when the server
  /// has no profiles.
  String? get launch => _launch;

  /// Reads the launch profile unless it is known, and answers it. Null for a
  /// server without the profiles route; any other failure throws and is
  /// tried again on the next call.
  Future<String?> load() {
    if (_launch != null) return Future.value(_launch);
    return _loading ??= _fetch().whenComplete(() => _loading = null);
  }

  Future<String?> _fetch() async {
    final read = _read;
    if (read == null) return null;
    final ({String active, String current}) answer;
    try {
      answer = await read();
    } on Object catch (error) {
      if (_isMissingRoute(error)) return null;
      rethrow;
    }
    final name = answer.current.isNotEmpty ? answer.current : answer.active;
    if (name.isEmpty) return null;
    _launch = name;
    notifyListeners();
    return name;
  }

  /// The profile [name], which the person picked from the server's own list.
  ResolvedProfile named(String name) {
    assert(name.isNotEmpty, 'A profile has a name');
    return ResolvedProfile._(name);
  }

  /// The profile a request for a chat on [profile] carries: its own, else the
  /// launch profile. Null while neither is known, and then nothing is sent.
  ResolvedProfile? resolve(String? profile) {
    if (profile != null && profile.isNotEmpty) {
      return ResolvedProfile._(profile);
    }
    final launch = _launch;
    return launch == null ? null : ResolvedProfile._(launch);
  }
}

/// A profile for a test or a fixture that has no resolver to ask.
@visibleForTesting
ResolvedProfile resolvedProfile(String name) =>
    ProfileResolver.known(name).resolve(null)!;

bool _isMissingRoute(Object error) =>
    error is DioException && error.response?.statusCode == 404;
