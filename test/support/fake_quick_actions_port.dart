import 'package:hermes_app/src/quick_actions/quick_actions_port.dart';

/// A [QuickActionsPort] that records what the controller sets.
class FakeQuickActionsPort implements QuickActionsPort {
  final calls = <String>[];
  final sets = <List<ShortcutItem>>[];
  void Function(String type)? onPick;

  /// Thrown by [setItems] while set.
  Error? failure;

  List<ShortcutItem> get items => sets.lastOrNull ?? const [];

  /// What the user picks from the menu.
  void pick(String type) => onPick!(type);

  @override
  Future<void> initialize(void Function(String type) onPick) async {
    calls.add('initialize');
    this.onPick = onPick;
  }

  @override
  Future<void> setItems(List<ShortcutItem> items) async {
    calls.add('setItems');
    if (failure case final error?) throw error;
    sets.add(items);
  }
}
