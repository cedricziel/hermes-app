import 'dart:io';

import 'package:flutter/foundation.dart';

import '../chat/media/media_store.dart' show stagedFileName;

/// Extensions Windows runs or installs when opened. A downloaded file with one
/// of these is never offered Open with…, on any server and for any file name
/// the server sends.
const kWindowsRunnableExtensions = {
  'bat',
  'cmd',
  'com',
  'exe',
  'msi',
  'msp',
  'scr',
  'pif',
  'ps1',
  'psm1',
  'vbs',
  'vbe',
  'js',
  'jse',
  'wsf',
  'wsh',
  'hta',
  'lnk',
  'url',
  'reg',
  'jar',
  'cpl',
  'dll',
  'inf',
  'sct',
  'msc',
  'appx',
  'msix',
  'appinstaller',
  'application',
  'appref-ms',
  'settingcontent-ms',
  'website',
  'diagcab',
  'chm',
  'xll',
  'ws',
  'wsc',
  'vb',
  'scf',
  // Disk images mount without the Mark of the Web, so what is inside runs
  // unchecked.
  'iso',
  'img',
  'vhd',
  'vhdx',
};

/// Writes the Mark of the Web (the `Zone.Identifier` alternate data stream,
/// zone 3) for [file], so SmartScreen and Office treat it as downloaded.
typedef MarkFile = Future<void> Function(File file);

Future<void> _writeZoneIdentifier(File file) =>
    File('${file.path}:Zone.Identifier')
        .writeAsString('[ZoneTransfer]\r\nZoneId=3\r\n', flush: true);

/// What the platform allows to be done with a file from the server's disk.
/// Only Windows has rules: no Open with… for a file that runs, and the Mark
/// of the Web on every file that can be opened.
class FilesPlatformPolicy {
  FilesPlatformPolicy({bool? windows, MarkFile? mark})
    : windows = windows ?? defaultTargetPlatform == TargetPlatform.windows,
      _mark = mark ?? _writeZoneIdentifier;

  /// No rules: for tests and for platforms other than Windows.
  const FilesPlatformPolicy.none() : windows = false, _mark = null;

  final bool windows;
  final MarkFile? _mark;

  /// Whether the file called [name] may be offered Open with….
  ///
  /// [name] is judged as it is staged ([stagedFileName]: the last path part,
  /// Unicode whitespace trimmed, cut to length), which is the name the file
  /// is opened by, and then as Windows reads it: it drops trailing dots and
  /// spaces, so `a.exe.` and `a.exe ` run as `a.exe`.
  bool canOpenWith(String name) {
    if (!windows) return true;
    final trimmed = stagedFileName(name).replaceFirst(RegExp(r'[. ]+$'), '');
    final dot = trimmed.lastIndexOf('.');
    if (dot < 0) return true;
    return !kWindowsRunnableExtensions.contains(
      trimmed.substring(dot + 1).toLowerCase(),
    );
  }

  /// Marks [file] as downloaded where that is a thing. Throws when the mark
  /// cannot be written.
  Future<void> markDownloaded(File file) async {
    final mark = _mark;
    if (!windows || mark == null) return;
    await mark(file);
  }
}
