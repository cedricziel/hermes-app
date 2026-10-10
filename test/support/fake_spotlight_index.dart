import 'dart:async';

import 'package:hermes_app/src/spotlight/spotlight_index.dart';

/// A [SpotlightIndex] that records its calls and holds the items it would
/// show, per domain.
class FakeSpotlightIndex implements SpotlightIndex {
  /// Every call, as `replace chat`, `deleteDomain chat` or `deleteAll`.
  final calls = <String>[];

  /// The `(upsert, remove)` of every `update` call.
  final updates = <(List<SpotlightItem>, List<String>)>[];

  /// What Spotlight would list now.
  final items = <String, List<SpotlightItem>>{};

  /// Whether the next calls succeed.
  var succeeds = true;

  /// Whether the device lets the index be used (false while it is locked).
  var available = true;

  final becameAvailableController = StreamController<void>.broadcast(
    sync: true,
  );

  /// Held calls wait on this before they answer.
  Completer<void>? gate;

  /// Returned once by [takeLaunch].
  Uri? launch;

  final openedController = StreamController<Uri>.broadcast(sync: true);

  var _inFlight = 0;

  /// The most calls that were ever running together.
  var maxInFlight = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<void> get becameAvailable => becameAvailableController.stream;

  @override
  Stream<Uri> get opened => openedController.stream;

  @override
  Future<Uri?> takeLaunch() async {
    final link = launch;
    launch = null;
    return link;
  }

  Future<bool> _call(String call, void Function() apply) async {
    calls.add(call);
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      await gate?.future;
      if (!succeeds) return false;
      apply();
      return true;
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<bool> replace(String domain, List<SpotlightItem> items) =>
      _call('replace $domain', () => this.items[domain] = items);

  @override
  Future<bool> update(
    String domain, {
    required List<SpotlightItem> upsert,
    required List<String> remove,
  }) => _call('update $domain', () {
    updates.add((upsert, remove));
    final held = [...?items[domain]]
      ..removeWhere((i) => remove.contains(i.url));
    for (final item in upsert) {
      final at = held.indexWhere((i) => i.url == item.url);
      at < 0 ? held.add(item) : held[at] = item;
    }
    items[domain] = held;
  });

  @override
  Future<bool> deleteDomain(String domain) =>
      _call('deleteDomain $domain', () => items.remove(domain));

  @override
  Future<bool> deleteAll() => _call('deleteAll', items.clear);

  @override
  void dispose() {
    unawaited(openedController.close());
    unawaited(becameAvailableController.close());
  }
}
