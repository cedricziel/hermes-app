import 'dart:async';

import 'package:flutter/services.dart';

import '../telemetry/breadcrumbs.dart';
import 'share_inbox.dart';
import 'shared_item.dart';

/// macOS, fed by the native Share Extension through the app delegate.
///
/// The extension leaves the shared content in the App Group container and
/// opens the app; the native side hands it over on `take` and tells Dart
/// with `shared` when the app is already running.
///
/// The Services menu's "Ask Hermes" goes the same way without the file: the
/// app delegate queues the selection in memory and answers `take` with it as
/// a text entry with `intent: ask`, which becomes a [SharedQuote].
class MacosShareInbox implements ShareInbox {
  MacosShareInbox({MethodChannel? channel, this.breadcrumbs = Breadcrumbs.none})
    : _channel = channel ?? const MethodChannel('hermes_app/share');

  final MethodChannel _channel;
  final Breadcrumbs breadcrumbs;
  late final StreamController<List<SharedItem>> _controller =
      StreamController.broadcast(
        onListen: () => _channel.setMethodCallHandler(_onCall),
        onCancel: () => _channel.setMethodCallHandler(null),
      );

  @override
  Future<List<SharedItem>> initialItems() => _take(launched: true);

  @override
  Stream<List<SharedItem>> get items => _controller.stream;

  @override
  Future<void> reset() async {}

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'shared') return;
    final items = await _take();
    if (items.isNotEmpty) _controller.add(items);
  }

  Future<List<SharedItem>> _take({bool launched = false}) async {
    final List<Object?> raw;
    try {
      raw = await _channel.invokeListMethod<Object?>('take') ?? const [];
    } on MissingPluginException {
      return const [];
    }
    return [for (final entry in raw) ?_itemFrom(entry, launched)];
  }

  SharedItem? _itemFrom(Object? entry, bool launched) {
    if (entry is! Map) return null;
    switch (entry['type']) {
      case 'text':
        final text = entry['text'];
        if (text is! String) return null;
        if (entry['intent'] != 'ask') return SharedText(text);
        if (text.trim().isEmpty) return null;
        final truncated = entry['truncated'] == true;
        breadcrumbs('service.ask.received', {
          'launched': launched,
          'truncated': truncated,
        });
        return SharedQuote(text, truncated: truncated);
      case 'dropped':
        final reason = entry['reason'];
        breadcrumbs('service.ask.dropped', {
          'reason': reason == 'empty' || reason == 'no_text'
              ? reason as String
              : 'unknown',
        });
        return null;
      case 'file':
        final path = entry['path'];
        final name = entry['name'];
        if (path is! String || name is! String) return null;
        return SharedFile(
          path: path,
          name: name,
          mimeType: entry['mimeType'] as String?,
          isImage: entry['isImage'] == true,
        );
    }
    return null;
  }
}
