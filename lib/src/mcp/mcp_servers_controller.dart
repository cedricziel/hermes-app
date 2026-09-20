import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../profiles/hermes_profiles_repository.dart';
import 'hermes_mcp_repository.dart';
import 'mcp_command_review_items.dart';

/// Where a connection test of one server stands.
sealed class McpTestState {
  const McpTestState();
}

class McpTestRunning extends McpTestState {
  McpTestRunning();
}

class McpTestFinished extends McpTestState {
  const McpTestFinished(this.result);

  final HermesMcpTestResult result;
}

/// The request itself failed, as opposed to the server failing the test.
class McpTestUnavailable extends McpTestState {
  const McpTestUnavailable();
}

/// Opens a link in the system browser; false when it could not.
typedef McpLinkLauncher = Future<bool> Function(Uri uri);

Future<bool> _openInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// What starting a sign-in came to.
sealed class McpSignInStart {
  const McpSignInStart();
}

/// Hermes started the flow; the user approves it in the browser.
class McpSignInStarted extends McpSignInStart {
  const McpSignInStarted(this.flow);

  final HermesMcpFlow flow;
}

/// Hermes said no. The reason is on [McpServersController.signInNoteOf].
class McpSignInDeclined extends McpSignInStart {
  const McpSignInDeclined();
}

/// The dashboard no longer knows the server; the list has been reloaded.
class McpSignInGone extends McpSignInStart {
  const McpSignInGone();
}

/// Asks the user whether the [commands] may be saved and run on the Hermes
/// host. False, or an error, means no.
typedef McpReviewer = Future<bool> Function(
  List<McpCommandReviewItem> commands,
);

/// What adding a server came to.
sealed class McpAddOutcome {
  const McpAddOutcome();
}

/// Hermes added the server and the list shows it.
class McpAdded extends McpAddOutcome {
  const McpAdded(this.name);

  final String name;
}

/// Nothing was sent: the user went back at the review, or another save was
/// already running.
class McpAddCancelled extends McpAddOutcome {
  const McpAddCancelled();
}

/// Hermes already has a server of that name.
class McpAddDuplicate extends McpAddOutcome {
  const McpAddDuplicate();
}

/// Hermes said no with a reason of its own, empty when it gave none.
class McpAddRefused extends McpAddOutcome {
  const McpAddRefused(this.reason);

  final String reason;
}

class McpAddFailed extends McpAddOutcome {
  const McpAddFailed();
}

/// What replacing the whole map of servers came to.
sealed class McpReplaceOutcome {
  const McpReplaceOutcome();
}

class McpReplaced extends McpReplaceOutcome {
  const McpReplaced();
}

/// Nothing was sent: the user declined the review, or another save was
/// already running.
class McpReplaceCancelled extends McpReplaceOutcome {
  const McpReplaceCancelled();
}

/// Hermes refused the save. [problems] are its words, one per problem.
class McpReplaceRefused extends McpReplaceOutcome {
  const McpReplaceRefused(this.problems);

  final List<String> problems;
}

class McpReplaceFailed extends McpReplaceOutcome {
  const McpReplaceFailed();
}

enum McpOutcome {
  done,

  /// The dashboard no longer knows the server; the list has been reloaded.
  gone,
  failed,
}

/// The state of one visit to the MCP servers screen: the active profile, the
/// servers of that profile and the test results, which are dropped with the
/// visit because they only say "worked just now".
///
/// Every request carries the profile learned in [load]. A profile lookup that
/// fails for any reason but 404 fails the load, so nothing is listed or
/// changed unscoped.
class McpServersController extends ChangeNotifier {
  McpServersController({
    required this.repository,
    this.profiles,
    McpLinkLauncher? launchLink,
  }) : launchLink = launchLink ?? _openInBrowser;

  final HermesMcpRepository repository;
  final HermesProfilesRepository? profiles;
  final McpLinkLauncher launchLink;

