import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';

/// What the system does with a downloaded file, behind an interface so tests
/// need no platform.
abstract interface class MediaActions {
  /// Opens the file at [path] in the app the system has for its type. False
  /// when no app can.
  Future<bool> open(String path);

  /// Asks the user where to keep [bytes] as [name] and writes them there.
  /// False when they cancel.
  Future<bool> save(String name, Uint8List bytes);

  /// Asks the user where to keep the file at [file] as [name]. False when
  /// they cancel. Throws [SaveTooLargeException] for a file the platform
  /// cannot save without holding it in memory.
  Future<bool> saveFile(String name, File file);
}

/// The largest file [PlatformMediaActions.saveFile] hands to the save dialog.
const kMaxSaveBytes = 32 * 1024 * 1024;

/// [MediaActions.saveFile] refused a file because saving it would need all of
/// it in memory. It carries nothing: no name, no path.
class SaveTooLargeException implements Exception {
  const SaveTooLargeException();

  @override
  String toString() => 'SaveTooLargeException';
}

class PlatformMediaActions implements MediaActions {
  const PlatformMediaActions({this.maxSaveBytes = kMaxSaveBytes});

  /// The size above which [saveFile] throws [SaveTooLargeException].
  final int maxSaveBytes;

  @override
  Future<bool> open(String path) async =>
      (await OpenFile.open(path)).type == ResultType.done;

  @override
  Future<bool> save(String name, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: name, bytes: bytes) != null;

  // file_picker 13 saves from bytes on every platform, so this reads the whole
  // file into memory. That is only acceptable for a small file, hence the cap;
  // a path-based save (file_selector on desktop, a document-export channel on
  // mobile) is what a file of any size needs.
  @override
  Future<bool> saveFile(String name, File file) async {
    if (await file.length() > maxSaveBytes) throw const SaveTooLargeException();
    return await FilePicker.saveFile(
          fileName: name,
          bytes: await file.readAsBytes(),
        ) !=
        null;
  }
}
