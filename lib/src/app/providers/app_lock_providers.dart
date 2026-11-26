import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../app_lock/app_lock_controller.dart';
import '../../auth/auth_controller.dart';
import '../../chat/media/files_lock_cleanup.dart';
import '../../chat/media/media_store.dart';
import '../../chat/queue_storage/durable_queue_store.dart';
import '../../chat/queue_storage/queue_persistence.dart';
import '../../chat/tool_image_loader.dart';
import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';

/// App Lock and the durable queues that follow it.
List<SingleChildWidget> appLockProviders(Telemetry telemetry) => [
  ChangeNotifierProvider(
    lazy: false,
    create: (_) => AppLockController()..load(),
  ),
  // What Files downloaded goes the moment the app locks.
  Provider<FilesLockCleanup>(
    lazy: false,
    create: (context) => FilesLockCleanup(
      context.read<AppLockController>(),
      context.read<MediaStore?>(),
    ),
    dispose: (_, cleanup) => cleanup.dispose(),
  ),
  // Images a tool result named, from other hosts and in memory only: gone on
  // sign-out, a server change and each time the app locks.
  Provider<ToolImageLoader?>(
    lazy: false,
    create: (context) {
      final lock = context.read<AppLockController>();
      return ToolImageLoader(breadcrumbs: context.read<Breadcrumbs>())
        ..clearOnSignOut(context.read<AuthController>().signedOut)
        ..clearWhenLocked(lock, () => lock.locked);
    },
    dispose: (_, loader) => loader?.dispose(),
  ),
  ChangeNotifierProvider<QueuePersistence>(
    lazy: false,
    create: (context) => QueuePersistence(
      auth: context.read<AuthController>(),
      lock: context.read<AppLockController>(),
      factory: () => DurableQueueStore.open(events: telemetry.events()),
    )..start(),
  ),
];
