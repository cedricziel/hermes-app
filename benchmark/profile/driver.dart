import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Host side of the profile-mode benchmark: collects the JSON the app reports
/// through `IntegrationTestWidgetsFlutterBinding.reportData` and writes it to
/// `CHAT_BENCH_OUT`.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final out =
        Platform.environment['CHAT_BENCH_OUT'] ??
        'build/chat_bench/results.json';
    final file = File(out)..createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(data ?? const {}),
    );
  },
);
