import 'dart:async';

import 'package:flutter/foundation.dart';

import 'share_inbox.dart';
import 'shared_item.dart';

/// Holds shared content until the chat screen is ready to show it. Items
/// arriving before sign-in stay pending through setup and login.
class ShareController extends ChangeNotifier {
  ShareController(this._inbox);

  final ShareInbox _inbox;
  final List<SharedItem> _pending = [];
  StreamSubscription<List<SharedItem>>? _subscription;

  bool get hasPending => _pending.isNotEmpty;

  Future<void> start() async {
    _subscription = _inbox.items.listen(_add);
    final initial = await _inbox.initialItems();
    if (initial.isNotEmpty) {
      _add(initial);
      await _inbox.reset();
    }
  }

  /// Returns the pending items and clears them.
  List<SharedItem> take() {
    if (_pending.isEmpty) return const [];
    final taken = List<SharedItem>.of(_pending);
    _pending.clear();
    return taken;
  }

  void _add(List<SharedItem> items) {
    if (items.isEmpty) return;
    _pending.addAll(items);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
