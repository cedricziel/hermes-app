import 'dart:async';

import 'package:flutter/foundation.dart';

import 'share_inbox.dart';
import 'shared_item.dart';

/// Holds shared content until the chat screen is ready to show it. Items
/// arriving before sign-in stay pending through setup and login.
///
/// A [SharedQuote] is selected text from another app. Only the latest one
/// waits, and it is dropped on sign-out ([signedOut]) so the next user does
/// not receive it.
class ShareController extends ChangeNotifier {
  ShareController(this._inbox, {Stream<void>? signedOut}) {
    _signedOut = signedOut?.listen((_) => discardQuotes());
  }

  final ShareInbox _inbox;
  final List<SharedItem> _pending = [];
  StreamSubscription<List<SharedItem>>? _subscription;
  StreamSubscription<void>? _signedOut;

  bool get hasPending => _pending.isNotEmpty;

  /// Identifies the initial-inbox notification while listeners run.
  bool get deliveringInitial => _deliveringInitial;
  bool _deliveringInitial = false;

  Future<void> start() async {
    _subscription = _inbox.items.listen(_add);
    final initial = await _inbox.initialItems();
    if (initial.isNotEmpty) {
      _add(initial, initial: true);
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

  /// Forgets the quotes still waiting.
  void discardQuotes() => _pending.removeWhere((i) => i is SharedQuote);

  void _add(List<SharedItem> items, {bool initial = false}) {
    if (items.isEmpty) return;
    if (initial) {
      _pending.insertAll(0, items);
    } else {
      _pending.addAll(items);
    }
    final latest = _pending.whereType<SharedQuote>().lastOrNull;
    _pending.removeWhere((i) => i is SharedQuote && !identical(i, latest));
    _deliveringInitial = initial;
    try {
      notifyListeners();
    } finally {
      _deliveringInitial = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _signedOut?.cancel();
    super.dispose();
  }
}
