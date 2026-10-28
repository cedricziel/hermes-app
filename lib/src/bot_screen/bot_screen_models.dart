import 'dart:typed_data';

/// Who holds the control lease of a profile's screen. `agent` is Hermes
/// itself; `human` is a person who took over, here or elsewhere.
enum BotScreenHolder { agent, human }

/// The public view of a screen's control lease. The holder's viewer id never
/// leaves the gateway: [viewerHash] (the first 12 hex digits of its SHA-256)
/// lets a holder recognise itself.
class BotScreenLease {
  const BotScreenLease({
    this.holder = BotScreenHolder.agent,
    this.viewerHash,
    this.reason = '',
    this.epoch = 0,
  });

  /// Reads a lease, failing closed: anything but an explicit `agent` holder
  /// (a missing or unreadable lease included) counts as a person holding
  /// control, so no picture is shown on a guess.
  factory BotScreenLease.fromJson(Object? json) {
    if (json is! Map) {
      return const BotScreenLease(holder: BotScreenHolder.human);
    }
    final hash = json['viewer_hash'];
    final reason = json['reason'];
    final epoch = json['epoch'];
    return BotScreenLease(
      holder: json['holder'] == 'agent'
          ? BotScreenHolder.agent
          : BotScreenHolder.human,
      viewerHash: hash is String ? hash : null,
      reason: reason is String ? reason : '',
      epoch: epoch is num ? epoch.toInt() : 0,
    );
  }

  final BotScreenHolder holder;
  final String? viewerHash;
  final String reason;
  final int epoch;
}

/// A profile's screen as `display.status` reports it. A field the server did
/// not send is unknown, not an error.
class BotScreenStatus {
  const BotScreenStatus({
    this.supported = false,
    this.installed = false,
    this.missing = const [],
    this.running = false,
    this.geometry,
    this.placement = 'gateway',
    this.installCommand,
    this.blocker,
    this.memoryAvailableMb,
    this.profileKey,
    this.lease = const BotScreenLease(),
  });

  factory BotScreenStatus.fromJson(Map<String, Object?> json) {
    String? text(String key) =>
        json[key] is String ? json[key] as String : null;
    bool flag(String key) => json[key] == true;
    final missing = json['missing'];
    final memory = json['memory_available_mb'];
    return BotScreenStatus(
      supported: flag('supported'),
      installed: flag('installed'),
      missing: missing is List
          ? missing.whereType<String>().toList()
          : const [],
      running: flag('running'),
      geometry: text('geometry'),
      placement: text('placement') ?? 'gateway',
      installCommand: text('install_command'),
      blocker: text('blocker'),
      memoryAvailableMb: memory is num ? memory.toInt() : null,
      profileKey: text('profile_key'),
      lease: BotScreenLease.fromJson(json['lease']),
    );
  }

  /// This status with [lease] in place of its own, as a `display.lease`
  /// broadcast changes it.
  BotScreenStatus withLease(BotScreenLease lease) => BotScreenStatus(
    supported: supported,
    installed: installed,
    missing: missing,
    running: running,
    geometry: geometry,
    placement: placement,
    installCommand: installCommand,
    blocker: blocker,
    memoryAvailableMb: memoryAvailableMb,
    profileKey: profileKey,
    lease: lease,
  );

  final bool supported;
  final bool installed;

  /// The packages the desktop still needs.
  final List<String> missing;
  final bool running;

  /// The screen's size as `WIDTHxHEIGHT`.
  final String? geometry;

  /// `gateway` for the server itself, else the terminal backend's sandbox.
  final String placement;

  /// Kept for display only; never logged.
  final String? installCommand;

  /// Why the screen cannot start; kept for display only, never logged.
  final String? blocker;
  final int? memoryAvailableMb;

  /// The profile's `HERMES_HOME` path, used only to match broadcasts in
  /// memory; never shown or logged.
  final String? profileKey;
  final BotScreenLease lease;
}

/// What `display.observe` answered: the single-use [ticket] for the display
/// stream (valid for 30 seconds), its [path], the [viewerId] the server minted
/// for this gateway connection and the screen's [status].
///
/// The ticket and the id are credentials. They are kept in memory only, and a
/// printed observation shows neither.
class BotScreenObservation {
  const BotScreenObservation({
    required this.ticket,
    required this.path,
    required this.viewerId,
    required this.status,
  });

  final String ticket;
  final String path;
  final String viewerId;
  final BotScreenStatus status;

  @override
  String toString() => 'BotScreenObservation()';
}

/// What `display.thumbnail` answered.
sealed class BotScreenFrame {
  const BotScreenFrame();
}

/// A JPEG of the screen.
class BotScreenJpeg extends BotScreenFrame {
  const BotScreenJpeg(this.bytes);

  final Uint8List bytes;
}

/// No picture is sent because a person holds control and the frame could show
/// what they type.
class BotScreenSuppressed extends BotScreenFrame {
  const BotScreenSuppressed(this.reason);

  final String reason;
}

/// No picture because the screen is not running.
class BotScreenStopped extends BotScreenFrame {
  const BotScreenStopped();
}

/// Why a display call failed. The slug is the `error_type` of the log event.
enum BotScreenFailure {
  /// Hermes answered with an error, or with an answer that could not be read.
  display('display_error'),

  /// No answer within the display timeout.
  timeout('timeout'),

  /// The connection closed or could not be opened.
  closed('closed');

  const BotScreenFailure(this.slug);

  final String slug;
}

/// The outcome of a display call. Callers get one of these, never an
/// exception.
sealed class BotScreenResult<T> {
  const BotScreenResult();
}

class BotScreenOk<T> extends BotScreenResult<T> {
  const BotScreenOk(this.value);

  final T value;
}

/// The server answered method-not-found: it has no Bot Screen feature.
class BotScreenUnsupported<T> extends BotScreenResult<T> {
  const BotScreenUnsupported();
}

class BotScreenFailed<T> extends BotScreenResult<T> {
  const BotScreenFailed(this.kind, {this.message});

  final BotScreenFailure kind;

  /// Hermes' own words when it answered with an error. Shown, never logged.
  final String? message;
}

/// What `display.install` answered when it started an install.
class BotScreenInstallStart {
  const BotScreenInstallStart({
    this.command,
    required this.profileKey,
    this.connection,
  });

  /// The package manager command Hermes runs; shown, never logged.
  final String? command;

  /// The profile's `HERMES_HOME` path the install broadcasts carry; matched
  /// in memory only, never shown or logged.
  final String profileKey;

  /// The connection that carried the call, which is the only one the sudo
  /// request of this install arrives on; null when the repository was given
  /// no way to tell.
  final Object? connection;
}

/// The state the Bot screen card last recorded as shown, so a card that
/// mounts again (a reopened panel, another chat) does not record it twice. One
/// per controller.
class BotScreenShown {
  String? slug;
}

/// What the viewer shows.
enum BotScreenViewerPhase {
  /// Asking for a ticket, opening the socket or waiting for the first picture.
  connecting,

  /// The picture arrives.
  live,

  /// The stream ended and is being opened again; the last picture is dimmed.
  reconnecting,

  /// A person other than this device holds control, so there is no picture.
  blanked,

  /// The screen is not running.
  off,

  /// Hermes does not let this app view the screen (HTTP 403).
  notAllowed,

  /// The stream could not be opened again, after all attempts.
  unreachable,

  /// The stream ended for a reason retrying does not fix: a protocol error or
  /// a ticket that kept being refused.
  failed,
}
