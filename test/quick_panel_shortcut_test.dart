import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/quick_panel/quick_panel_shortcut.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_conversation_window_host.dart';
import 'support/fake_global_shortcut.dart';

void main() {
  late FakeConversationWindowHost host;
  late FakeGlobalShortcut shortcut;
  late BreadcrumbTrail trail;
  late List<(String, Map<String, Object>)> events;
  late ConversationWindows windows;
  late QuickPanelShortcut panelShortcut;
  ({String baseUrl, bool authRequired})? connection;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    host = FakeConversationWindowHost();
    shortcut = FakeGlobalShortcut();
    trail = BreadcrumbTrail();
    events = [];
    connection = (baseUrl: 'https://hermes.test', authRequired: true);
    windows = ConversationWindows(
      host: host,
      store: ConversationWindowStore(SharedPreferencesAsync()),
      connection: () => connection,
      headers: ({rejected}) async => const {},
    );
    panelShortcut = QuickPanelShortcut(
      shortcut: shortcut,
      windows: windows,
      events: (name, [attributes = const {}]) => events.add((name, attributes)),
      breadcrumbs: Breadcrumbs.of(trail),
    )..start();
  });

  tearDown(() {
    panelShortcut.dispose();
    windows.dispose();
    shortcut.dispose();
  });

  test('a press shows the panel while signed in', () async {
    shortcut.press();
    await pumpEventQueue();

    expect(host.panels, hasLength(1));
    expect(host.mainShown, 0);
    expect(trail.recent.map((c) => c.name), contains('panel.shortcut_pressed'));
  });

  test('a press without a connection brings the main window forward', () async {
    connection = null;

    shortcut.press();
    await pumpEventQueue();

    expect(host.panels, isEmpty);
    expect(host.mainShown, 1);
  });

  test('a recorded or cleared shortcut logs only whether one is set', () async {
    shortcut.change(set: true);
    shortcut.change(set: false);
    await pumpEventQueue();

    expect(
      [for (final (name, attributes) in events) '$name $attributes'],
      [
        'panel.shortcut_changed {set: true}',
        'panel.shortcut_changed {set: false}',
      ],
    );
  });
}
