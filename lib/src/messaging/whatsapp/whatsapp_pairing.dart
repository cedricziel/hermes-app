/// The types of the WhatsApp pairing routes: what the repository returns and
/// what it throws. A controller switches over [WhatsAppPairingState] and
/// [WhatsAppPairingFailureKind].
///
/// The pairing id and the QR text are credentials, and the account is a
/// person's phone number: each of them prints as a fixed string. The text the
/// server wrote (an `error` or a `detail`; it can hold paths) is kept in a
/// [WhatsAppServerText] for the screen to show as given, and that holder
/// never prints it. No failure, state or snapshot prints a text the server
/// wrote or a name the user typed.
library;

/// A text the server wrote, held for the screen to show as given (it can hold
/// the server's paths and the profile name). It is opaque: [toString] is fixed
/// and [==] and [hashCode] never print or expose it. Read [text] only to
/// draw it on the screen, never to log, report or store it, and drop the
/// holder when the screen closes, App Lock locks or the user signs out.
class WhatsAppServerText {
  const WhatsAppServerText(this.text);

  /// For display only.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is WhatsAppServerText && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'WhatsAppServerText(<hidden>)';
}

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

/// Why a pairing ended in `error`, as a fixed category for the headline. The
/// server's own text travels beside it in a [WhatsAppServerText].
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

/// The bridge or the server gave up; see [reason]. [serverText] is the
/// server's `error` as given, for the screen only (null when it sent none).
/// Equality looks at [reason] alone.
class WhatsAppPairingFailed extends WhatsAppPairingState {
  const WhatsAppPairingFailed(this.reason, {this.serverText});

  final WhatsAppFailReason reason;
  final WhatsAppServerText? serverText;

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

/// A refused or unanswered pairing request. Carries a kind and a fixed line;
/// the `detail` of a 400, 409 or 500 on start or apply rides along in
/// [serverText] for the screen. It never reaches [message] or [toString].
class WhatsAppPairingFailure implements Exception {
  const WhatsAppPairingFailure(this.kind, {this.serverText});

  final WhatsAppPairingFailureKind kind;
  final WhatsAppServerText? serverText;

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

/// The fixed category of an `error` text, matched on the server's own opening
/// words after an optional `<status>: ` prefix (Starlette writes an
/// `HTTPException` as `500: detail`). The text itself is not kept here.
WhatsAppFailReason whatsAppFailReason(Object? text) {
  final lower = (text is String ? text : '').toLowerCase().replaceFirst(
    RegExp(r'^\d+: '),
    '',
  );
  bool starts(String prefix) => lower.startsWith(prefix);
  if (starts('node.js preparation failed')) {
    return WhatsAppFailReason.nodeUnavailable;
  }
  if (starts('npm install failed') ||
      starts('installing whatsapp bridge dependencies') ||
      starts('failed to install whatsapp bridge dependencies')) {
    return WhatsAppFailReason.installFailed;
  }
  if (starts('whatsapp bridge script was not found')) {
    return WhatsAppFailReason.bridgeMissing;
  }
  if (starts('whatsapp pairing process exited')) {
    return WhatsAppFailReason.processExited;
  }
  if (lower.contains('logged out') || lower.contains('logged_out')) {
    return WhatsAppFailReason.loggedOut;
  }
  return WhatsAppFailReason.other;
}
