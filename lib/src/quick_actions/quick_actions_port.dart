import 'package:quick_actions/quick_actions.dart';

export 'package:quick_actions/quick_actions.dart' show ShortcutItem;

/// The app icon's long-press menu, as far as the controller needs it.
abstract interface class QuickActionsPort {
  /// Registers [onPick], which gets the type of the item that was picked,
  /// including the one that launched the app.
  Future<void> initialize(void Function(String type) onPick);

  /// Replaces all items.
  Future<void> setItems(List<ShortcutItem> items);
}

/// [QuickActionsPort] on the `quick_actions` plugin.
class PluginQuickActionsPort implements QuickActionsPort {
  const PluginQuickActionsPort([this._plugin = const QuickActions()]);

  final QuickActions _plugin;

  @override
  Future<void> initialize(void Function(String type) onPick) =>
      _plugin.initialize(onPick);

  @override
  Future<void> setItems(List<ShortcutItem> items) => items.isEmpty
      ? _plugin.clearShortcutItems()
      : _plugin.setShortcutItems(items);
}
