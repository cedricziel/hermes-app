import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../chat_models.dart' show fileNameOf;
import 'media_actions.dart';
import 'media_source.dart';

const _folder = 'hermes_media';
final _unsafeInName = RegExp(r'[\x00-\x1f:*?"<>|/\\]');

/// Keeps what the chat fetched from the server for files the agent sent:
/// images in memory, other files in the app's cache directory. Nothing is
/// fetched twice, and [clear] removes all of it.
class MediaStore {
  MediaStore({
    required this._source,
    required this._cacheDirectory,
    this._actions = const PlatformMediaActions(),
    this._imageBudget = 32 * 1024 * 1024,
  });

  final MediaSource _source;
  final Future<Directory> Function() _cacheDirectory;
  final MediaActions _actions;
  final int _imageBudget;

  // Insertion order is age: the first entry is the least recently used.
  final _images = <String, Uint8List>{};
  var _imageBytes = 0;
  final _imageFetches = <String, Future<Uint8List>>{};
  final _fileFetches = <String, Future<File>>{};

  /// Bumped by [clear], so a fetch that finishes afterwards keeps nothing.
  var _generation = 0;
  StreamSubscription<void>? _signOut;

  /// The bytes of the image at [path] on the server, for showing.
  Future<Uint8List> image(String path) {
    final cached = _images.remove(path);
    if (cached != null) return Future.value(_images[path] = cached);
    return _imageFetches.putIfAbsent(path, () => _fetchImage(path));
  }

  Future<Uint8List> _fetchImage(String path) async {
    final generation = _generation;
    try {
      final bytes = await _source.image(path);
      if (generation == _generation) _remember(path, bytes);
      return bytes;
    } finally {
      if (generation == _generation) unawaited(_imageFetches.remove(path));
    }
  }

  void _remember(String path, Uint8List bytes) {
    _images[path] = bytes;
    _imageBytes += bytes.length;
    while (_imageBytes > _imageBudget && _images.length > 1) {
      final oldest = _images.keys.first;
      _imageBytes -= _images.remove(oldest)!.length;
    }
  }

  /// The file at [path] on the server, downloaded to the cache directory
  /// under [name] the first time it is asked for.
  Future<File> file(String path, String name) =>
      _fileFetches.putIfAbsent(path, () => _download(path, name));

  Future<File> _download(String path, String name) async {
    final generation = _generation;
    File? part;
    try {
      final root = await _root();
      final key = sha256.convert(utf8.encode(path)).toString().substring(0, 16);
      final target = File('${root.path}/$key/${_safeName(name)}');
      if (await target.exists()) return target;

      final bytes = await _source.file(path);
      if (generation != _generation) {
        throw const MediaFetchException(MediaFailure.failed);
      }
      await target.parent.create(recursive: true);
      // Written aside and renamed, so a half-written file is never taken for
      // a downloaded one.
      part = File('${target.path}.part');
      await part.writeAsBytes(bytes, flush: true);
      if (generation != _generation) {
        throw const MediaFetchException(MediaFailure.failed);
      }
      await part.rename(target.path);
      return target;
    } on Object catch (e) {
      final leftover = part;
      if (leftover != null) {
        await _quietly(() async {
          await leftover.delete();
        });
      }
      throw e is MediaFetchException
          ? e
          : const MediaFetchException(MediaFailure.failed);
    } finally {
      if (generation == _generation) unawaited(_fileFetches.remove(path));
    }
  }

  Future<bool> open(File file) => _actions.open(file.path);

  Future<bool> save(String name, Uint8List bytes) => _actions.save(name, bytes);

  /// Deletes every file downloaded so far, including those of an earlier
  /// run, and forgets the images.
  Future<void> clear() async {
    _generation++;
    _images.clear();
    _imageBytes = 0;
    _imageFetches.clear();
    _fileFetches.clear();
    await _quietly(() async {
      final root = await _root();
      if (await root.exists()) await root.delete(recursive: true);
    });
  }

  /// Calls [clear] each time [signedOut] fires.
  void clearOnSignOut(Stream<void> signedOut) {
    _signOut?.cancel();
    _signOut = signedOut.listen((_) => clear());
  }

  void dispose() {
    _signOut?.cancel();
    _signOut = null;
  }

  Future<Directory> _root() async =>
      Directory('${(await _cacheDirectory()).path}/$_folder');
}

/// The last part of [name], with what a file system rejects taken out, so a
/// name from the server can only land inside its own folder.
String _safeName(String name) {
  final clean = fileNameOf(name).replaceAll(_unsafeInName, '_').trim();
  return clean.isEmpty || clean == '.' || clean == '..' ? 'file' : clean;
}

Future<void> _quietly(Future<void> Function() action) async {
  try {
    await action();
  } on Object {
    // Deleting is best effort.
  }
}
