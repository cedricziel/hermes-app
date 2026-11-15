import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';

/// Deletes a temp directory used by a [DurableQueueStore] once the store has
/// no operation left.
///
/// Code under test starts store writes it does not await (for example the
/// `accepted` write after Hermes takes a queued prompt). Deleting the
/// directory while one runs fails with "Directory not empty". The store runs
/// its operations in order per directory, so [DurableQueueStore.settle] waits
/// for every one, including those that earlier ones enqueue. Dispose the
/// controllers under test first so nothing new starts afterwards.
Future<void> deleteQueueStoreDir(Directory directory) async {
  await pumpEventQueue();
  await DurableQueueStore.settle(directory);
  await directory.delete(recursive: true);
}
