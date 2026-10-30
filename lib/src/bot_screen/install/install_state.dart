import '../bot_screen_models.dart';

/// How many of the package manager's latest lines an install keeps.
const kInstallLines = 6;

/// How an install that ended is told on the card. Install lines and the
/// command are shown, never logged.
sealed class InstallResult {
  const InstallResult();

  /// The fixed word `bot_screen.install` records for this ending.
  String get outcome;
}

/// Hermes is done: the packages are installed. The card shows the state of
/// the status that came with it, not a result.
final class InstallInstalled extends InstallResult {
  const InstallInstalled();

  @override
  String get outcome => 'installed';
}

/// `display.install` was refused: another install is running, the host is
/// unsupported, the profile is sandboxed or there is no package manager.
/// [message] is the server's own words.
final class InstallRefused extends InstallResult {
  const InstallRefused({this.message});

  final String? message;

  @override
  String get outcome => 'refused';
}

/// `display.install` got no answer: [failure] says why.
final class InstallUnreachable extends InstallResult {
  const InstallUnreachable(this.failure);

  final BotScreenFailure failure;

  @override
  String get outcome => 'error';
}

/// The user declined the sudo password (`display.install.done` code -1).
final class InstallCancelled extends InstallResult {
  const InstallCancelled();

  @override
  String get outcome => 'cancelled';
}

/// The server has no sudo (code -2); [command] is what to run there by hand.
final class InstallNoSudo extends InstallResult {
  const InstallNoSudo({this.command});

  final String? command;

  @override
  String get outcome => 'no_sudo';
}

/// The package manager failed; [lines] are its last lines.
final class InstallFailed extends InstallResult {
  const InstallFailed({this.lines = const []});

  final List<String> lines;

  @override
  String get outcome => 'failed';
}

/// No `display.install.done` arrived within the wait, and the status did not
/// say the packages are installed.
final class InstallMayStillRun extends InstallResult {
  const InstallMayStillRun();

  @override
  String get outcome => 'unknown';
}

/// An install the app started for one profile.
sealed class InstallState {
  const InstallState();
}

/// The install runs. [lines] are the latest output, [askedPassword] whether
/// the server asked for the sudo password.
final class InstallRunning extends InstallState {
  const InstallRunning({this.lines = const [], this.askedPassword = false});

  final List<String> lines;
  final bool askedPassword;
}

/// The install ended with [result]. [status] is the fresh status that came
/// with it, when there was one.
final class InstallEnded extends InstallState {
  const InstallEnded(this.result, {this.status});

  final InstallResult result;
  final BotScreenStatus? status;
}
