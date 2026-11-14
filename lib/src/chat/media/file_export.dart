import 'dart:io';

import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

/// Where the user wants a copy of a file kept. Returns the folder-and-name
/// chosen, or null when they cancel.
typedef PickSaveDestination = Future<String?> Function(String name);

/// Hands the file at a path to the system's export sheet and returns the
/// saved path, or null when they cancel. The name is the staged file's own;
/// the real export does not pass it on.
typedef ExportFromPath = Future<String?> Function(String name, String path);

/// Copies a file on disk to a place the user picks, never reading it into
/// memory: on iOS and Android the platform's document picker is given the
/// file's path (`flutter_file_dialog`), on desktop `file_selector` returns the
/// destination and the file is copied by the file system.
class FileExport {
  FileExport({
    bool? mobile,
    PickSaveDestination? pickDestination,
    ExportFromPath? exportFromPath,
  }) : _mobile =
           mobile ??
           (defaultTargetPlatform == TargetPlatform.iOS ||
               defaultTargetPlatform == TargetPlatform.android),
       _pickDestination = pickDestination ?? _pickWithSelector,
       _exportFromPath = exportFromPath ?? _exportWithDialog;

  final bool _mobile;
  final PickSaveDestination _pickDestination;
  final ExportFromPath _exportFromPath;

  /// Asks where to keep [source] as [name] and copies it there. False when
  /// the user cancels.
  Future<bool> saveCopy(String name, File source) async {
    if (_mobile) return await _exportFromPath(name, source.path) != null;
    final destination = await _pickDestination(name);
    if (destination == null) return false;
    // Copied straight onto the file the panel granted. The macOS app is
    // sandboxed and the panel grants that one file only: a temp file beside
    // it, or a rename, is not allowed there. The staged source is already
    // whole and in the app's own container, so nothing needs staging twice.
    // A failure never reads as done. A copy that fails before it writes leaves
    // an existing file as it was; one that fails after writing leaves a
    // partial file, which is deleted when the panel made it (the file did not
    // exist before) and otherwise cannot be restored.
    final existed = await File(destination).exists();
    try {
      await source.copy(destination);
    } on Object {
      if (!existed) {
        try {
          final partial = File(destination);
          if (await partial.exists()) await partial.delete();
        } on Object {
          // Best effort.
        }
      }
      rethrow;
    }
    return true;
  }

  static Future<String?> _pickWithSelector(String name) async =>
      (await selector.getSaveLocation(suggestedName: name))?.path;

  // No `fileName`: with one, the plugin on iOS first copies the whole file to
  // `NSTemporaryDirectory()/<name>`, outside the media cache, where it
  // outlives App Lock and a kill. Without it the staged file is exported
  // as it is (iOS) and Android names the document after the staged file, whose
  // name is already the safe one.
  static Future<String?> _exportWithDialog(String name, String path) =>
      FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(sourceFilePath: path),
      );
}
