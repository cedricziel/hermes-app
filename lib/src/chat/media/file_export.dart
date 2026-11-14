import 'dart:io';

import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

/// Where the user wants a copy of a file kept. Returns the folder-and-name
/// chosen, or null when they cancel.
typedef PickSaveDestination = Future<String?> Function(String name);

/// Hands the file at a path to the system's export sheet and returns the
/// saved path, or null when they cancel.
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
    await source.copy(destination);
    return true;
  }

  static Future<String?> _pickWithSelector(String name) async =>
      (await selector.getSaveLocation(suggestedName: name))?.path;

  static Future<String?> _exportWithDialog(String name, String path) =>
      FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(sourceFilePath: path, fileName: name),
      );
}
