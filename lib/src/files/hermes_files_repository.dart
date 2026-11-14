import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../api/hermes_api_client.dart';
import '../surfaces/surface_snapshot.dart' show kDefaultProfile;
import 'files_failure.dart';
import 'files_models.dart';
import 'files_source.dart';
import 'files_telemetry.dart';
import 'server_path.dart';

/// From this many announced bytes a download asks first (design: 50 MB).
const kLargeDownloadBytes = 50 * 1024 * 1024;

/// Reads a chat's working folder from the server over `/api/fs/*`: the
/// folder listing, a file's text and a streamed download.
///
/// Every request names its [profile] (`default` for none) except [probe].
/// Paths are only ever the absolute ones the server returned, passed to the
/// generated client as query parameters, never joined into a URL, and with
/// [highestFolder] set none outside it is requested. Responses are untyped
/// JSON, so parsing is lenient: a row that does not fit is skipped.
///
/// Calls return a [FilesResult] and never throw. A failed request is mapped
/// to a [FilesFailure] from its status and `detail` alone: the [DioException]
/// holds the request's URI, and so the path, and is dropped here, so no span,
/// log, breadcrumb or message downstream can carry either.
class HermesFilesRepository implements FilesSource {
  HermesFilesRepository(
    this._client, {
    String? profile,
    FilesTelemetry? telemetry,
    this.idleTimeout = const Duration(seconds: 30),
  }) : profile = profile ?? kDefaultProfile,
       _telemetry = telemetry ?? FilesTelemetry();

  final HermesApiClient _client;
  final String profile;
  final FilesTelemetry _telemetry;

  /// How long a download may go without a chunk.
  final Duration idleTimeout;

  /// The folder this page may not leave, once known. Set it before the first
  /// list, read or download below it.
  @override
  ServerPath? highestFolder;

  /// Whether the server has the `/api/fs` routes, by `GET /api/fs/default-cwd`
  /// sent without `profile` (a profile the server lacks also answers 404).
  /// What it answers is thrown away: the folder belongs to whichever profile
  /// is active on the server. 404 and 405 are [FilesUnsupported], logged once
  /// per [FilesTelemetry]; any other failure is not "unsupported".
  Future<FilesResult<void>> probe({CancelToken? cancelToken}) async {
    final result = await _get<void>(
      () =>
          _client.raw.fsDefaultCwdApiFsDefaultCwdGet(cancelToken: cancelToken),
      (_) => const FilesOk(null),
      unsupportedOnMissing: true,
    );
    if (result is FilesUnsupported) _telemetry.unsupported();
    return result;
  }

  /// `GET /api/fs/default-cwd?profile=`: the start folder of a chat that has
  /// no stored folder yet. A local profile gets the dashboard's own folder.
  @override
  Future<FilesResult<ServerPath>> defaultCwd({CancelToken? cancelToken}) =>
      _get(
        () => _client.raw.fsDefaultCwdApiFsDefaultCwdGet(
          profile: profile,
          cancelToken: cancelToken,
        ),
        (body) => _pathAt(body, 'cwd'),
        unsupportedOnMissing: true,
      );

  /// `GET /api/fs/git-root`: the repository root above [path], or null.
  @override
  Future<FilesResult<ServerPath?>> gitRoot(
    ServerPath path, {
    CancelToken? cancelToken,
  }) {
    if (_outside(path)) {
      return Future.value(const FilesFailed(FilesFailure.outside));
    }
    return _get(
      () => _client.raw.fsGitRootApiFsGitRootGet(
        path: path.value,
        profile: profile,
        cancelToken: cancelToken,
      ),
      (body) {
        if (body is! Map) return const FilesFailed(FilesFailure.unreadable);
        final root = body['root'];
        if (root == null) return const FilesOk(null);
        final parsed = root is String ? ServerPath.tryParse(root) : null;
        return parsed == null
            ? const FilesFailed(FilesFailure.unreadable)
            : FilesOk(parsed);
      },
    );
  }

  /// `GET /api/fs/list`: the entries of [path]. A 200 with an `error` code is
  /// a failure, never an empty folder.
  @override
  Future<FilesResult<FsListing>> list(
    ServerPath path, {
    CancelToken? cancelToken,
  }) async {
    if (_outside(path)) {
      return const FilesFailed(FilesFailure.outside);
    }
    final span = _telemetry.startList();
    final result = await _get(
      () => _client.raw.fsListApiFsListGet(
        path: path.value,
        profile: profile,
        cancelToken: cancelToken,
      ),
      _parseListing,
    );
    switch (result) {
      case FilesOk(:final value):
        _telemetry.endList(span, null, entries: value.entries.length);
      case FilesFailed(:final kind):
        _telemetry.endList(span, kind);
        if (kind != FilesFailure.cancelled) _telemetry.listFailed(kind);
      case FilesUnsupported():
        _telemetry.endList(span, FilesFailure.unreadable);
    }
    return result;
  }

  /// `GET /api/fs/read-text`: up to 512 KB of [path] as text.
  @override
  Future<FilesResult<FsTextFile>> readText(
    ServerPath path, {
    CancelToken? cancelToken,
  }) {
    if (_outside(path)) {
      return Future.value(const FilesFailed(FilesFailure.outside));
    }
    return _get(
      () => _client.raw.fsReadTextApiFsReadTextGet(
        path: path.value,
        profile: profile,
        cancelToken: cancelToken,
      ),
      _parseText,
      fileRoute: true,
    );
  }

