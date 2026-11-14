import 'json_read.dart';

/// How Hermes is installed, which decides whether the dashboard can update it.
enum InstallMethod {
  git,
  docker,
  apt,
  nix,
  nixos,
  managedRuntime,
  desktopApp,
  unknown,
  other,
}

InstallMethod _installMethod(String? raw) => switch (raw) {
  'git' => InstallMethod.git,
  'docker' => InstallMethod.docker,
  'apt' => InstallMethod.apt,
  'nix' => InstallMethod.nix,
  'nixos' => InstallMethod.nixos,
  'managed-runtime' => InstallMethod.managedRuntime,
  'desktop-app' => InstallMethod.desktopApp,
  'unknown' => InstallMethod.unknown,
  _ => InstallMethod.other,
};

class UpdateCommit {
  const UpdateCommit({
    required this.sha,
    required this.summary,
    this.author,
    this.at,
  });

  final String sha;
  final String summary;
  final String? author;

  /// Unix seconds.
  final int? at;
}

/// `GET /api/hermes/update/check`.
class UpdateCheck {
  const UpdateCheck({
    required this.installMethod,
    this.installMethodRaw,
    this.currentVersion,
    this.behind,
    this.updateAvailable = false,
    this.canApply = false,
    this.updateCommand,
    this.message,
    this.rollbackTo,
    this.commits = const [],
  });

  static UpdateCheck? parse(Object? json) {
    final root = readMap(json);
    if (root == null) return null;
    final raw = readString(root['install_method']);
    final command = readString(root['update_command']);
    return UpdateCheck(
      installMethod: _installMethod(raw),
      installMethodRaw: raw,
      currentVersion: readVersion(root['current_version']),
      behind: readInt(root['behind']),
      updateAvailable: readBool(root['update_available']) ?? false,
      canApply: readBool(root['can_apply']) ?? false,
      updateCommand: command == null || command.isEmpty ? null : command,
      message: readString(root['message']),
      rollbackTo: readString(root['rollback_to']),
      commits: [
        for (final c in readMaps(root['commits']))
          if (readString(c['sha']) case final sha?
              when readString(c['summary']) != null)
            UpdateCommit(
              sha: sha,
              summary: readString(c['summary'])!,
              author: readString(c['author']),
              at: readInt(c['at']),
            ),
      ],
    );
  }

  final InstallMethod installMethod;
  final String? installMethodRaw;
  final String? currentVersion;

  /// Commits behind: 0 up to date, -1 unknown count, null the check could not
  /// run.
  final int? behind;
  final bool updateAvailable;
  final bool canApply;
  final String? updateCommand;
  final String? message;

  /// Set when applying would move this build back to a stable release.
  final String? rollbackTo;
  final List<UpdateCommit> commits;

  bool get couldNotCheck => behind == null;
}
