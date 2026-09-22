import 'package:local_auth/local_auth.dart';

/// Asks the operating system to confirm that the person holding the device is
/// its owner: Face ID, Touch ID or fingerprint, or the device passcode.
abstract class DeviceAuthenticator {
  /// False when the device has no biometrics or passcode set up, or the
  /// platform has no support for either.
  Future<bool> isAvailable();

  /// True only when the system confirmed the person. A cancel, a lockout or
  /// any error is false.
  Future<bool> authenticate(String reason);
}

class LocalDeviceAuthenticator implements DeviceAuthenticator {
  LocalDeviceAuthenticator({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on Object catch (_) {
      return false;
    }
  }
}
