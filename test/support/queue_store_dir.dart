import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';

bool _isNotEmpty(FileSystemException error) {
  final code = error.osError?.errorCode;
  return code == 39 || // ENOTEMPTY on Linux
      code == 66 || // ENOTEMPTY on macOS
      code == 145 || // ERROR_DIR_NOT_EMPTY on Windows
      error.message.contains('not empty') ||
      (error.osError?.message.contains('not empty') ?? false);
}

/// Deletes a temp directory used by a [DurableQueueStore] once nothing is
/// still writing into it, and returns how many rounds that took (1 when
/// nothing was pending).
///
/// Code under test starts store writes it does not await (for example the
/// `accepted` write after Hermes takes a queued prompt). Deleting the
/// directory while one runs fails with "Directory not empty".
/// [DurableQueueStore.settle] waits for every queued operation and those a
/// finished one enqueues from a microtask.
///
/// This is a bounded retry, and only on that one error. The controller's
/// dispatch chain has real I/O and timer gaps between two store operations,
/// and no public API lets a test await it, so a write can still arrive after
/// `settle` returned. A round pumps the event queue, settles and tries the
/// delete again, until [timeout]; it never sleeps a fixed time. Any other
/// error is rethrown at once. A directory that does not empty in time fails
/// with a listing of what is left, so a real leak still fails the test.
///
/// Follow-up that removes the loop: a test-only idle future on the
/// controller. Dispose the controllers under test first so nothing new
/// starts.
Future<int> deleteQueueStoreDir(
  Directory directory, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  var rounds = 0;
  while (true) {
    rounds++;
    await pumpEventQueue();
    await DurableQueueStore.settle(directory);
    try {
      await directory.delete(recursive: true);
      return rounds;
    } on FileSystemException catch (error) {
      if (!_isNotEmpty(error)) rethrow;
      if (!DateTime.now().isBefore(deadline)) {
        final left = directory
            .listSync(recursive: true, followLinks: false)
            .map((entry) => entry.path.substring(directory.path.length))
            .join(', ');
        throw FileSystemException(
          'Queue store directory still not empty after $timeout and $rounds '
          'rounds; left: $left (${error.message})',
          directory.path,
          error.osError,
        );
      }
    }
  }
}
