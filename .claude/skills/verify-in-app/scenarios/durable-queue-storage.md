## Durable local queue storage

Run `flutter test --concurrency=1 test/chat/queue_storage` with its real temporary directories and fake key adapter. Verify restart recovery, deleting original attachment files, independent corrupted records, missing or unavailable keys, concurrent adapters, interrupted commits, and cleanup after sign-out. These checks establish the storage adapter, not controller recovery or native keychain behavior.

Native checks use the isolated client and disposable data. Confirm the `hermes_app/queue_storage` directory is app-private and excluded from supported OS automatic backup. On iOS verify complete file protection and private directory permissions; on Android verify `noBackupFilesDir`; on macOS verify backup exclusion and private permissions. Queue keys use their own namespace and must not change token-storage options. Arbitrary user or administrator backups are outside app control; do not promise their exclusion or forensic erasure.
