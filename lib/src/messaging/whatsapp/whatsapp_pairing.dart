/// The types of the WhatsApp pairing routes: what the repository returns and
/// what it throws. A controller switches over [WhatsAppPairingState] and
/// [WhatsAppPairingFailureKind].
///
/// The pairing id and the QR text are credentials, and the account is a
/// person's phone number: each of them prints as a fixed string, and no
/// failure, state or snapshot carries a text the server wrote (it can hold
/// paths) or a name the user typed.
library;

/// How the linked WhatsApp account talks to the agent: `bot` or `self-chat`.
enum WhatsAppMode {
  bot('bot'),
  selfChat('self-chat');

  const WhatsAppMode(this.wire);

  /// The value the server reads and writes.
  final String wire;
}

/// The server's id of one pairing. It is a credential: anyone holding it
/// could read the code, so it prints as a fixed string.
class WhatsAppPairingId {
  const WhatsAppPairingId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is WhatsAppPairingId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'WhatsAppPairingId(…)';
}

/// The text a QR code encodes. Linking a device needs only this and a phone,
/// so it prints as a fixed string.
class WhatsAppQrPayload {
  const WhatsAppQrPayload(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is WhatsAppQrPayload && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'WhatsAppQrPayload(…)';
}

/// The account a pairing is linked to, as the bridge reported it. Every field
/// can be missing. [phone] is digits only. Prints as a fixed string.
class WhatsAppLinkedAccount {
  const WhatsAppLinkedAccount({this.id, this.name, this.phone});

  final String? id;
  final String? name;
  final String? phone;

  @override
  bool operator ==(Object other) =>
      other is WhatsAppLinkedAccount &&
      other.id == id &&
      other.name == name &&
      other.phone == phone;

  @override
  int get hashCode => Object.hash(id, name, phone);

  @override
  String toString() => 'WhatsAppLinkedAccount(…)';
}

/// What the server is doing before a code can be shown.
enum WhatsAppWorkStage {
  /// Installing the bridge's packages or preparing Node.
  installing,

  /// The bridge is starting, or waiting has no code yet.
  starting,

  /// A status this app does not know, read as work in progress.
  other,
}

/// Why a pairing ended in `error`, as a fixed category. The server's text can
/// hold its paths and is dropped.
enum WhatsAppFailReason {
  /// Node.js could not be found or prepared.
  nodeUnavailable,

  /// `npm install` of the bridge failed or timed out.
  installFailed,

  /// The bridge script is not on the server.
  bridgeMissing,

  /// The bridge process ended before the pairing completed.
  processExited,

  /// The account was logged out.
  loggedOut,

  /// Any other text, or none.
  other,
}

/// Where one pairing stands.
sealed class WhatsAppPairingState {
  const WhatsAppPairingState();
}

/// Installing or starting; nothing to scan yet. Also what an unknown status
/// reads as.
class WhatsAppWorking extends WhatsAppPairingState {
  const WhatsAppWorking(this.stage);

  final WhatsAppWorkStage stage;

  @override
  bool operator ==(Object other) =>
      other is WhatsAppWorking && other.stage == stage;

  @override
  int get hashCode => stage.hashCode;

  @override
  String toString() => 'WhatsAppWorking(${stage.name})';
}

/// A code to scan. It rotates: each read can carry a new [qr].
class WhatsAppWaitingForScan extends WhatsAppPairingState {
  const WhatsAppWaitingForScan(this.qr);

  final WhatsAppQrPayload qr;

  @override
  bool operator ==(Object other) =>
      other is WhatsAppWaitingForScan && other.qr == qr;

  @override
  int get hashCode => qr.hashCode;

  @override
  String toString() => 'WhatsAppWaitingForScan';
}

/// Linked. At a start this is the "already linked" case: nothing was scanned.
class WhatsAppConnected extends WhatsAppPairingState {
  const WhatsAppConnected(this.account);

  final WhatsAppLinkedAccount account;

  @override
  bool operator ==(Object other) =>
      other is WhatsAppConnected && other.account == account;

  @override
  int get hashCode => account.hashCode;

  @override
  String toString() => 'WhatsAppConnected';
}

/// The bridge or the server gave up; see [reason].
class WhatsAppPairingFailed extends WhatsAppPairingState {
  const WhatsAppPairingFailed(this.reason);

  final WhatsAppFailReason reason;

  @override
  bool operator ==(Object other) =>
      other is WhatsAppPairingFailed && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'WhatsAppPairingFailed(${reason.name})';
}

/// The setup's ten minutes ran out (status `expired`, or a 410).
class WhatsAppPairingExpired extends WhatsAppPairingState {
  const WhatsAppPairingExpired();

