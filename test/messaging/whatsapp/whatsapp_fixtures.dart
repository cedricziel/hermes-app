/// Answers of Hermes `d923a5eb` to the four WhatsApp pairing routes under
/// `/api/messaging/whatsapp/onboarding`, for the repository tests. Every name,
/// number, id and code is invented; no real account was linked and nothing
/// contacted WhatsApp. The table in
/// `openspec/changes/whatsapp-onboarding/design.md` ("Recorded answers") says
/// which of these are recorded and which come from the source.
///
/// Each constant says one of:
///
/// - RECORDED: a throwaway dashboard (`scripts/dev-backend.sh`, its own
///   `HERMES_HOME`) gave this answer. The random pairing id and the clock
///   times are replaced with invented ones.
/// - FROM SOURCE, NOT RECORDED: the server cannot be driven to it without
///   starting the Baileys bridge, which reaches WhatsApp's servers (needs a
///   phone or an account). Written from `hermes_cli/web_routers/messaging.py`
///   and `hermes_cli/web_server_messaging.py`.
///
/// The bridge was never started: Node 22 exists on the recording machine, but
/// the bridge's `node_modules` do not, so a `start` would have run
/// `npm install` and then connected out. "Already linked" was recorded by
/// putting an invented `creds.json` in the throwaway home's session folder,
/// which makes `start` answer `connected` without spawning anything.
library;

const waBase = '/api/messaging/whatsapp/onboarding';
const waStartPath = '$waBase/start';
const waId = 'Zk3-demoPairingId_0001';
const waStatusPath = '$waBase/$waId';
const waApplyPath = '$waBase/$waId/apply';

/// An invented code. A real one is Baileys' `qr` text; this is not scannable.
const waQr = 'DEMO-NOT-A-REAL-QR,AAAA,BBBB,1';
const waPhone = '15555550123';
const waAccountId = '$waPhone:7@s.whatsapp.net';
const waAccountName = 'Test Account';
const waExpiresAt = '2026-11-15T12:10:00.000000Z';

Map<String, Object?> _payload({
  String id = waId,
  required String status,
  String? qr,
  String mode = 'bot',
  String allowedUsers = '',
  String? accountId,
  String? accountName,
  String? accountPhone,
  String? error,
}) => {
  'pairing_id': id,
  'status': status,
  'qr_payload': qr,
  'expires_at': waExpiresAt,
  'mode': mode,
  'allowed_users': allowedUsers,
  'account_id': accountId,
  'account_name': accountName,
  'account_phone': accountPhone,
  'error': error,
};

/// RECORDED (start with an invented `creds.json` in the session folder):
/// already linked, `connected` at once. Note the server's normalised
/// `allowed_users` ("+1 555 555 0100, 15555550101" became
/// "+15555550100,15555550101").
final waStartAlreadyLinked = _payload(
  status: 'connected',
  allowedUsers: '+15555550100,15555550101',
  accountId: waAccountId,
  accountName: waAccountName,
  accountPhone: waPhone,
);

/// RECORDED: the same record read with GET.
final waStatusConnected = waStartAlreadyLinked;

/// RECORDED: `self-chat` start on the same linked folder, no numbers given.
final waStartAlreadyLinkedSelfChat = _payload(
  status: 'connected',
  mode: 'self-chat',
  accountId: waAccountId,
  accountName: waAccountName,
  accountPhone: waPhone,
);

/// FROM SOURCE, NOT RECORDED: start on a folder with no credentials. The
/// route returns before the thread runs, so the first answer is `starting`
/// (the record's default status) with no code.
final waStartFresh = _payload(status: 'starting');

/// FROM SOURCE, NOT RECORDED: the thread is running `npm install` or looking
/// for Node.
final waStatusInstalling = _payload(status: 'installing');

/// FROM SOURCE, NOT RECORDED: the bridge was spawned and has not emitted a
/// code yet.
final waStatusStarting = _payload(status: 'starting');

/// FROM SOURCE, NOT RECORDED: the bridge emitted a `qr` event.
final waStatusWaiting = _payload(status: 'waiting', qr: waQr);

/// FROM SOURCE, NOT RECORDED: the code rotated (a new `qr` event).
final waStatusWaitingRotated = _payload(
  status: 'waiting',
  qr: 'DEMO-NOT-A-REAL-QR,CCCC,DDDD,2',
);

/// FROM SOURCE, NOT RECORDED: the phone scanned the code (a `connected`
/// event of the bridge).
final waStatusConnectedAfterScan = _payload(
  status: 'connected',
  accountId: waAccountId,
  accountName: waAccountName,
  accountPhone: waPhone,
);

