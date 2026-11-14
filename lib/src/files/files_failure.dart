import 'dart:io';

import 'package:dio/dio.dart';

/// Why a Files request did not give what it was asked for. This is all a
/// caller learns about a failure: the request's address and path, which a
/// [DioException] carries, never leave the code that maps it.
enum FilesFailure {
  /// 404, ENOENT, or a missing folder on an SSH workspace.
  missing,

  /// 403, EACCES, or the boundary of a locked deployment.
  notAllowed,

  /// 400 for a directory or something that is not a regular file, or
  /// ENOTDIR for a file asked for as a folder.
  notAFile,

  /// 409: a database Hermes has open right now.
  busy,

  /// 413.
  tooLarge,

  /// 503 or ECONN: the profile's SSH workspace is down.
  workspaceDown,

  /// 502, a timeout or no network.
  unreachable,

  /// Anything else, including an answer that is not the shape Hermes sends.
  unreadable,

  /// A 400 on a folder, an invalid profile name, or a 404 for a profile the
  /// server does not have.
  badRequest,

  /// The path lies outside the folder this page is confined to; nothing was
  /// requested.
  outside,

  /// The caller cancelled the request.
  cancelled;

  /// A fixed name for telemetry.
  String get slug => name;

  /// Whether asking again can help.
  bool get retryable =>
      this == unreachable || this == workspaceDown || this == busy;
}

/// The kind for an HTTP [status] and the `detail` string of its body, if any.
///
/// [fileRoute] is true for a route that reads one file: there a 400 about a
/// directory or a file that is not regular is [FilesFailure.notAFile], while
/// any other 400 is the server not accepting the request.
FilesFailure filesFailureForStatus(
  int? status,
  String? detail, {
  bool fileRoute = false,
}) {
  switch (status) {
    case 400:
      final lower = detail?.toLowerCase() ?? '';
      final notAFile =
          lower.contains('directory') || lower.contains('regular file');
      return fileRoute && notAFile
          ? FilesFailure.notAFile
          : FilesFailure.badRequest;
    case 403:
      return FilesFailure.notAllowed;
    case 404:
      return (detail ?? '').startsWith("Profile '")
          ? FilesFailure.badRequest
          : FilesFailure.missing;
    case 409:
      return FilesFailure.busy;
    case 413:
      return FilesFailure.tooLarge;
    case 502:
    case 504:
      return FilesFailure.unreachable;
    case 503:
      return FilesFailure.workspaceDown;
    default:
      return FilesFailure.unreadable;
  }
}

/// The kind for the `error` code of a listing Hermes answered with 200.
FilesFailure filesFailureForListError(String code) =>
    switch (code.toUpperCase()) {
      'ENOENT' => FilesFailure.missing,
      'ENOTDIR' => FilesFailure.notAFile,
      'EACCES' || 'EPERM' => FilesFailure.notAllowed,
      'ECONN' => FilesFailure.workspaceDown,
      _ => FilesFailure.unreadable,
    };

/// The `detail` of an error body Dio already decoded, if it is a string.
String? errorDetail(Object? data) {
  if (data is Map && data['detail'] is String) return data['detail'] as String;
  return null;
}

/// The kind for a failed request, built from its type, status and `detail`
/// only. [error] is never read for text, so the URI it holds cannot escape.
FilesFailure filesFailureForDio(DioException error, {bool fileRoute = false}) =>
    switch (error.type) {
      DioExceptionType.cancel => FilesFailure.cancelled,
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.transformTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => FilesFailure.unreachable,
      DioExceptionType.badResponse => filesFailureForStatus(
        error.response?.statusCode,
        errorDetail(error.response?.data),
        fileRoute: fileRoute,
      ),
      DioExceptionType.unknown =>
        error.error is IOException
            ? FilesFailure.unreachable
            : FilesFailure.unreadable,
    };

/// A download that ended without a complete file. It carries the kind and
/// nothing else, not the request's address or path.
class FsDownloadException implements Exception {
  const FsDownloadException(this.kind);

  final FilesFailure kind;

  @override
  String toString() => 'FsDownloadException(${kind.slug})';
}
