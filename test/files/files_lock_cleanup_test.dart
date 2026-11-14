import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/media/files_lock_cleanup.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/files/files_controller.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/attachment_fixtures.dart';
import '../support/fake_device_authenticator.dart';
import '../support/fake_files_source.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_quick_look.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'App Lock locking deletes Files downloads and closes Quick Look',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final lock = AppLockController(authenticator: FakeDeviceAuthenticator());
      addTearDown(lock.dispose);
      await lock.load();
      await lock.setEnabled(true);
      final cache = tempDir('files_lock');
      final quickLook = FakeQuickLook();
      final media = MediaStore(
        source: HermesMediaSource(() => FakeHermesServer().client()),
        cacheDirectory: () async => cache,
        quickLook: quickLook,
      );
      // Staged by the controller itself, under the key it really uses.
      final source = FakeFilesSource();
      source.downloads['/srv/p/a.zip'] = writes([1, 2], length: 2);
      final controller = FilesController(
        source: source,
        media: media,
        profile: 'work',
        cwd: p('/srv/p'),
      );
      addTearDown(controller.dispose);
      source.lists['/srv/p'] = () => listing([file('/srv/p/a.zip')]);
      source.gitRoots['/srv/p'] = () => ok<ServerPath?>(null);
      await controller.start();
      await controller.select(controller.entries.single);
      await controller.openWith();
      await media.stage(
        '${kSecretCopyKeyPrefix}work:/.env',
        '.env',
        () async => kTinyPng,
      );
      final attachment = await media.stage(
        'chat:1',
        'b.png',
        () async => kTinyPng,
      );
      final cleanup = FilesLockCleanup(lock, media);
      addTearDown(cleanup.dispose);

      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(lock.locked, isTrue);
      bool leftOver() => cache
          .listSync(recursive: true)
          .any((e) => e.path.endsWith('.zip') || e.path.endsWith('.env'));
      for (var i = 0; i < 100 && leftOver(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(quickLook.closes, greaterThan(0));
      expect(leftOver(), isFalse);
      expect(attachment.existsSync(), isTrue);
    },
  );
}
