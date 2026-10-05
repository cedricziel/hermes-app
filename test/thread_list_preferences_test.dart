import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/thread_list_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('late restore does not overwrite a newer choice', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('chat.thread-list.iOS.grouping', 'folder');
    final controller = ThreadListPreferences(platform: 'iOS', prefs: prefs);
    addTearDown(controller.dispose);
    final loading = controller.load();
    controller.choose(ThreadGrouping.recent);
    await loading;
    expect(controller.grouping, ThreadGrouping.recent);
  });

  test('platform preferences remain independent', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('chat.thread-list.iOS.grouping', 'folder');
    await prefs.setStringList('chat.thread-list.iOS.folded', [
      'folder:/code/app',
    ]);
    final ios = ThreadListPreferences(platform: 'iOS', prefs: prefs);
    final mac = ThreadListPreferences(platform: 'macOS', prefs: prefs);
    addTearDown(ios.dispose);
    addTearDown(mac.dispose);
    await ios.load();
    await mac.load();
    expect(ios.grouping, ThreadGrouping.folder);
    expect(ios.isCollapsed('folder:/code/app'), isTrue);
    expect(mac.grouping, ThreadGrouping.recent);
    expect(mac.isCollapsed('folder:/code/app'), isFalse);
  });
}