  @override
  bool operator ==(Object other) => other is WhatsAppPairingExpired;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'WhatsAppPairingExpired';
}

/// A newer setup on the same session folder replaced this one (status
/// `cancelled`; a record the app cancels is dropped, so this is the only way
/// to read it).
class WhatsAppPairingSuperseded extends WhatsAppPairingState {
  const WhatsAppPairingSuperseded();

  @override
  bool operator ==(Object other) => other is WhatsAppPairingSuperseded;

  @override
  int get hashCode => 2;

  @override
  String toString() => 'WhatsAppPairingSuperseded';
}

/// One read of a pairing: its [state] and the fixed deadline of the setup
/// (null when the server's time did not parse).
class WhatsAppPairingSnapshot {
  const WhatsAppPairingSnapshot({required this.state, this.expiresAt});

  final WhatsAppPairingState state;
  final DateTime? expiresAt;

  @override
  String toString() => 'WhatsAppPairingSnapshot($state)';
}

/// A started pairing: its [id] and the first read.
class WhatsAppPairingStart {
  const WhatsAppPairingStart({required this.id, required this.snapshot});

  final WhatsAppPairingId id;
  final WhatsAppPairingSnapshot snapshot;

  @override
  String toString() => 'WhatsAppPairingStart(${snapshot.state})';
}

/// What an answered apply came to.
class WhatsAppApplyResult {
  const WhatsAppApplyResult({
    required this.confirmed,
    required this.restartStarted,
    required this.needsRestart,
  });

  /// The server said `ok: true`. A 200 without it leaves the save unknown.
  final bool confirmed;

  /// A `hermes gateway restart` child was spawned. That does not mean the
  /// gateway restarted: the child can still refuse.
  final bool restartStarted;

  /// The messaging gateway still has to be restarted by the user.
  final bool needsRestart;

  @override
  String toString() =>
      'WhatsAppApplyResult(confirmed: $confirmed, restartStarted: '
      '$restartStarted, needsRestart: $needsRestart)';
}

enum WhatsAppPairingFailureKind {
  /// 400, or an id or profile the app refused to send.
  badRequest,

  /// 422: the body was refused.
  validation,

  /// 404 naming the profile: it was deleted.
  profileGone,

  /// On start: any other 404, or a 405; the server has no such route.
  unsupported,

  /// 404 on a read or apply: the record is gone (dropped after 900 s, a
  /// dashboard restart, or an apply that already succeeded).
  recordGone,

  /// 409: apply before the pairing is connected.
  notConnected,

  /// 410: the setup expired.
  expired,

  /// 5xx.
  server,

  /// A 200 whose body cannot be read.
  malformed,

  /// A read or cancel got no answer.
  unreachable,

  /// A start or apply got no answer: it may or may not have gone through.
  /// Nothing is resent.
  lostAnswer,

  /// Any other status.
  unexpected,
}

/// A refused or unanswered pairing request. Carries a kind and a fixed line,
/// never the response body.
class WhatsAppPairingFailure implements Exception {
  const WhatsAppPairingFailure(this.kind);

  final WhatsAppPairingFailureKind kind;

  String get message => switch (kind) {
    WhatsAppPairingFailureKind.badRequest => 'The server refused the request.',
    WhatsAppPairingFailureKind.validation => 'The server refused the values.',
    WhatsAppPairingFailureKind.profileGone => 'The profile no longer exists.',
    WhatsAppPairingFailureKind.unsupported =>
      'The server cannot link WhatsApp this way.',
    WhatsAppPairingFailureKind.recordGone => 'The setup is no longer there.',
    WhatsAppPairingFailureKind.notConnected => 'WhatsApp is not linked yet.',
    WhatsAppPairingFailureKind.expired => 'The setup expired.',
    WhatsAppPairingFailureKind.server => 'Hermes reported a problem.',
    WhatsAppPairingFailureKind.malformed =>
      'The server sent an answer the app cannot read.',
    WhatsAppPairingFailureKind.unreachable => 'The server did not answer.',
    WhatsAppPairingFailureKind.lostAnswer =>
      'The request may have gone through.',
    WhatsAppPairingFailureKind.unexpected =>
      'The server answered unexpectedly.',
  };

  @override
  String toString() => 'WhatsAppPairingFailure(${kind.name})';
}

/// The fixed category of an `error` text. The text is read here and dropped.
WhatsAppFailReason whatsAppFailReason(Object? text) {
  final lower = text is String ? text.toLowerCase() : '';
  if (lower.contains('node.js')) return WhatsAppFailReason.nodeUnavailable;
  if (lower.contains('npm install') || lower.contains('bridge dependencies')) {
    return WhatsAppFailReason.installFailed;
  }
  if (lower.contains('bridge script')) return WhatsAppFailReason.bridgeMissing;
  if (lower.contains('logged out') || lower.contains('logged_out')) {
    return WhatsAppFailReason.loggedOut;
  }
  if (lower.contains('pairing process exited')) {
    return WhatsAppFailReason.processExited;
  }
  return WhatsAppFailReason.other;
}
