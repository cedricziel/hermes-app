import 'package:flutter/foundation.dart';
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
    expect(report.skippedByPlatform, {'linux': 1});
  });

  test('a workflow screen is judged by what it rendered as, or by macOS', () {
    expect(judgedPlatform(TargetPlatform.android, 390), 'android');
    expect(judgedPlatform(TargetPlatform.iOS, 390), 'ios');
    expect(judgedPlatform(TargetPlatform.android, 1280), 'macos');
    expect(judgedPlatform(TargetPlatform.macOS, 1280), 'macos');
    expect(judgedPlatform(TargetPlatform.macOS, 390), 'skip');
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
  });

  test('skipped passes are counted by reason, apart from skipped screens', () {
    final report = TapReport([
      const TapSample('u', 'skip', [], 'android', 'pins android'),
      const TapSample('v', 'skip', [], 'android', 'pins android'),
      const TapSample('w', 'skip', [], 'macos'),
    ]);
    expect(report.skippedPasses, {'pins android': 2});
    expect(report.skippedByPlatform, {'macos': 1});
  });
}
