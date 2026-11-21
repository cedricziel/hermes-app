import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/settings/third_party_notices.dart';
import 'package:yaml/yaml.dart';

/// Guards the claims behind the `flutter_soloud` dependency: its build hook
/// downloads no Xiph or VST3 binaries, and the licences of what it compiles in
/// are registered for the pinned version. Whoever changes one of these reads
/// `hook/build.dart` of the new version again (docs/architecture/native.md).
/// That `flutter_soloud` is imported by one file only is checked in
/// `test/voice/calls/portable_call_lifecycle_test.dart`.
YamlMap _map(Object? value) => value as YamlMap;

void main() {
  final pubspec = _map(loadYaml(File('pubspec.yaml').readAsStringSync()));
  final pinned = _map(pubspec['dependencies'])['flutter_soloud'];

  test('the build hook is told to download no Xiph library and no VST3', () {
    final hooks = _map(pubspec['hooks']);
    final defines = _map(_map(hooks['user_defines'])['flutter_soloud']);
    expect(defines['no_xiph_libs'], isTrue);
    expect(defines['enable_vst3'], isFalse);
  });

  test('flutter_soloud is pinned to one exact version', () {
    expect(pinned, matches(RegExp(r'^\d+\.\d+\.\d+$')));
  });

  test('the notices were written for the pinned version', () {
    expect(
      pinned,
      kFlutterSoloudNoticesVersion,
      reason:
          'Bump kFlutterSoloudNoticesVersion together with the pin, after '
          'reading the new version\'s hook/build.dart and licences',
    );
  });

  test('the lock file resolves the pinned version', () {
    final lock = _map(loadYaml(File('pubspec.lock').readAsStringSync()));
    final package = _map(_map(lock['packages'])['flutter_soloud']);
    expect(package['version'], kFlutterSoloudNoticesVersion);
    expect(package['source'], 'hosted');
  });

  test('the notices still cover what flutter_soloud compiles in', () {
    final names = [for (final (n, _) in callAudioNotices) ...n];
    for (final package in [
      'SoLoud',
      'signalsmith-stretch',
      'signalsmith-linear',
      'pffft',
    ]) {
      expect(
        names.where((n) => n.startsWith(package)),
        isNotEmpty,
        reason: package,
      );
    }
  });
}
