import 'dart:io';
import 'dart:typed_data';

import 'package:hermes_app/src/chat/media/media_actions.dart';

/// Stands in for the system app that opens a file and the save dialog.
class FakeMediaActions implements MediaActions {
  FakeMediaActions({this.opens = true, this.saves = true});

  /// Whether some app can open the file.
  bool opens;

  /// Whether the user confirms a save.
  bool saves;

  /// The paths handed to the system to open.
  final opened = <String>[];

  final saved = <({String name, Uint8List bytes})>[];

  /// Names and paths handed to [saveFile].
  final savedFiles = <({String name, String path})>[];

  @override
  Future<bool> open(String path) async {
    opened.add(path);
    return opens;
  }

  @override
  Future<bool> save(String name, Uint8List bytes) async {
    if (!saves) return false;
    saved.add((name: name, bytes: bytes));
    return true;
  }

  @override
  Future<bool> saveFile(String name, File file) async {
    if (!saves) return false;
    savedFiles.add((name: name, path: file.path));
    return true;
  }
}