  /// `GET /api/fs/download`: streams [path] into [sink] through
  /// [HermesApiClient.downloadFsFile]. The caller closes [sink] and deletes a
  /// partial file on any result but [FilesOk] with [FsDownload.bytes] fully
  /// written.
  ///
  /// With an announced length from [kLargeDownloadBytes] up and [allowLarge]
  /// false, it stops after the headers and answers a [FsDownload] with
  /// `declined` set and the length, so the page can ask first.
  @override
  Future<FilesResult<FsDownload>> download(
    ServerPath path, {
    required IOSink sink,
    CancelToken? cancelToken,
    void Function(int received, int? total)? onProgress,
    bool allowLarge = false,
  }) async {
    if (_outside(path)) {
      return const FilesFailed(FilesFailure.outside);
    }
    final span = _telemetry.startDownload();
    int? announced;
    var received = 0;
    try {
      final done = await _client.downloadFsFile(
        path.value,
        profile: profile,
        sink: sink,
        cancelToken: cancelToken,
        idleTimeout: idleTimeout,
        onProgress: (bytes, total) {
          received = bytes;
          onProgress?.call(bytes, total);
        },
        onHeaders: (length) {
          announced = length;
          return allowLarge || length == null || length < kLargeDownloadBytes;
        },
      );
      _telemetry.endDownload(
        span,
        done.declined
            ? FilesDownloadOutcome.tooLarge
            : FilesDownloadOutcome.done,
        bytes: done.contentLength ?? done.bytes,
        lengthKnown: done.contentLength != null,
      );
      return FilesOk(done);
    } on FsDownloadException catch (error) {
      final kind = error.kind;
      _telemetry.endDownload(
        span,
        kind == FilesFailure.cancelled
            ? FilesDownloadOutcome.cancelled
            : FilesDownloadOutcome.failed,
        bytes: announced ?? received,
        lengthKnown: announced != null,
      );
      if (kind != FilesFailure.cancelled) _telemetry.downloadFailed(kind);
      return FilesFailed(kind);
    }
  }

  bool _outside(ServerPath path) {
    final highest = highestFolder;
    return highest != null && !path.isWithin(highest);
  }

  Future<FilesResult<T>> _get<T>(
    Future<Response<Object>> Function() request,
    FilesResult<T> Function(Object? body) parse, {
    bool fileRoute = false,
    bool unsupportedOnMissing = false,
  }) async {
    try {
      final response = await request();
      return parse(response.data);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final kind = filesFailureForDio(error, fileRoute: fileRoute);
      if (unsupportedOnMissing &&
          (status == 405 || (status == 404 && kind == FilesFailure.missing))) {
        return const FilesUnsupported();
      }
      return FilesFailed(kind);
    } on Object {
      // A body the generated client could not read, or a parser slip.
      return const FilesFailed(FilesFailure.unreadable);
    }
  }

  FilesResult<ServerPath> _pathAt(Object? body, String key) {
    final text = body is Map ? body[key] : null;
    final path = text is String ? ServerPath.tryParse(text) : null;
    return path == null
        ? const FilesFailed(FilesFailure.unreadable)
        : FilesOk(path);
  }

  FilesResult<FsListing> _parseListing(Object? body) {
    if (body is! Map) return const FilesFailed(FilesFailure.unreadable);
    final error = body['error'];
    if (error is String && error.isNotEmpty) {
      return FilesFailed(filesFailureForListError(error));
    }
    // `null`, `false` and an empty string say there was no error.
    if (error != null && error != false && error != '') {
      return const FilesFailed(FilesFailure.unreadable);
    }
    final rows = body['entries'];
    if (rows is! List) return const FilesFailed(FilesFailure.unreadable);
    final entries = <FsEntry>[];
    var skipped = 0;
    var outside = 0;
    for (final row in rows) {
      final name = row is Map ? row['name'] : null;
      final text = row is Map ? row['path'] : null;
      final path = text is String ? ServerPath.tryParse(text) : null;
      if (name is! String || name.isEmpty || path == null) {
        skipped++;
        continue;
      }
      if (_outside(path)) {
        skipped++;
        outside++;
        continue;
      }
      entries.add(
        FsEntry(
          name: name,
          path: path,
          isDirectory: (row as Map)['isDirectory'] == true,
        ),
      );
    }
    return FilesOk(
      FsListing(entries: entries, skipped: skipped, skippedOutside: outside),
    );
  }

  FilesResult<FsTextFile> _parseText(Object? body) {
    if (body is! Map) return const FilesFailed(FilesFailure.unreadable);
    final binary = body['binary'] == true;
    final text = body['text'];
    if (text is! String && !binary) {
      return const FilesFailed(FilesFailure.unreadable);
    }
    final size = body['byteSize'];
    final fallbackSize = text is String ? utf8.encode(text).length : 0;
    final language = body['language'];
    final mime = body['mimeType'];
    return FilesOk(
      FsTextFile(
        text: text is String ? text : '',
        byteSize: size is num ? size.toInt() : fallbackSize,
        truncated: body['truncated'] == true,
        binary: binary,
        language: language is String && language.isNotEmpty ? language : null,
        mimeType: mime is String && mime.isNotEmpty ? mime : null,
      ),
    );
  }
}
