import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../app_lock/app_lock_controller.dart';
import '../../auth/auth_controller.dart';
import '../../chat/queue_storage/durable_queue_store.dart';
import '../../chat/queue_storage/queue_persistence.dart';
import '../../telemetry/telemetry.dart';

/// App Lock and the durable queues that follow it.
List<SingleChildWidget> appLockProviders(Telemetry telemetry) => [
  ChangeNotifierProvider(
    lazy: false,
    create: (_) => AppLockController()..load(),
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
