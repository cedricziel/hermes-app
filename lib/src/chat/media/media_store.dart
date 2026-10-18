import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../chat_models.dart' show fileNameOf;
import 'media_actions.dart';
import 'media_source.dart';
import 'quick_look.dart';

const _folder = 'hermes_media';

/// How long a downloaded file may stay in the cache before the next launch
/// deletes it.
const mediaCacheMaxAge = Duration(hours: 24);

final _unsafeInName = RegExp(r'[\x00-\x1f:*?"<>|/\\]');

/// Keeps what the chat fetched from the server for files the agent sent:
/// images in memory, other files in the app's cache directory. Nothing is
/// fetched twice, and [clear] removes all of it.
class MediaStore {
  MediaStore({
    required this._source,
    required this._cacheDirectory,
    this._actions = const PlatformMediaActions(),
    this._quickLook = const NoQuickLook(),
    this._imageBudget = 32 * 1024 * 1024,
  });

  final MediaSource _source;
  final Future<Directory> Function() _cacheDirectory;
  final MediaActions _actions;
  final QuickLook _quickLook;
  final int _imageBudget;

  // Insertion order is age: the first entry is the least recently used.
  final _images = <String, Uint8List>{};
  var _imageBytes = 0;
  final _imageFetches = <String, Future<Uint8List>>{};
  final _fileFetches = <String, Future<File>>{};

  /// Makes the names of the files this store writes aside its own.
  final _partSuffix = '$pid-${Random().nextInt(1 << 30)}';

  var _sweeping = false;
  final _usedWhileSweeping = <String>{};

  /// Bumped by [clear], so a fetch that finishes afterwards keeps nothing.
  var _generation = 0;
  var _previewRequest = 0;
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
      stage(path, name, () => _source.file(path));

  /// A file in the cache directory under [name], whose bytes [fetch] supplies
  /// the first time [key] is asked for. Asking for the same [key] again, also
  /// while [fetch] runs, shares that one file.
  ///
  /// An error [fetch] throws reaches the caller as it is; a failure to write
  /// the file is a [MediaFetchException] of [MediaFailure.failed].
  Future<File> stage(
    String key,
    String name,
    Future<Uint8List> Function() fetch,
  ) => _stage(key, name, (part) async {
    final bytes = await fetch();
    try {
      await part.writeAsBytes(bytes, flush: true);
    } on Object {
      throw const MediaFetchException(MediaFailure.failed);
    }
  });

  /// [bytes] the chat already holds, as a file in the cache directory.
  Future<File> stageBytes(String key, String name, Uint8List bytes) =>
      stage(key, name, () async => bytes);

  /// A copy of [source], a file from elsewhere on the device, in the cache
  /// directory, so nothing outside the app's container has to be read. The
  /// copy is made on disk, never through memory. A changed file is copied
  /// again.
  Future<File> stageCopy(String name, File source) async {
    final FileStat stat;
    try {
      stat = await source.stat();
    } on Object {
      throw const MediaFetchException(MediaFailure.failed);
    }
    if (stat.type != FileSystemEntityType.file) {
      throw const MediaFetchException(MediaFailure.missing);
    }
    final modified = stat.modified.microsecondsSinceEpoch;
    return _stage('local:${source.path}:${stat.size}:$modified', name, (
      part,
    ) async {
      try {
        await source.copy(part.path);
      } on Object {
        throw const MediaFetchException(MediaFailure.failed);
      }
    });
  }

  /// The file for [key], made by [fill] into the path it is given the first
  /// time, and shared by every request for [key] after that, also while
  /// [fill] runs. What [fill] throws reaches the caller as it is.
  Future<File> _stage(
    String key,
    String name,
    Future<void> Function(File part) fill,
  ) {
    if (_sweeping) _usedWhileSweeping.add(_folderOf(key));
    return _fileFetches.putIfAbsent(key, () => _make(key, name, fill));
  }

