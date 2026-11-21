import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tap_targets.dart';

TapTarget target(
  String label,
  double w,
  double h, {
  bool labeled = true,
  double x = 0,
  double y = 0,
}) => TapTarget(
  label: label,
  width: w,
  height: h,
  labeled: labeled,
  left: x,
  top: y,
);

void main() {
  test('a screen seen in both themes counts once', () {
    final report = TapReport([
      TapSample('chat-phone/01-x', 'android', [target('Copy', 40, 40)]),
      TapSample('chat-phone-dark/01-x', 'android', [target('Copy', 40, 40)]),
    ]);
    expect(report.violations('android'), hasLength(1));
    expect(report.rawViolations('android'), hasLength(2));
  });

  test('identical controls at different places count separately', () {
    final report = TapReport([
      for (var i = 0; i < 10; i++)
        TapSample('f/a', 'android', [
          target('(no label)', 40, 40, labeled: false, y: i * 50.0),
        ]),
      TapSample('f-dark/a', 'android', [
        for (var i = 0; i < 10; i++)
          target('(no label)', 40, 40, labeled: false, y: i * 50.0),
      ]),
    ]);
    expect(report.violations('android'), hasLength(10));
    expect(report.rawViolations('android'), hasLength(20));
  });

  test('each platform judges by its own minimum', () {
    final report = TapReport([
      TapSample('a', 'android', [target('x', 46, 46)]),
      TapSample('a', 'ios', [target('x', 46, 46)]),
      TapSample('a', 'macos', [target('x', 24, 24), target('y', 44, 44)]),
    ]);
    expect(report.violations('android'), hasLength(1));
    expect(report.violations('ios'), isEmpty);
    expect(report.violations('macos'), hasLength(1));
    expect(report.inflated(), hasLength(1));
  });

  test('unlabeled targets count, skipped screens do not', () {
    final report = TapReport([
      TapSample('a', 'android', [target('(no label)', 50, 50, labeled: false)]),
      TapSample('b', 'skip', [
        target('(no label)', 5, 5, labeled: false),
      ], 'linux'),
    ]);
    expect(report.unlabeled(), hasLength(1));
  });

  test('every theme platform has its own rule', () {
    expect(platformKey(TargetPlatform.android), 'android');
    expect(platformKey(TargetPlatform.fuchsia), 'android');
    expect(platformKey(TargetPlatform.iOS), 'ios');
    expect(platformKey(TargetPlatform.macOS), 'macos');
    expect(platformKey(TargetPlatform.windows), 'windows');
    expect(platformKey(TargetPlatform.linux), 'linux');
    expect(tapThresholds['windows'], 28);
    expect(windowClass(1280), 'desktop');
    expect(windowClass(390), 'phone');
  });

  Future<TapSample> measureAt(
    WidgetTester tester,
    TargetPlatform platform,
    Size size, [
    double box = 40,
  ]) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Center(
            child: Semantics(
              label: 'Small',
              button: true,
              onTap: () {},
              child: SizedBox(width: box, height: box),
            ),
          ),
        ),
      ),
    );
    return measureWorkflowScreen(tester, 'flow/01-x');
  }

  testWidgets('a desktop-width screen with an Android theme is judged as '
      'Android, not as macOS', (tester) async {
    final sample = await measureAt(
      tester,
      TargetPlatform.android,
      const Size(1280, 800),
    );
    expect(sample.platform, 'android');
    expect(sample.window, 'desktop');
    final report = TapReport([sample]);
    expect(report.violations('android'), hasLength(1));
    expect(report.violations('macos'), isEmpty);
    expect(report.inflated(), isEmpty);
  });

  testWidgets('a macOS-themed screen is judged by 28 and the inflated check, '
      'even in a narrow window', (tester) async {
    final small = await measureAt(
      tester,
      TargetPlatform.macOS,
      const Size(600, 800),
      24,
    );
    expect(small.platform, 'macos');
    expect(small.window, 'phone');
    expect(TapReport([small]).violations('macos'), hasLength(1));
    expect(TapReport([small]).violations('android'), isEmpty);
    final inflated = await measureAt(
      tester,
      TargetPlatform.macOS,
      const Size(1280, 800),
      48,
    );
    expect(inflated.platform, 'macos');
    expect(TapReport([inflated]).violations('macos'), isEmpty);
    expect(TapReport([inflated]).inflated(), hasLength(1));
  });

  testWidgets('a phone window with a desktop theme is judged by its theme and '
      'keeps its window class', (tester) async {
    final sample = await measureAt(
      tester,
      TargetPlatform.linux,
      const Size(390, 844),
    );
    expect(sample.platform, 'linux');
    expect(sample.window, 'phone');
    expect(TapReport([sample]).violations('linux'), isEmpty);
  });

  test('window class survives the JSON round trip', () {
    final back = TapSample.fromJson(
      const TapSample('a', 'android', [], 'android', null, 'desktop').toJson(),
    );
    expect(back.window, 'desktop');
  });

  test('theme suffix is stripped from the flow only', () {
    expect(stripTheme('chat-phone-dark/01-x'), 'chat-phone/01-x');
    expect(stripTheme('chat-phone/01-dark-mode'), 'chat-phone/01-dark-mode');
  });

  test('a use case that pins another platform is not judged by this one', () {
    expect(
      pinnedPlatform([TargetPlatform.android], TargetPlatform.macOS),
      'android',
    );
    expect(pinnedPlatform([TargetPlatform.iOS], TargetPlatform.android), 'ios');
    expect(
      pinnedPlatform([TargetPlatform.android], TargetPlatform.android),
      isNull,
    );
    expect(
      pinnedPlatform([TargetPlatform.linux], TargetPlatform.macOS),
      isNull,
    );
    expect(pinnedPlatform(const [], TargetPlatform.iOS), isNull);
    // Side by side: each pass finds its own theme.
    const both = [TargetPlatform.android, TargetPlatform.iOS];
    expect(pinnedPlatform(both, TargetPlatform.android), isNull);
    expect(pinnedPlatform(both, TargetPlatform.iOS), isNull);
    expect(pinnedPlatform(both, TargetPlatform.macOS), 'android');
  });

  test('skipped passes are counted by reason', () {
    final report = TapReport([
      const TapSample('u', 'skip', [], 'android', 'pins android'),
      const TapSample('v', 'skip', [], 'android', 'pins android'),
    ]);
    expect(report.skippedPasses, {'pins android': 2});
  });

  Future<void> pumpAt(WidgetTester tester, TargetPlatform platform) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: Center(
            child: Semantics(
              label: 'Small',
              button: true,
              onTap: () {},
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      ),
    );
    // The theme animates between platforms.
    await tester.pumpAndSettle();
  }

  testWidgets('samples of every run folder are read back', (tester) async {
    final dir = Directory.systemTemp.createTempSync('tap_runs');
    addTearDown(() => dir.deleteSync(recursive: true));
    await pumpAt(tester, TargetPlatform.android);
    await recordWorkflowScreen(
      tester,
      'a',
      '01',
      dir: dir.path,
      run: defaultRun,
    );
    await pumpAt(tester, TargetPlatform.macOS);
    await recordWorkflowScreen(tester, 'a', '02', dir: dir.path, run: 'macOS');
    final samples = readWorkflowSamples(dir: dir.path);
    expect(samples.map((s) => s.source).toList()..sort(), ['a/01', 'a/02']);
    expect(samples.map((s) => s.platform).toSet(), {'android', 'macos'});
  });

  testWidgets('a WORKFLOW_PLATFORM run records only screens of that platform', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('tap_runs');
    addTearDown(() => dir.deleteSync(recursive: true));
    await pumpAt(tester, TargetPlatform.android);
    await recordWorkflowScreen(tester, 'a', '01', dir: dir.path, run: 'macOS');
    expect(readWorkflowSamples(dir: dir.path), isEmpty);
    await pumpAt(tester, TargetPlatform.macOS);
    await recordWorkflowScreen(tester, 'a', '02', dir: dir.path, run: 'macOS');
    expect(readWorkflowSamples(dir: dir.path), hasLength(1));
  });

  testWidgets('a screen a test pins to macOS counts once across both runs', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('tap_runs');
    addTearDown(() => dir.deleteSync(recursive: true));
    await pumpAt(tester, TargetPlatform.macOS);
    await recordWorkflowScreen(
      tester,
      'mac',
      '01',
      dir: dir.path,
      run: defaultRun,
    );
    await recordWorkflowScreen(
      tester,
      'mac',
      '01',
      dir: dir.path,
      run: 'macOS',
    );
    expect(readWorkflowSamples(dir: dir.path), hasLength(1));
  });
}
