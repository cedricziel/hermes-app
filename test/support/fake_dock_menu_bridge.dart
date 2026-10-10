import 'dart:async';

import 'package:hermes_app/src/macos/dock/dock_menu_bridge.dart';

/// Records what the Dock menu was given and lets a test pick its items.
class FakeDockMenuBridge extends DockMenuBridge {
  FakeDockMenuBridge() : super(enabled: false);

  final updates = <(DockMenuState, List<DockChat>)>[];
  // ignore: close_sinks
  final picks = StreamController<DockMenuAction>.broadcast(sync: true);

  @override
  Stream<DockMenuAction> get actions => picks.stream;

  @override
  Future<void> update(DockMenuState state, List<DockChat> chats) async =>
      updates.add((state, chats));

  /// The chat ids of the latest list, in order.
  List<String> get shownIds => [for (final c in updates.last.$2) c.id];
}
