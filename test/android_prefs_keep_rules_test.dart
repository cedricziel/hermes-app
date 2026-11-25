import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Kotlin classes `package:jni` looks up by name to call suspend
/// functions, which `shared_preferences_android` 2.5 reads preferences through.
const _kotlinClassesJniLooksUp = [
  'kotlin.Unit',
  'kotlin.Result',
  r'kotlin.Result$Failure',
  'kotlin.coroutines.Continuation',
  'kotlin.coroutines.intrinsics.CoroutineSingletons',
  'kotlin.coroutines.intrinsics.IntrinsicsKt',
];

/// The 0.1.75 Android release build ran `jni` 1.1.0, which ships no R8 consumer
/// rules: R8 stripped those Kotlin classes, and every preferences read failed
/// with a `NoSuchMethodError`. `jni` 1.1.1 added the rules; this fails when a
/// dependency change brings back a `jni` without them.
void main() {
  test('jni keeps the Kotlin classes that suspend calls look up', () {
    final config = jsonDecode(
      File('.dart_tool/package_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final jni = (config['packages'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == 'jni');
    final root = Uri.parse(jni['rootUri'] as String);
    final dir = Directory.fromUri(
      root.isAbsolute ? root : Directory('.dart_tool').uri.resolveUri(root),
    );
    final rules = File('${dir.path}/android/consumer-rules.pro');

    expect(
      rules.existsSync(),
      isTrue,
      reason: 'jni ships no R8 consumer rules; use jni 1.1.1 or later',
    );
    final text = rules.readAsStringSync();
    for (final name in _kotlinClassesJniLooksUp) {
      expect(text, contains('-keep class $name '), reason: name);
    }
  });
}
