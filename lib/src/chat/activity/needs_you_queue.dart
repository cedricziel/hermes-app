import 'package:flutter/foundation.dart';

import '../../telemetry/breadcrumbs.dart';
import '../billing_verification_controller.dart';
import '../chat_session_state.dart';
import '../connector_operation_controller.dart';
import 'activity_tier.dart';
import 'widgets/needs_you_models.dart';

/// What the queue reads for the open chat: the three places a request that
/// waits on the user comes from. Anything may be null, and a new [scope]
/// (the chat) starts the queue over.
typedef NeedsYouSources = ({
  Object? scope,
  BillingVerificationController? billing,
  ConnectorOperationController? connector,
  ChatSessionState? session,
});

/// A request that waits on the user: its key, its kind and when the queue
/// first saw it. Nothing else of it, never a code, link, name or reason.
class NeedsYouEntry {
  const NeedsYouEntry({
    required this.key,
    required this.kind,
    required this.since,
  });

  /// Stable while the request waits; the dock's item id.
  final String key;
  final NeedsYouKind kind;
  final DateTime since;
}

/// The requests that wait on the user in one chat, oldest first, and which
/// of them the dock shows.
///
/// It reads [read] again whenever [changes] fires and keeps only item keys
/// and first-seen times: an item leaves when its source stops calling it
/// Needs you (`activity_tier.dart`), and a new one is announced through
/// [onArrived] once. The shown position follows its item, or its slot when
/// the item leaves, so a re-render never moves the card.
///
/// It records `chat.activity.needs_you.shown` (kind, count) when another item
/// comes to the front and `chat.activity.needs_you.paged` (count) when the
/// user pages, and nothing about what the items say.
class NeedsYouQueue extends ChangeNotifier {
  NeedsYouQueue({
    required Listenable changes,
    required this._read,
    DateTime Function()? now,
    this.breadcrumbs = Breadcrumbs.none,
    this.onArrived,
  }) : _changes = changes,
       _now = now ?? DateTime.now {
    changes.addListener(refresh);
    refresh();
  }

  final Listenable _changes;
  final NeedsYouSources Function() _read;
  final DateTime Function() _now;
  final Breadcrumbs breadcrumbs;

  /// Called once for each item that joins the queue.
  final void Function(NeedsYouEntry entry)? onArrived;

  final _seen = <String, ({DateTime since, int serial})>{};
  var _serial = 0;
  Object? _scope;
  var _entries = const <NeedsYouEntry>[];
  var _shown = 0;
  String? _shownKey, _frontKey;
  var _disposed = false;

  /// Oldest first.
  List<NeedsYouEntry> get entries => _entries;
  int get count => _entries.length;

  /// The index of the item on the card; 0 when the queue is empty.
  int get shown => _shown;

  /// Shows the item at [index], as the user paged to it.
  void show(int index) {
    if (_disposed || _entries.isEmpty) return;
    final next = index.clamp(0, _entries.length - 1);
    if (next == _shown) return;
    _shown = next;
    _shownKey = _frontKey = _entries[next].key;
    breadcrumbs('chat.activity.needs_you.paged', {'count': _entries.length});
    notifyListeners();
  }

  /// Reads the sources again.
  void refresh() {
    if (_disposed) return;
    final sources = _read();
    if (sources.scope != _scope) {
      _scope = sources.scope;
      _seen.clear();
      _entries = const [];
      _shown = 0;
      _shownKey = _frontKey = null;
    }
    final found = _collect(sources);
    final keys = {for (final (key, _) in found) key};
    _seen.removeWhere((key, _) => !keys.contains(key));
    final arrived = <NeedsYouEntry>[];
    final entries = <NeedsYouEntry>[];
    for (final (key, kind) in found) {
      final seen = _seen[key] ??= (since: _now(), serial: _serial++);
      final entry = NeedsYouEntry(key: key, kind: kind, since: seen.since);
      entries.add(entry);
      if (!_entries.any((known) => known.key == key)) arrived.add(entry);
    }
    entries.sort(
      (a, b) => _seen[a.key]!.serial.compareTo(_seen[b.key]!.serial),
    );

    var shown = entries.indexWhere((entry) => entry.key == _shownKey);
    if (shown < 0) {
      shown = entries.isEmpty ? 0 : _shown.clamp(0, entries.length - 1);
    }
    final changed =
        shown != _shown ||
        entries.length != _entries.length ||
        [for (final e in entries) e.key].join('\n') !=
            [for (final e in _entries) e.key].join('\n');
    _entries = List.unmodifiable(entries);
    _shown = shown;
    _shownKey = entries.isEmpty ? null : entries[shown].key;

    final front = _shownKey;
    if (front != _frontKey) {
      _frontKey = front;
      if (front != null) {
        breadcrumbs('chat.activity.needs_you.shown', {
          'kind': entries[shown].kind.name,
          'count': entries.length,
        });
      }
    }
    if (changed) notifyListeners();
    for (final entry in arrived) {
      onArrived?.call(entry);
    }
  }

  List<(String, NeedsYouKind)> _collect(NeedsYouSources sources) {
    final found = <(String, NeedsYouKind)>[];
    final state = sources.session;
    if (state != null &&
        state.visible &&
        sessionStateTier(state) == ActivityTier.needsYou) {
      final reclaimed = state.reclaimedReason != null;
      found.add((
        '${reclaimed ? 'reclaim' : 'resume'}:${state.runtimeId}',
        reclaimed ? NeedsYouKind.reclaim : NeedsYouKind.resume,
      ));
    }
    final billing = sources.billing;
    if (billing != null &&
        billing.supported &&
        billingTier(billing) == ActivityTier.needsYou) {
      found.add(('billing:${billing.generation}', NeedsYouKind.billing));
    }
    final connector = sources.connector;
    if (connector != null) {
      for (final operation in connector.operations) {
        if (operation.owner.type == 'session' &&
            connectorTier(operation, connector) == ActivityTier.needsYou) {
          found.add((
            'connector:${operation.owner.sessionId}:${operation.opId}',
            NeedsYouKind.connector,
          ));
        }
      }
    }
    return found;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _changes.removeListener(refresh);
    super.dispose();
  }
}