/// FROM SOURCE, NOT RECORDED: a status this app does not know yet.
final waStatusUnknown = _payload(status: 'reconnecting-soon');

/// FROM SOURCE, NOT RECORDED: Node could not be prepared. The text can hold
/// the server's paths; the app never keeps it.
final waStatusErrorNode = _payload(
  status: 'error',
  error: '500: Node.js preparation failed: no network at /srv/hermes/node',
);

/// FROM SOURCE, NOT RECORDED: `npm install` failed.
final waStatusErrorInstall = _payload(
  status: 'error',
  error:
      'npm install failed for WhatsApp bridge: ENOENT /srv/hermes/'
      'scripts/whatsapp-bridge',
);

/// FROM SOURCE, NOT RECORDED: `bridge.js` is missing.
final waStatusErrorBridge = _payload(
  status: 'error',
  error:
      'WhatsApp bridge script was not found at '
      '/srv/hermes/scripts/whatsapp-bridge/bridge.js.',
);

/// FROM SOURCE, NOT RECORDED: the bridge process ended.
final waStatusErrorExited = _payload(
  status: 'error',
  error: 'WhatsApp pairing process exited with code 1.',
);

/// FROM SOURCE, NOT RECORDED: any other text.
final waStatusErrorOther = _payload(
  status: 'error',
  error: 'Something at /srv/x went wrong for +15555550123.',
);

/// FROM SOURCE, NOT RECORDED: a newer start on the same folder replaced this
/// record.
final waStatusSuperseded = _payload(
  status: 'cancelled',
  error: 'Superseded by a newer WhatsApp setup session.',
);

/// FROM SOURCE, NOT RECORDED: a read of an `expired` record is a 410 with this
/// body. A live record past `expires_at` becomes `expired` on the next read.
const waExpiredBody = {
  'detail': 'WhatsApp QR setup expired. Start a new setup.',
};

/// FROM SOURCE, NOT RECORDED: apply answered 200 and the restart child was
/// spawned.
const waApplyRestartStarted = {
  'ok': true,
  'platform': 'whatsapp',
  'needs_restart': false,
  'restart_started': true,
  'restart_action': 'gateway-restart',
  'restart_pid': 4242,
};

/// FROM SOURCE, NOT RECORDED: apply saved but the restart could not be
/// spawned.
const waApplyRestartFailed = {
  'ok': true,
  'platform': 'whatsapp',
  'needs_restart': true,
  'restart_started': false,
  'restart_error': 'could not run /usr/bin/hermes',
};

/// RECORDED: start, status or apply of an id the server does not hold; also
/// what a cancelled or dropped record answers on a read.
const waRecordGone = {
  'detail': 'WhatsApp setup session was not found. Start a new setup.',
};

/// RECORDED: start with a profile that does not exist (404), raised before
/// any record is made.
const waProfileGone = {'detail': "Profile 'ghost' does not exist."};

/// RECORDED: start with an invalid profile name (400). It echoes the name.
const waProfileBadName = {
  'detail':
      "'a b' is not a valid profile name. Use lowercase letters, numbers, "
      "'-' or '_', starting with a letter or number, up to 64 characters "
      '(for example: a-b). Then run `hermes profile create a-b`.',
};

/// RECORDED: start or apply with a mode other than `bot` or `self-chat`
/// (400, before anything is saved or spawned).
const waBadMode = {'detail': "WhatsApp mode must be 'bot' or 'self-chat'."};

/// RECORDED: a body with a wrong type (422, FastAPI's list).
const waValidation = {
  'detail': [
    {
      'type': 'string_type',
      'loc': ['body', 'mode'],
      'msg': 'Input should be a valid string',
      'input': 5,
    },
  ],
};

/// FROM SOURCE, NOT RECORDED: apply before the record is `connected` (409).
const waNotConnected = {'detail': 'WhatsApp setup is not connected yet.'};

/// FROM SOURCE, NOT RECORDED: apply could not save (500).
const waSaveFailed = {'detail': 'Failed to save WhatsApp setup.'};

/// RECORDED: a route this server does not have (an id with `/` in it, which
/// the server decodes from `%2F`, answers this too).
const waRouteMissing = {
  'detail': 'No such API endpoint: /api/messaging/whatsapp/onboarding/a/b',
};

/// RECORDED: DELETE of a known or unknown id.
const waCancelOk = {'ok': true};

/// RECORDED against a password-gated dashboard, no session cookie.
const waUnauthorized = {
  'error': 'unauthenticated',
  'detail': 'Unauthorized',
  'reason': 'no_cookie',
  'login_url': '/login',
};
