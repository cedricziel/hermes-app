import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'macos_share_inbox.dart';
import 'plugin_share_inbox.dart';
import 'shared_item.dart';

/// Where shared content enters the app. Each platform feeds this from its
/// own share extension or intent; [ShareController] is the only consumer.
abstract class ShareInbox {
  /// Items that were shared while the app was closed, i.e. that launched it.
  Future<List<SharedItem>> initialItems();

  /// Items shared while the app is already running.
  Stream<List<SharedItem>> get items;

  /// Tells the platform the launch items were handled so they aren't
  /// delivered again on the next start.
  Future<void> reset();
}

/// For platforms without a share target (Linux, Windows, web).
class NoopShareInbox implements ShareInbox {
  const NoopShareInbox();

  @override
  Future<List<SharedItem>> initialItems() async => const [];

  @override
  Stream<List<SharedItem>> get items => const Stream.empty();

  @override
  Future<void> reset() async {}
}

ShareInbox createPlatformShareInbox() {
  if (kIsWeb) return const NoopShareInbox();
  if (Platform.isIOS || Platform.isAndroid) return PluginShareInbox();
  if (Platform.isMacOS) return MacosShareInbox();
  return const NoopShareInbox();
}
