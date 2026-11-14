import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hermes_app/src/files/files_failure.dart';
import 'package:hermes_app/src/files/files_models.dart';
import 'package:hermes_app/src/files/files_source.dart';
import 'package:hermes_app/src/files/server_path.dart';

/// Answers the Files controller's questions as a test scripts them. Every
/// answer may be held back with a [Completer] to decide the order they arrive
/// in. Each call is recorded as `"<method> <path>"`.
class FakeFilesSource implements FilesSource {
  @override
  ServerPath? highestFolder;

  final calls = <String>[];

  /// The cancel token each call was given, by `"<method> <path>"`.
  final tokens = <String, CancelToken?>{};

  Future<FilesResult<ServerPath>> Function()? onDefaultCwd;
  final gitRoots = <String, Future<FilesResult<ServerPath?>> Function()>{};
  final lists = <String, Future<FilesResult<FsListing>> Function()>{};
  final texts = <String, Future<FilesResult<FsTextFile>> Function()>{};

  /// A download writes what it likes into the sink; the future it returns
  /// ends the request. [CancelToken] lets it end on cancel.
  final downloads =
      <
        String,
        Future<FilesResult<FsDownload>> Function(
          IOSink sink,
          CancelToken? token,
          bool allowLarge,
          void Function(int received, int? total)? onProgress,
        )
      >{};

  int count(String prefix) => calls.where((c) => c.startsWith(prefix)).length;

  Future<T> _answer<T>(
    String call,
    Map<String, Future<T> Function()> from,
    String path,
    CancelToken? token,
  ) {
    calls.add('$call $path');
    tokens['$call $path'] = token;
    final answer = from[path];
    if (answer == null) throw StateError('no answer scripted for $call $path');
    return answer();
  }

  @override
  Future<FilesResult<ServerPath>> defaultCwd({CancelToken? cancelToken}) {
    calls.add('defaultCwd');
    tokens['defaultCwd'] = cancelToken;
    return onDefaultCwd!();
  }

  @override
  Future<FilesResult<ServerPath?>> gitRoot(
    ServerPath path, {
    CancelToken? cancelToken,
  }) => _answer('gitRoot', gitRoots, path.value, cancelToken);

  @override
  Future<FilesResult<FsListing>> list(
    ServerPath path, {
    CancelToken? cancelToken,
  }) => _answer('list', lists, path.value, cancelToken);

  @override
  Future<FilesResult<FsTextFile>> readText(
    ServerPath path, {
    CancelToken? cancelToken,
  }) => _answer('readText', texts, path.value, cancelToken);

  @override
  Future<FilesResult<FsDownload>> download(
    ServerPath path, {
    required IOSink sink,
    CancelToken? cancelToken,
    void Function(int received, int? total)? onProgress,
    bool allowLarge = false,
  }) {
    calls.add('download ${path.value}');
    final answer = downloads[path.value];
    if (answer == null) throw StateError('no download scripted');
    return answer(sink, cancelToken, allowLarge, onProgress);
  }
}

ServerPath p(String text) => ServerPath.tryParse(text)!;

FsEntry file(String path, {bool dir = false}) =>
    FsEntry(name: path.split('/').last, path: p(path), isDirectory: dir);

FsEntry folderEntry(String path) => file(path, dir: true);

Future<FilesResult<FsListing>> listing(List<FsEntry> entries) =>
    Future.value(FilesOk(FsListing(entries: entries)));

Future<FilesResult<T>> ok<T>(T value) => Future.value(FilesOk(value));

Future<FilesResult<T>> failed<T>(FilesFailure kind) =>
    Future.value(FilesFailed<T>(kind));

/// A download that writes [bytes] and ends. [length] is the announced length.
Future<FilesResult<FsDownload>> Function(
  IOSink,
  CancelToken?,
  bool,
  void Function(int, int?)?,
)
writes(List<int> bytes, {int? length}) =>
    (sink, token, allowLarge, progress) async {
      sink.add(bytes);
      progress?.call(bytes.length, length);
      return FilesOk(FsDownload(bytes: bytes.length, contentLength: length));
    };

/// A download that stays open until [gate] completes or it is cancelled.
Future<FilesResult<FsDownload>> Function(
  IOSink,
  CancelToken?,
  bool,
  void Function(int, int?)?,
)
holds(Completer<void> gate, {List<int> first = const [1, 2, 3]}) =>
    (sink, token, allowLarge, progress) async {
      sink.add(first);
      await Future.any([gate.future, token!.whenCancel]);
      return token.isCancelled
          ? const FilesFailed(FilesFailure.cancelled)
          : FilesOk(
              FsDownload(bytes: first.length, contentLength: first.length),
            );
    };
