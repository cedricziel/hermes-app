import 'dart:async';

import 'package:hermes_app/src/spotlight/spotlight_index.dart';

/// A [SpotlightIndex] that records its calls and holds the items it would
/// show, per domain.
class FakeSpotlightIndex implements SpotlightIndex {
  /// Every call, as `replace chat`, `deleteDomain chat` or `deleteAll`.
  final calls = <String>[];

  /// What Spotlight would list now.
  final items = <String, List<SpotlightItem>>{};

  /// Whether the next calls succeed.
  var succeeds = true;

  /// Held calls wait on this before they answer.
  Completer<void>? gate;

  /// Returned once by [takeLaunch].
  Uri? launch;

  final openedController = StreamController<Uri>.broadcast(sync: true);

  var _inFlight = 0;

  /// The most calls that were ever running together.
  var maxInFlight = 0;

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
  Future<bool> deleteDomain(String domain) =>
      _call('deleteDomain $domain', () => items.remove(domain));

  @override
  Future<bool> deleteAll() => _call('deleteAll', items.clear);

  @override
  void dispose() {
    unawaited(openedController.close());
  }
}