  Future<File> _make(
    String key,
    String name,
    Future<void> Function(File part) fill,
  ) async {
    final generation = _generation;
    File? part;
    Object? fillFailure;
    try {
      final root = await _root();
      final target = File('${root.path}/${_folderOf(key)}/${_safeName(name)}');
      if (await target.exists()) {
        // A file in use is not an old one, whatever its download date.
        await _quietly(() => target.setLastModified(DateTime.now()));
        return target;
      }

      await target.parent.create(recursive: true);
      // Written aside and renamed, so a half-written file is never taken for
      // a downloaded one. The name is this store's own, since every engine
      // has a store over the same folder.
      part = File('${target.path}.$_partSuffix.part');
      try {
        await fill(part);
      } on Object catch (e) {
        fillFailure = e;
        rethrow;
      }
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
      if (e is MediaFetchException || identical(e, fillFailure)) rethrow;
      throw const MediaFetchException(MediaFailure.failed);
    } finally {
      if (generation == _generation) unawaited(_fileFetches.remove(key));
    }
  }

  static String _folderOf(String key) =>
      sha256.convert(utf8.encode(key)).toString().substring(0, 16);

  /// Captures a preview intent before staging starts. A newer preview or a
  /// session clear invalidates it, so a late download cannot replace what the
  /// user opened next or present media after signing out.
  bool Function() beginPreview() {
    final generation = _generation;
    final request = ++_previewRequest;
    return () => generation == _generation && request == _previewRequest;
  }

  /// Shows [file] in the Quick Look panel. With [toggle] the panel closes
  /// instead when it already shows [file].
  Future<QuickLookToggle> showQuickLook(
    File file, {
    required bool toggle,
  }) async {
    if (toggle) return _quickLook.toggle(file.path);
    return await _quickLook.preview(file.path)
        ? QuickLookToggle.shown
        : QuickLookToggle.failed;
  }

  Future<bool> open(File file) => _actions.open(file.path);

  Future<bool> save(String name, Uint8List bytes) => _actions.save(name, bytes);

  /// Deletes every file downloaded so far, including those of an earlier
  /// run, and forgets the images.
  Future<void> clear() async {
    _generation++;
    await _quietly(_quickLook.close);
    _images.clear();
    _imageBytes = 0;
    _imageFetches.clear();
    _fileFetches.clear();
    await _quietly(() async {
      final root = await _root();
      if (await root.exists()) await root.delete(recursive: true);
    });
  }

  /// Deletes what was cached more than [maxAge] ago, such as by an earlier
  /// run. Best effort: nothing it cannot delete is reported.
  ///
  /// A file used while the sweep runs is left alone: the age is measured from
  /// before the sweep started, a folder asked for meanwhile is skipped, and a
  /// file's date is looked at again just before it is deleted.
  Future<void> sweep(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    _sweeping = true;
    return _quietly(() async {
      final root = await _root();
      if (!await root.exists()) return;
      await for (final entry in root.list()) {
        if (entry is! Directory) continue;
        final name = entry.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        await _quietly(() async {
          await for (final file in entry.list()) {
            if (_usedWhileSweeping.contains(name)) return;
            if (file is File && await _olderThan(file, cutoff)) {
              await file.delete();
            }
          }
          // A folder a request is about to fill is not empty yet.
          final busy =
              _usedWhileSweeping.contains(name) || _fileFetches.isNotEmpty;
          if (!busy && await entry.list().isEmpty) await entry.delete();
        });
      }
    }).whenComplete(() {
      _sweeping = false;
      _usedWhileSweeping.clear();
    });
  }

  static Future<bool> _olderThan(File file, DateTime cutoff) async =>
      (await file.lastModified()).isBefore(cutoff);

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
  if (clean.isEmpty || clean == '.' || clean == '..') return 'file';
  return _shortened(clean);
}

/// [name] cut to a length a file system takes (255 bytes, with the suffix of
/// a `.part` file to spare), keeping its extension.
String _shortened(String name) {
  const limit = 180;
  if (utf8.encode(name).length <= limit) return name;
  final dot = name.lastIndexOf('.');
  final extension = dot > 0 && name.length - dot <= 16
      ? name.substring(dot)
      : '';
  var base = name.substring(0, extension.isEmpty ? name.length : dot);
  while (utf8.encode(base).length + utf8.encode(extension).length > limit) {
    base = base.substring(0, base.length - 1);
  }
  return '$base$extension';
}

Future<void> _quietly(Future<void> Function() action) async {
  try {
    await action();
  } on Object {
    // Deleting is best effort.
  }
}
