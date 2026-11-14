import '../../app_lock/app_lock_controller.dart';
import 'media_store.dart';

/// Deletes every Files download, and closes the Quick Look panel, each time
/// App Lock locks the app.
class FilesLockCleanup {
  FilesLockCleanup(this._lock, this._media) {
    _wasLocked = _lock.locked;
    _lock.addListener(_changed);
  }

  final AppLockController _lock;
  final MediaStore? _media;
  var _wasLocked = false;

  void _changed() {
    final locked = _lock.locked;
    if (locked && !_wasLocked) _media?.clearFileDownloads();
    _wasLocked = locked;
  }

  void dispose() => _lock.removeListener(_changed);
}
