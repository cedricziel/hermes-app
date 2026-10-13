import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<Directory> queueDirectory() async {
  if (kIsWeb) {
    throw UnsupportedError('Durable queues require local protected storage');
  }
  if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
    final path = await const MethodChannel('hermes_app/queue_storage')
        .invokeMethod<String>('directory');
    if (path == null || path.isEmpty) {
      throw const FileSystemException('Protected queue directory unavailable');
    }
    return Directory(path);
  }
  final folder = Directory(
    '${(await getApplicationSupportDirectory()).path}/DurableQueues',
  );
  await folder.create(recursive: true);
  if (Platform.isLinux) {
    final result = await Process.run('/bin/chmod', ['700', folder.path]);
    if (result.exitCode != 0) {
      throw const FileSystemException(
        'Protected queue permissions unavailable',
      );
    }
  }
  return folder;
}
