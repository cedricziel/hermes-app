import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// How a request to confirm the person ended.
enum DeviceAuthResult {
  /// The system confirmed the person.
  confirmed,

  /// Not confirmed: a cancel, a lockout, a timeout or any other error.
  failed,

  /// The device cannot confirm anyone: no passcode or biometrics set up, or
  /// no implementation on this platform.
  unavailable,
}

/// Asks the operating system to confirm that the person holding the device is
/// its owner: Face ID, Touch ID or fingerprint, or the device passcode.
abstract class DeviceAuthenticator {
  /// False when the device has no biometrics or passcode set up, or the
  /// platform has no support for either; null when the check itself failed,
  /// which says nothing about the device.
  Future<bool?> isAvailable();

  /// Asks the system to confirm the person.
  Future<DeviceAuthResult> authenticate(String reason);
}

class LocalDeviceAuthenticator implements DeviceAuthenticator {
  LocalDeviceAuthenticator({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// What [LocalAuthentication.authenticate] throws when no one can be
  /// confirmed on this device, as opposed to a confirmation that failed.
  static const _unavailableCodes = {
    LocalAuthExceptionCode.noCredentialsSet,
    LocalAuthExceptionCode.noBiometricHardware,
    LocalAuthExceptionCode.noBiometricsEnrolled,
  };

  @override
  Future<bool?> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on MissingPluginException {
      // No implementation on this platform (local_auth has none on Linux).
      return false;
    } on UnimplementedError {
      return false;
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
            localizedReason: reason,
            persistAcrossBackgrounding: true,
          )
          ? DeviceAuthResult.confirmed
          : DeviceAuthResult.failed;
    } on LocalAuthException catch (error) {
      return _unavailableCodes.contains(error.code)
          ? DeviceAuthResult.unavailable
          : DeviceAuthResult.failed;
    } on MissingPluginException {
      return DeviceAuthResult.unavailable;
    } on UnimplementedError {
      return DeviceAuthResult.unavailable;
    } on Object catch (_) {
      return DeviceAuthResult.failed;
    }
  }
}
