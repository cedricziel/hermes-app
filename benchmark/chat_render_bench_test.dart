// Chat rendering benchmark, widget-test mode: drives the real ChatScreen
// through scripted streams on the test binding and records, per frame, the
// wall time of the UI-thread work. Run it with `scripts/chat-bench.sh` or
// `flutter test benchmark/chat_render_bench_test.dart -j 1`. It lives outside
// test/ so the CI shards never pick it up. Profile mode: see
// benchmark/profile/chat_render_profile.dart.
import 'package:flutter_test/flutter_test.dart';

import 'support/frame_stats.dart';
import 'support/scenarios.dart';

void main() {
  tearDownAll(() async => writeReport());
  registerScenarios();
}
