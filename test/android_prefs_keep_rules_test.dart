import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 0.1.75 Android release build ran `shared_preferences_android` 2.5.0,
/// whose JNI lookups R8 stripped: every read failed with a `NoSuchMethodError`.
/// Later releases keep those classes (`@Keep` in the plugin, consumer rules in
/// `jni`); this fails when an upgrade drops that.
void main() {
  late Directory Function(String) packageDir;

  setUpAll(() {
    final config = jsonDecode(
      File('.dart_tool/package_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final roots = {
      for (final p in config['packages'] as List<dynamic>)
        (p as Map<String, dynamic>)['name'] as String: Uri.parse(
          p['rootUri'] as String,
        ),
    };
    packageDir = (name) {
      final root = roots[name]!;
      return Directory.fromUri(
        root.isAbsolute ? root : Directory('.dart_tool').uri.resolveUri(root),
      );
    };
  });

  test('the Kotlin registrar the prefs plugin looks up by name survives R8', () {
    final plugin = packageDir('shared_preferences_android');
    final kotlin = File(
      '${plugin.path}/android/src/main/kotlin/io/flutter/plugins/'
      'sharedpreferences/MessagesAsync.g.kt',
    ).readAsStringSync();
    final kept = RegExp(r'@Keep\s+class SharedPreferencesAsyncApiRegistrar')
        .hasMatch(kotlin);
    final rules = File('${plugin.path}/android/consumer-rules.pro');
    final ruled =
        rules.existsSync() &&
        rules.readAsStringSync().contains('SharedPreferencesAsyncApiRegistrar');

    expect(
      kept || ruled,
      isTrue,
      reason:
          'shared_preferences_android neither annotates nor keeps its '
          'registrar class; add a keep rule to android/app/proguard-rules.pro',
    );
  });

  test('jni keeps the Kotlin classes that suspend calls look up', () {
    final rules = File('${packageDir('jni').path}/android/consumer-rules.pro')
        .readAsStringSync();

    expect(rules, contains('-keep class kotlin.coroutines.Continuation'));
  });
}