  String? _profile;
  List<HermesMcpServer>? _servers;
  bool _loading = true;
  bool _failed = false;
  bool _disposed = false;
  bool _saving = false;
  final _switching = <String>{};
  final _tests = <String, McpTestState>{};
  final _startingSignIn = <String>{};
  final _signInNotes = <String, String>{};

  /// The profile the screen acts on; null when the dashboard has none.
  String? get profile => _profile;
  List<HermesMcpServer>? get servers => _servers;
  bool get loading => _loading;
  bool get failed => _failed;

  /// Whether an add or a replace is running, review included. Another one
  /// waits for it.
  bool get isSaving => _saving;

  bool get _ready => _servers != null && !_failed;

  bool isSwitching(String name) => _switching.contains(name);
  McpTestState? testOf(String name) => _tests[name];
  bool isStartingSignIn(String name) => _startingSignIn.contains(name);

  /// Why Hermes would not start a sign-in for the server, until the next try.
  String? signInNoteOf(String name) => _signInNotes[name];

  HermesMcpServer? serverNamed(String? name) =>
      _servers?.where((s) => s.name == name).firstOrNull;

  /// Learns the active profile, then lists its servers.
  Future<void> load() async {
    _loading = true;
    _failed = false;
    _notify();
    try {
      _profile = await _activeProfile();
      await _fetch();
    } on Object {
      if (_disposed) return;
      _failed = true;
    }
    _loading = false;
    _notify();
  }

  Future<String?> _activeProfile() async {
    try {
      final active = (await profiles?.loadActive())?.active;
      return active == null || active.isEmpty ? null : active;
    } on Object catch (e) {
      if (isMcpNotFound(e)) return null;
      rethrow;
    }
  }

  Future<void> _fetch() async {
    final servers = await repository.loadServers(profile: _profile);
    if (_disposed) return;
    _servers = servers;
    _tests.removeWhere((name, _) => servers.every((s) => s.name != name));
  }

