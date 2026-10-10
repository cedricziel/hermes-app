import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/spotlight/spotlight_settings.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late SharedPreferencesAsync prefs;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  test('is off until loaded, and off on a fresh install', () async {
    final settings = SpotlightSettings(prefs: prefs);
    expect(settings.enabled, isFalse);
    expect(settings.loaded, isFalse);

    await settings.load();

    expect(settings.enabled, isFalse);
    expect(settings.loaded, isTrue);
  });

  test('keeps the choice across launches', () async {
    await SpotlightSettings(prefs: prefs).setEnabled(true);

    final next = SpotlightSettings(prefs: prefs);
    await next.load();

    expect(next.enabled, isTrue);
  });

  test('a change made while loading wins over the saved value', () async {
    await prefs.setBool('hermes.spotlight', true);
    final settings = SpotlightSettings(prefs: prefs);

    final loading = settings.load();
    final saving = settings.setEnabled(false);
    await loading;
    await saving;

    expect(settings.enabled, isFalse);
    expect(await prefs.getBool('hermes.spotlight'), isFalse);
  });

  test('notifies listeners and leaves a breadcrumb for each change', () async {
    final trail = BreadcrumbTrail();
    final settings = SpotlightSettings(
      prefs: prefs,
      breadcrumbs: Breadcrumbs.of(trail),
    );
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setEnabled(true);
    await settings.setEnabled(true);
    await settings.setEnabled(false);

    expect(notified, 2);
    expect(
      [for (final c in trail.recent) '${c.name} ${c.attributes}'],
      [
        'spotlight.toggled {enabled: true}',
        'spotlight.toggled {enabled: false}',
      ],
    );
  });

  group('offered', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('only on iOS', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          SpotlightSettings.offered,
          platform == TargetPlatform.iOS,
          reason: '$platform',
        );
      }
    });
  });
}
