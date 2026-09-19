import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'share_inbox.dart';
import 'shared_item.dart';

/// iOS and Android, backed by the `receive_sharing_intent` plugin.
class PluginShareInbox implements ShareInbox {
  @override
  Future<List<SharedItem>> initialItems() async => sharedItemsFromMedia(
    await ReceiveSharingIntent.instance.getInitialMedia(),
  );

  @override
  Stream<List<SharedItem>> get items =>
      ReceiveSharingIntent.instance.getMediaStream().map(sharedItemsFromMedia);

  @override
  Future<void> reset() => ReceiveSharingIntent.instance.reset();
}

List<SharedItem> sharedItemsFromMedia(List<SharedMediaFile> media) {
  return [
    for (final file in media)
      switch (file.type) {
        SharedMediaType.text || SharedMediaType.url => SharedText(file.path),
        SharedMediaType.image ||
        SharedMediaType.video ||
        SharedMediaType.file => SharedFile(
          path: file.path,
          name: file.path.split('/').last,
          mimeType: file.mimeType,
          isImage: file.type == SharedMediaType.image,
        ),
      },
  ];
}
