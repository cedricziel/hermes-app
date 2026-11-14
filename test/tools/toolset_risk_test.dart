import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/toolset_risk.dart';

void main() {
  test('exactly these four toolsets ask before switching on', () {
    final asking = {
      for (final e in kToolsetRisks.entries)
        if (e.value.asksBeforeSwitchingOn) e.key,
    };

    expect(asking, {'terminal', 'code_execution', 'computer_use', 'browser'});
    expect(toolsetRisk('file')?.level, ToolsetRiskLevel.explain);
    expect(toolsetRisk('web'), isNull);
  });

  test('no name is both risky and "no risk"', () {
    expect(kToolsetRisks.keys.toSet().intersection(kNoRiskToolsets), isEmpty);
  });

  test('a plugin toolset\'s name never becomes a telemetry label', () {
    expect(toolsetSlug('terminal'), 'terminal');
    expect(toolsetSlug('web'), 'web');
    expect(toolsetSlug('acme_private_plugin'), 'other');
  });
}
