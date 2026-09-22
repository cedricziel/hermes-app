import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that can outlive its screen: work still running after
/// [dispose] stops notifying instead of throwing.
mixin SafeNotifier on ChangeNotifier {
  bool _disposed = false;

  bool get disposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
