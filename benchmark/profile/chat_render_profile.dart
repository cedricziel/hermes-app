// Chat rendering benchmark, profile mode: the same scenarios as
// benchmark/chat_render_bench_test.dart, run in the real Linux app (AOT, no
// debug asserts, real window and clock) and measured with the engine's
// FrameTiming. Run it through `scripts/chat-bench.sh --mode profile`, which
// wraps `flutter drive --profile -d linux` in Xvfb.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../support/frame_stats.dart';
import '../support/scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  collectFrameTimings();
  tearDownAll(() async {
    writeReport();
    binding.reportData = resultsJson();
  });
  registerScenarios();
}
