import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/quick_actions/quick_actions_port.dart';
import 'package:quick_actions/quick_actions.dart';

class RecordingPlugin extends QuickActions {
  final calls = <String>[];

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async =>
      calls.add('set ${items.length}');

  @override
  Future<void> clearShortcutItems() async => calls.add('clear');
}

void main() {
  test('no items clears the menu', () async {
    final plugin = RecordingPlugin();
    await PluginQuickActionsPort(plugin).setItems(const []);

    expect(plugin.calls, ['clear']);
  });

  test('items replace the menu', () async {
    final plugin = RecordingPlugin();
    await PluginQuickActionsPort(plugin).setItems(const [
      ShortcutItem(type: 'hermes://new', localizedTitle: 'New Chat'),
    ]);

    expect(plugin.calls, ['set 1']);
  });
}
