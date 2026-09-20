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
}
