import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// A 1x1 transparent PNG.
final Uint8List kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

/// A fresh temporary directory, deleted when the test ends.
Directory tempDir(String prefix) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// Writes [bytes] to `<dir>/<name>`.
File writeTemp(Directory dir, String name, List<int> bytes) =>
    File('${dir.path}/$name')..writeAsBytesSync(bytes);
