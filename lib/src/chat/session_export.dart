import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'widgets/session_export_failure.dart';

/// What a decoded chat export holds, for the telemetry bucket and nothing else.
typedef SessionExportFile = ({int messageCount});

/// The body is not a whole session: it stopped short or has the wrong shape.
/// Carries no text on purpose: a [FormatException] from `jsonDecode` embeds a
/// slice of the file, which must reach no log, crash report or message.
class SessionExportIncomplete implements Exception {
  const SessionExportIncomplete();

  @override
  String toString() => 'SessionExportIncomplete';
}

const _isolateAbove = 1024 * 1024;

/// Checks that [bytes] are a whole session (an object with a string `id` and a
/// list `messages`) and counts its messages. Throws [SessionExportIncomplete]
/// otherwise. Decodes in an isolate above 1 MB.
Future<SessionExportFile> decodeSessionExport(Uint8List bytes) async {
  final count = bytes.length > _isolateAbove
      ? await Isolate.run(() => _messageCount(bytes))
      : _messageCount(bytes);
  if (count < 0) throw const SessionExportIncomplete();
  return (messageCount: count);
}

/// The number of messages, or -1 for anything that is not a whole session.
/// Never throws, so no error text crosses the isolate.
int _messageCount(Uint8List bytes) {
  try {
    final root = jsonDecode(utf8.decode(bytes));
    if (root is Map && root['id'] is String && root['messages'] is List) {
      return (root['messages'] as List).length;
    }
  } on Object {
    // Deliberately dropped: a FormatException's message holds file content.
  }
  return -1;
}

/// The failure kind for a failed export request, from its type, status and
/// `detail` only. Nothing of [error] (its URI, message or body) is kept.
/// [receivedAny] says whether a byte of the body arrived before it failed.
SessionExportFailure classifySessionExportError(
  DioException error, {
  required bool receivedAny,
}) => switch (error.type) {
  DioExceptionType.connectionTimeout => SessionExportFailure.lost,
  DioExceptionType.receiveTimeout =>
    receivedAny ? SessionExportFailure.incomplete : SessionExportFailure.lost,
  DioExceptionType.connectionError => SessionExportFailure.offline,
  DioExceptionType.badResponse => _forStatus(error.response),
  _ => SessionExportFailure.failed,
};

SessionExportFailure _forStatus(Response<dynamic>? response) {
  final status = response?.statusCode;
  if (status == 503) return SessionExportFailure.unreadable;
  if (status == 400) return SessionExportFailure.profileInvalid;
  if (status == 405) return SessionExportFailure.unsupported;
  if (status != 404) return SessionExportFailure.failed;
  final detail = _detail(response?.data);
  if (detail == 'Session not found') return SessionExportFailure.gone;
  if (detail != null && detail.startsWith("Profile '")) {
    return SessionExportFailure.profileMissing;
  }
  return SessionExportFailure.unsupported;
}

/// The `detail` string of an error body, which arrives as bytes because the
/// request asked for bytes.
String? _detail(Object? data) {
  try {
    final decoded = data is List<int>
        ? jsonDecode(utf8.decode(data, allowMalformed: true))
        : data;
    if (decoded is Map && decoded['detail'] is String) {
      return decoded['detail'] as String;
    }
  } on Object {
    // Not JSON: no detail.
  }
  return null;
}
