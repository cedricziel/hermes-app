import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/surfaces/widget_usage_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/recorded_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordedEvents events;
  late List<MethodCall> calls;
  late Object? Function() installed;
  late DateTime now;

  WidgetUsageReporter reporter() => WidgetUsageReporter(
    events: events.call,
    prefs: SharedPreferencesAsync(),
    clock: () => now,
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    events = RecordedEvents();
    calls = [];
    now = DateTime.utc(2026, 10, 10, 12);
    installed = () => [
      {'kind': 'HermesRecentChats', 'family': 'systemMedium'},
      {'kind': 'HermesRecentChats', 'family': 'systemMedium'},
      {'kind': 'HermesBoard', 'family': 'systemSmall'},
      {'kind': 'HermesNewChat', 'family': 'accessoryCircular'},
      {'kind': 'SomeoneElsesWidget', 'family': 'systemSmall'},
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (
          call,
        ) async {
          calls.add(call);
          if (call.method == 'getInstalledWidgets') return installed();
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), null),
    );
  });

  test('logs the installed widgets per kind and family', () async {
    await reporter().report();

    expect(events.named('widgets.installed'), [
      {
        'widgets.count': 4,
        'widgets.kinds':
            'HermesBoard/systemSmall=1,'
            'HermesNewChat/accessoryCircular=1,'
            'HermesRecentChats/systemMedium=2',
      },
    ]);
  });

  test('logs nothing but a count when no widget is installed', () async {
    installed = () => <Object?>[];

    await reporter().report();

    expect(events.named('widgets.installed'), [
      {'widgets.count': 0, 'widgets.kinds': ''},
    ]);
  });

  test('does not report again within 24 hours', () async {
    await reporter().report();
    now = now.add(const Duration(hours: 23, minutes: 59));

    await reporter().report();

    expect(events.named('widgets.installed'), hasLength(1));
    expect(calls.where((c) => c.method == 'getInstalledWidgets'), hasLength(1));
  });

  test('reports again after 24 hours', () async {
    await reporter().report();
    now = now.add(const Duration(hours: 24));

    await reporter().report();

    expect(events.named('widgets.installed'), hasLength(2));
  });

  test('logs nothing and tries again when the plugin throws', () async {
    installed = () => throw PlatformException(code: 'unavailable');

    await reporter().report();
    installed = () => <Object?>[];
    await reporter().report();

    expect(events.named('widgets.installed'), hasLength(1));
  });

  test('a failing logger does not throw', () async {
    final failing = WidgetUsageReporter(
      events: (name, [attributes = const {}]) => throw StateError('no sink'),
      prefs: SharedPreferencesAsync(),
      clock: () => now,
    );

    await failing.report();
  });
}