  /// Lists the servers again, for a change made elsewhere such as an install.
  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    try {
      await _fetch();
    } on Object {
      if (_disposed) return;
      _failed = true;
    }
    _notify();
  }

  /// Adds [server] to the profile. A command server makes Hermes run a
  /// program, so [review] must confirm it first and nothing is sent until it
  /// does; this is the only way the app saves one. Nothing is added when the
  /// profile is unknown.
  Future<McpAddOutcome> addServer(
    McpNewServer server, {
    required McpReviewer review,
  }) async {
    if (_saving) return const McpAddCancelled();
    if (!_ready) return const McpAddFailed();
    _saving = true;
    _notify();
    try {
      if (server is McpNewCommandServer &&
          !await review([McpCommandReviewItem.of(server)])) {
        return const McpAddCancelled();
      }
      await repository.addServer(server, profile: _profile);
      await _reload();
      return McpAdded(server.name);
    } on McpRefused catch (e) {
      return e.status == 409
          ? const McpAddDuplicate()
          : McpAddRefused(e.reason);
    } on Object {
      return const McpAddFailed();
    } finally {
      _saving = false;
      _notify();
    }
  }

  /// The profile's whole `mcp_servers` map as stored, for an editor that
  /// replaces it. Throws when it cannot be read, or the profile is unknown.
  Future<Map<String, Object?>> loadRawServers() async {
    if (!_ready) await load();
    if (!_ready) throw StateError('The active profile is unknown');
    return repository.loadRawServers(profile: _profile);
  }

  /// Replaces the profile's whole map of servers with [servers], which was
  /// edited from [loaded]. The command servers of [servers] that are new or
  /// changed against [loaded] go to [review] first and nothing is sent until
  /// it confirms. What is reviewed is what is sent: [servers] is copied first.
  Future<McpReplaceOutcome> replaceServers(
    Map<String, Object?> loaded,
    Map<String, Map<String, Object?>> servers, {
    required McpReviewer review,
  }) async {
    if (_saving) return const McpReplaceCancelled();
    if (!_ready) return const McpReplaceFailed();
    _saving = true;
    _notify();
    try {
      final snapshot = <String, Map<String, Object?>>{
        for (final e in (jsonDecode(jsonEncode(servers)) as Map).entries)
          '${e.key}': Map<String, Object?>.from(e.value as Map),
      };
      final commands = commandServersToReview(loaded, snapshot);
      if (commands.isNotEmpty && !await review(commands)) {
        return const McpReplaceCancelled();
      }
      await repository.replaceServers(snapshot, profile: _profile);
      await _reload();
      return const McpReplaced();
    } on McpRefused catch (e) {
      return McpReplaceRefused(e.problems);
    } on Object {
      return const McpReplaceFailed();
    } finally {
      _saving = false;
      _notify();
    }
  }

  /// Sets the server on or off. The new state shows once the dashboard has
  /// confirmed it.
  Future<McpOutcome> setEnabled(HermesMcpServer server, bool enabled) async {
    final name = server.name;
    if (!_switching.add(name)) return McpOutcome.failed;
    _notify();
    try {
      await repository.setEnabled(name, enabled, profile: _profile);
      _servers = [
        for (final s in _servers ?? const <HermesMcpServer>[])
          s.name == name ? s.withEnabled(enabled) : s,
      ];
      return McpOutcome.done;
    } on Object catch (e) {
      return _failure(e);
    } finally {
      _switching.remove(name);
      _notify();
    }
  }

  Future<void> test(HermesMcpServer server) async {
    final name = server.name;
    if (_tests[name] is McpTestRunning) return;
    final run = McpTestRunning();
    _tests[name] = run;
    _notify();
    McpTestState? outcome;
    try {
      outcome = McpTestFinished(
        await repository.testServer(server, profile: _profile),
      );
    } on Object catch (e) {
      if (await _failure(e) != McpOutcome.gone) {
        outcome = const McpTestUnavailable();
      }
    }
    if (identical(_tests[name], run)) {
      if (outcome == null) {
        _tests.remove(name);
      } else {
        _tests[name] = outcome;
      }
    }
    _notify();
  }

  /// Deletes the server. A server the dashboard no longer knows counts as
  /// removed.
  Future<McpOutcome> remove(HermesMcpServer server) async {
    final name = server.name;
    try {
      await repository.removeServer(name, profile: _profile);
    } on Object catch (e) {
      return _failure(e);
    }
    _servers = _servers?.where((s) => s.name != name).toList();
    _tests.remove(name);
    _notify();
    return McpOutcome.done;
  }

  /// Asks Hermes to start signing in to an OAuth server. Its refusals become
  /// a note on the server, not an exception.
  Future<McpSignInStart> startSignIn(HermesMcpServer server) async {
    final name = server.name;
    if (!_startingSignIn.add(name)) return const McpSignInDeclined();
    _signInNotes.remove(name);
    _notify();
    try {
      return McpSignInStarted(
        await repository.startSignIn(name, profile: _profile),
      );
    } on McpRefused catch (e) {
      _signInNotes[name] = switch (e.status) {
        409 =>
          'A sign-in for $name is already in progress on your server. '
              'Try again in a few minutes.',
        429 =>
          'Too many sign-ins are in progress on your server. '
              'Try again in a few minutes.',
        _ when e.reason.isNotEmpty => e.reason,
        _ => 'Could not start signing in to $name',
      };
      return const McpSignInDeclined();
    } on Object catch (e) {
      if (await _failure(e) == McpOutcome.gone) return const McpSignInGone();
      _signInNotes[name] = 'Could not start signing in to $name';
      return const McpSignInDeclined();
    } finally {
      _startingSignIn.remove(name);
      _notify();
    }
  }

  /// Ends [flow] on Hermes so its server can start another sign-in. Nobody
  /// waits for the answer; a flow Hermes has dropped is already cancelled.
  void cancelSignIn(HermesMcpFlow flow) {
    unawaited(repository.cancelFlow(flow.flowId).catchError((Object _) {}));
  }

  /// A 404 means another client removed the server: reload the list.
  Future<McpOutcome> _failure(Object error) async {
    if (!isMcpNotFound(error)) return McpOutcome.failed;
    await _reload();
    return McpOutcome.gone;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
