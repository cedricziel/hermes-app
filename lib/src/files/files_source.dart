import 'dart:io';

import 'package:dio/dio.dart';

import 'files_models.dart';
import 'server_path.dart';

/// What the Files controller asks of the server, so a test can answer it
/// without one. [HermesFilesRepository] is the real thing.
abstract interface class FilesSource {
  /// The folder this page may not leave, once known.
  ServerPath? highestFolder;

  Future<FilesResult<ServerPath>> defaultCwd({CancelToken? cancelToken});

  Future<FilesResult<ServerPath?>> gitRoot(
    ServerPath path, {
    CancelToken? cancelToken,
  });

  Future<FilesResult<FsListing>> list(
    ServerPath path, {
    CancelToken? cancelToken,
  });

  Future<FilesResult<FsTextFile>> readText(
    ServerPath path, {
    CancelToken? cancelToken,
  });

  Future<FilesResult<FsDownload>> download(
    ServerPath path, {
    required IOSink sink,
    CancelToken? cancelToken,
    void Function(int received, int? total)? onProgress,
    bool allowLarge = false,
  });
}
