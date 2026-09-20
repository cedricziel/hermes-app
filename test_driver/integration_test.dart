import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Host side of `integration_test/store_screenshots_test.dart`.
///
/// The test asks for each screenshot over HTTP at the moment it wants it and
/// waits for the answer, so the picture is of the screen as it is right then.
/// The driver's own screenshot hook would run after the whole test is over.
///
/// `SHOT_PORT` is where to listen, `SHOT_DIR` where the files go, and
/// `SHOT_UDID` the simulator whose whole screen (status bar included) is
/// captured.
Future<void> main() async {
  final dir = Directory(Platform.environment['SHOT_DIR'] ?? 'build/screenshots')
    ..createSync(recursive: true);
  final udid = Platform.environment['SHOT_UDID'];
  final port = int.parse(Platform.environment['SHOT_PORT'] ?? '0');

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  server.listen((request) async {
    final name = request.uri.queryParameters['name'] ?? '';
    var ok = udid != null && RegExp(r'^[a-z0-9-]+$').hasMatch(name);
    if (ok) {
      final result = await Process.run('xcrun', [
        'simctl',
        'io',
        udid,
        'screenshot',
        '--type=png',
        '${dir.path}/$name.png',
      ]);
      ok = result.exitCode == 0;
    }
    request.response.statusCode = ok ? 200 : 500;
    await request.response.close();
  });

  try {
    await integrationDriver();
  } finally {
    await server.close(force: true);
  }
}
