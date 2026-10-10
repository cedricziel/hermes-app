import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, listEquals;
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../deep_links/deep_link_listener.dart';
import '../deep_links/deep_link_target.dart';
import '../surfaces/surface_snapshot.dart';
import '../surfaces/surface_snapshot_store.dart';
import '../telemetry/breadcrumbs.dart';
import 'quick_actions_items.dart';
import 'quick_actions_port.dart';

/// Keeps the app icon's long-press menu in step with the surface snapshot and
/// hands a picked item to the deep-link path.
class QuickActionsController {
  QuickActionsController({
    required this.port,
    required this.store,
    required this.open,
    this.ios = false,
    this.events = noopAppEventLogger,
    this.breadcrumbs = Breadcrumbs.none,
  });

  /// The app's controller, or null where there is no icon menu to fill or no
  /// snapshot to follow.
  static QuickActionsController? forPlatform({
    required SurfaceSnapshotStore? store,
    required DeepLinks? deepLinks,
    required TargetPlatform platform,
    AppEventLogger events = noopAppEventLogger,
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
    QuickActionsPort? port,
  }) {
    final ios = platform == TargetPlatform.iOS;
    if (store == null ||
        deepLinks == null ||
        (!ios && platform != TargetPlatform.android)) {
      return null;
    }
    return QuickActionsController(
      port: port ?? const PluginQuickActionsPort(),
      store: store,
      open: deepLinks.open,
      ios: ios,
      events: events,
      breadcrumbs: breadcrumbs,
    );
  }

  final QuickActionsPort port;
  final SurfaceSnapshotStore store;

  /// Where a picked item's link goes: `DeepLinks.open`.
  final PendingDeepLink? Function(Uri link) open;

  /// Whether the menu is iOS's, which can show a subtitle.
  final bool ios;
  final AppEventLogger events;
  final Breadcrumbs breadcrumbs;

  StreamSubscription<SurfaceSnapshot>? _writes;
  Future<void> _applying = Future.value();
  List<(String, String, String?)>? _applied;

  /// Registers the handler first, so an item that launched the app is not
  /// lost, then follows the snapshot.
  Future<void> start() async {
    try {
      await port.initialize(_onPick);
    } on Object catch (error) {
      _failed(error);
    }
    _writes = store.writes.listen(_enqueue);
    final current = await store.read();
    if (current != null) _enqueue(current);
  }

  void _enqueue(SurfaceSnapshot snapshot) {
    _applying = _applying.then((_) => _apply(snapshot));
  }

  Future<void> _apply(SurfaceSnapshot snapshot) async {
    final items = quickActionItems(snapshot, ios: ios);
    final key = [
      for (final item in items)
        (item.type, item.localizedTitle, item.localizedSubtitle),
    ];
    if (listEquals(_applied, key)) return;
    try {
      await port.setItems(items);
      _applied = key;
    } on Object catch (error) {
      _failed(error);
    }
  }

  void _onPick(String type) {
    final Uri link;
    try {
      link = Uri.parse(type);
    } on FormatException {
      return;
    }
    final pending = open(link);
    if (pending == null) return;
    final kind = switch (pending.target) {
      NewChat(dictate: true) => 'dictate',
      NewChat() => 'new_chat',
      OpenChat() => 'recent',
      _ => 'other',
    };
    try {
      events('quick_action.used', {'kind': kind});
    } on Object {
      // Telemetry must not break the app.
    }
    breadcrumbs('quick_action.opened', {
      'kind': kind,
      'cold_start': pending.cold,
    });
  }

  void _failed(Object error) {
    try {
      events('quick_actions.update_failed', {
        'error.type': error.runtimeType.toString(),
      });
    } on Object {
      // Telemetry must not break the app.
    }
  }

  Future<void> dispose() async {
    await _writes?.cancel();
    await _applying;
  }
}
