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
}

class PlatformMediaActions implements MediaActions {
  const PlatformMediaActions();

  @override
  Future<bool> open(String path) async =>
      (await OpenFile.open(path)).type == ResultType.done;

  @override
  Future<bool> save(String name, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: name, bytes: bytes) != null;
}
