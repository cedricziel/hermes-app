import 'package:dio/dio.dart';

import '../../api/missing_profile_detail.dart';
import 'whatsapp_pairing.dart';

/// Which of the four routes a request went to; the same status means
/// different things on each.
enum WhatsAppRoute { start, status, apply, cancel }

/// A name or id that may go into a request: not empty, not a dot name, and
/// without a character that would leave its path segment or a query value
/// (`/`, `\`, `?`, `#`, `%`), a space or a control character.
///
/// The generated client pastes path parameters in unencoded, and the server
/// decodes `%2F` back to `/` (recorded: that reaches another route's 404), so
/// such a value is refused instead of encoded. Hermes' own ids are url-safe
/// base64 and its profile names lowercase letters, digits, `-` and `_`.
bool isSafeWhatsAppToken(String value) =>
    value.isNotEmpty &&
    value != '.' &&
    value != '..' &&
    !RegExp(r'[/\\?#%\s\x00-\x1f\x7f]').hasMatch(value);

/// The failure for [error], or null for a 401, which stays a [DioException]
/// for the sign-in path.
///
/// A request with no answer is `lostAnswer` on a write ([writes]: start and
/// apply, which may have gone through) and `unreachable` on a read.
WhatsAppPairingFailure? whatsAppFailureFor(
  DioException error,
  WhatsAppRoute route,
) {
  final write = route == WhatsAppRoute.start || route == WhatsAppRoute.apply;
  final response = error.response;
  if (response == null) {
    return WhatsAppPairingFailure(
      write
          ? WhatsAppPairingFailureKind.lostAnswer
          : WhatsAppPairingFailureKind.unreachable,
    );
  }
  final status = response.statusCode ?? 0;
  if (status == 401) return null;
  final detail = response.data is Map ? (response.data as Map)['detail'] : null;
  final shown =
      (route == WhatsAppRoute.start || route == WhatsAppRoute.apply) &&
          (status == 400 || status == 409 || status == 500) &&
          detail is String &&
          detail.isNotEmpty
      ? WhatsAppServerText(detail)
      : null;
  return WhatsAppPairingFailure(serverText: shown, switch (status) {
    404 => switch (route) {
      WhatsAppRoute.start =>
        namesMissingProfile(response.data)
            ? WhatsAppPairingFailureKind.profileGone
            : WhatsAppPairingFailureKind.unsupported,
      WhatsAppRoute.apply =>
        namesMissingProfile(response.data)
            ? WhatsAppPairingFailureKind.profileGone
            : WhatsAppPairingFailureKind.recordGone,
      WhatsAppRoute.status ||
      WhatsAppRoute.cancel => WhatsAppPairingFailureKind.recordGone,
    },
    405 => WhatsAppPairingFailureKind.unsupported,
    400 => WhatsAppPairingFailureKind.badRequest,
    409 => WhatsAppPairingFailureKind.notConnected,
    410 => WhatsAppPairingFailureKind.expired,
    422 => WhatsAppPairingFailureKind.validation,
    >= 500 && < 600 => WhatsAppPairingFailureKind.server,
    _ => WhatsAppPairingFailureKind.unexpected,
  });
}

/// The state a `status` string and the rest of the payload make. An unknown
/// status is work in progress; the server's `error` text gives the category
/// and rides along, hidden, for the screen.
WhatsAppPairingState whatsAppStateFrom(Map<Object?, Object?> body) {
  final status = body['status'];
  switch (status) {
    case 'installing':
      return const WhatsAppWorking(WhatsAppWorkStage.installing);
    case 'starting':
      return const WhatsAppWorking(WhatsAppWorkStage.starting);
    case 'waiting':
      final qr = body['qr_payload'];
      return qr is String && qr.isNotEmpty
          ? WhatsAppWaitingForScan(WhatsAppQrPayload(qr))
          : const WhatsAppWorking(WhatsAppWorkStage.starting);
    case 'connected':
      String? text(String key) =>
          body[key] is String ? body[key] as String : null;
      return WhatsAppConnected(
        WhatsAppLinkedAccount(
          id: text('account_id'),
          name: text('account_name'),
          phone: text('account_phone'),
        ),
      );
    case 'error':
      final error = body['error'];
      return WhatsAppPairingFailed(
        whatsAppFailReason(error),
        serverText: error is String && error.isNotEmpty
            ? WhatsAppServerText(error)
            : null,
      );
    case 'expired':
      return const WhatsAppPairingExpired();
    case 'cancelled':
      return const WhatsAppPairingSuperseded();
    default:
      return const WhatsAppWorking(WhatsAppWorkStage.other);
  }
}

/// A snapshot of a payload, or null when [data] is not an object.
WhatsAppPairingSnapshot? whatsAppSnapshotFrom(Object? data) {
  if (data is! Map) return null;
  final expires = data['expires_at'];
  return WhatsAppPairingSnapshot(
    state: whatsAppStateFrom(data),
    expiresAt: expires is String ? DateTime.tryParse(expires)?.toUtc() : null,
  );
}

/// The apply result of a 200 body, lenient about missing fields.
WhatsAppApplyResult whatsAppApplyResultFrom(Object? data) {
  final body = data is Map ? data : const {};
  final started = body['restart_started'] == true;
  final needs = body['needs_restart'];
  return WhatsAppApplyResult(
    confirmed: body['ok'] == true,
    restartStarted: started,
    needsRestart: needs is bool ? needs : !started,
  );
}
