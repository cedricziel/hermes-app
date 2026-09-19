import 'dart:async';

import 'package:flutter/services.dart';

import 'share_inbox.dart';
import 'shared_item.dart';

/// macOS, fed by the native Share Extension through the app delegate.
///
/// The extension leaves the shared content in the App Group container and
/// opens the app; the native side hands it over on `take` and tells Dart
/// with `shared` when the app is already running.
class MacosShareInbox implements ShareInbox {
  MacosShareInbox({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('hermes_app/share');

  final MethodChannel _channel;
  late final StreamController<List<SharedItem>> _controller =
      StreamController.broadcast(
        onListen: () => _channel.setMethodCallHandler(_onCall),
        onCancel: () => _channel.setMethodCallHandler(null),
      );

  @override
  Future<List<SharedItem>> initialItems() => _take();

  @override
  Stream<List<SharedItem>> get items => _controller.stream;

  @override
  Future<void> reset() async {}

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'shared') return;
    final items = await _take();
    if (items.isNotEmpty) _controller.add(items);
  }

  Future<List<SharedItem>> _take() async {
    final List<Object?> raw;
    try {
      raw = await _channel.invokeListMethod<Object?>('take') ?? const [];
    } on MissingPluginException {
      return const [];
    }
    return [for (final entry in raw) ?_itemFrom(entry)];
  }

  SharedItem? _itemFrom(Object? entry) {
    if (entry is! Map) return null;
    switch (entry['type']) {
      case 'text':
        final text = entry['text'];
        return text is String ? SharedText(text) : null;
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
