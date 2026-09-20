import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Host side of `integration_test/store_screenshots_test.dart`.
///
/// The test asks for each screenshot over HTTP at the moment it wants it and
/// waits for the answer, so the picture is of the screen as it is right then.
/// The driver's own screenshot hook would run after the whole test is over.
///
/// `SHOT_PORT` is where to listen and `SHOT_DIR` where the files go. With
/// `SHOT_UDID` the whole screen of that simulator (status bar included) is
/// captured; with `SHOT_MAC_PROCESS` the window of that macOS app.
Future<void> main() async {
  final dir = Directory(Platform.environment['SHOT_DIR'] ?? 'build/screenshots')
    ..createSync(recursive: true);
  final udid = Platform.environment['SHOT_UDID'];
  final macProcess = Platform.environment['SHOT_MAC_PROCESS'];
  final port = int.parse(Platform.environment['SHOT_PORT'] ?? '0');

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  server.listen((request) async {
    final name = request.uri.queryParameters['name'] ?? '';
    final file = '${dir.path}/$name.png';
    var ok = RegExp(r'^[a-z0-9-]+$').hasMatch(name);
    if (ok && udid != null) {
      ok = await _run('xcrun', [
        'simctl',
        'io',
        udid,
        'screenshot',
        '--type=png',
        file,
      ]);
    } else if (ok && macProcess != null) {
      ok = await _captureMacWindow(macProcess, file);
    } else {
      ok = false;
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

Future<bool> _run(String executable, List<String> arguments) async =>
    (await Process.run(executable, arguments)).exitCode == 0;

/// A covered window is not painted, so the app is brought forward first (as
/// `scripts/dev-app.sh screenshot` does), then its window alone is captured.
Future<bool> _captureMacWindow(String process, String file) async {
  final pid = (await Process.run('pgrep', [
    '-n',
    '-x',
    process,
  ])).stdout.toString().trim();
  if (pid.isEmpty) return false;
  await Process.run('osascript', [
    '-e',
    'tell application "System Events" to set frontmost of (first process whose unix id is $pid) to true',
  ]);
  await Future<void>.delayed(const Duration(seconds: 1));
  final window = (await Process.run('xcrun', [
    'swift',
    'scripts/window-id.swift',
    pid,
  ])).stdout.toString().trim();
  if (window.isEmpty) return false;
  return _run('screencapture', ['-x', '-o', '-l', window, file]);
}
