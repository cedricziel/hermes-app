import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

/// One thing Spotlight can find and open.
@immutable
class SpotlightItem {
  const SpotlightItem({
    required this.domain,
    required this.id,
    required this.title,
    required this.text,
    required this.url,
  });

  /// The kind of thing, such as `chat`. Replacing or deleting a domain leaves
  /// the others alone.
  final String domain;

  /// Tells the item apart within its [domain].
  final String id;
  final String title;
  final String text;

  /// The `hermes://` link a tap on the result opens. It is also what
  /// Spotlight hands back, since the system returns nothing else.
  final String url;

  @override
  bool operator ==(Object other) =>
      other is SpotlightItem &&
      other.domain == domain &&
      other.id == id &&
      other.title == title &&
      other.text == text &&
      other.url == url;

  @override
  int get hashCode => Object.hash(domain, id, title, text, url);
}

/// The system search index. Every call answers whether it worked and never
/// throws: Spotlight is a convenience, and a failed call is retried by the
/// caller's next change.
abstract interface class SpotlightIndex {
  /// The index of this platform: Spotlight on iOS, nothing elsewhere.
  factory SpotlightIndex.forPlatform({
    AppEventLogger events = noopAppEventLogger,
  }) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? ChannelSpotlightIndex(events: events)
      : const NoSpotlightIndex();

  /// Makes [items] the whole of [domain]: new ones are added, changed ones
  /// updated and the rest removed.
  Future<bool> replace(String domain, List<SpotlightItem> items);

  Future<bool> deleteDomain(String domain);

  /// Removes everything Hermes put in Spotlight, in every domain.
  Future<bool> deleteAll();

  /// The links of results tapped while the app runs.
  Stream<Uri> get opened;

  /// The link of the result that launched the app, once.
  Future<Uri?> takeLaunch();

  void dispose();
}

/// The index where the platform has none.
class NoSpotlightIndex implements SpotlightIndex {
  const NoSpotlightIndex();

  @override
  Future<bool> replace(String domain, List<SpotlightItem> items) async => true;

  @override
  Future<bool> deleteDomain(String domain) async => true;

  @override
  Future<bool> deleteAll() async => true;

  @override
  Stream<Uri> get opened => const Stream.empty();

  @override
  Future<Uri?> takeLaunch() async => null;

  @override
  void dispose() {}
}

/// [SpotlightIndex] over the Runner's `hermes_app/spotlight` channel
/// (`Spotlight.swift`).
class ChannelSpotlightIndex implements SpotlightIndex {
  ChannelSpotlightIndex({this.events = noopAppEventLogger}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'opened') return;
      if (await takeLaunch() case final link?) _opened.add(link);
    });
  }

  final AppEventLogger events;
  final _channel = const MethodChannel('hermes_app/spotlight');
  final _opened = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get opened => _opened.stream;

  @override
  Future<bool> replace(String domain, List<SpotlightItem> items) =>
      _call('replace', 'replace', domain, {
        'domain': domain,
        'items': [
          for (final item in items)
            {'url': item.url, 'title': item.title, 'text': item.text},
        ],
      });

  @override
  Future<bool> deleteDomain(String domain) =>
      _call('deleteDomain', 'delete_domain', domain, {'domain': domain});

  @override
  Future<bool> deleteAll() => _call('deleteAll', 'delete_all', 'all', null);

  @override
  Future<Uri?> takeLaunch() async {
    try {
      final link = await _channel.invokeMethod<String>('take');
      return link == null ? null : Uri.tryParse(link);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Calls [method]; a failure is logged as [operation] on [domain].
  Future<bool> _call(
    String method,
    String operation,
    String domain,
    Map<String, Object?>? arguments,
  ) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return true;
    } on Object catch (error) {
      try {
        events('spotlight.index_failed', {
          'operation': operation,
          'spotlight.domain': domain,
          'error.type': error.runtimeType.toString(),
        });
      } on Object {
        // Telemetry must not break the app.
      }
      return false;
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_opened.close());
  }
}
