// Measures every tap target of the Widgetbook catalog (and, when the workflow
// tests ran before it with HERMES_TAP_REPORT=1, of their screens) against the
// Android (48), iOS (44) and macOS (28) minimums. It reports, never fails.
//
// The file is named without `_test` on purpose: `flutter test` and the CI
// shards do not pick it up. Run it with scripts/tap-report.sh (see the
// hill-climb-style skill).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:widgetbook/widgetbook.dart';

import '../../widgetbook/directories.dart';
import '../support/tap_targets.dart';

Iterable<(String, WidgetbookUseCase)> _useCases(
  Iterable<WidgetbookNode> nodes, [
  String prefix = '',
]) sync* {
  for (final node in nodes) {
    if (node is WidgetbookUseCase) {
      yield ('$prefix${node.name}', node);
    } else {
      yield* _useCases(node.children ?? const [], '$prefix${node.name} / ');
    }
  }
}

const _phone = Size(390, 844);
const _desktop = Size(1280, 800);

/// Android and iOS are measured on a phone, macOS on a desktop window.
const _passes = [
  (TargetPlatform.android, _phone),
  (TargetPlatform.iOS, _phone),
  (TargetPlatform.macOS, _desktop),
];

void main() {
  final samples = <TapSample>[];
  final stopwatch = Stopwatch()..start();
  var useCaseCount = 0;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final (label, useCase) in _useCases(directories)) {
    testWidgets('measure: $label', (tester) async {
      useCaseCount++;
      for (final (platform, size) in _passes) {
        tester.view
          ..physicalSize = size * 2
          ..devicePixelRatio = 2;
        debugDefaultTargetPlatformOverride = platform;
        try {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildHermesLightTheme(platform: platform),
              home: Scaffold(body: Builder(builder: useCase.builder)),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          if (tester.takeException() == null) {
            samples.add(
              await measureScreen(
                tester,
                'usecase: $label',
                platformKey(platform),
              ),
            );
          } else {
            // A use case that throws is the catalog test's business.
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 10));
        } finally {
          debugDefaultTargetPlatformOverride = null;
          tester.view.reset();
        }
      }
    });
  }

  tearDownAll(() {
    final useCaseSamples = List.of(samples);
    final workflow = readWorkflowSamples();
    final report = TapReport([...useCaseSamples, ...workflow]);
    final out = File('$tapReportDir/report.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(
        report.toJson(
          meta: {
            'useCases': useCaseCount,
            'useCaseScreens': useCaseSamples.length,
            'workflowScreens': workflow.length,
            'seconds': stopwatch.elapsed.inSeconds,
          },
        ),
      ),
    );
    // ignore: avoid_print
    print(
      '\n${report.summary()}\nuse cases: $useCaseCount, workflow screens: '
      '${workflow.length}, ${stopwatch.elapsed.inSeconds}s\n'
      'full list: ${out.path}',
    );
  });
}
