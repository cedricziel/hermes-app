import 'package:hermes_app/src/app_lock/device_authenticator.dart';

class FakeDeviceAuthenticator implements DeviceAuthenticator {
  FakeDeviceAuthenticator({this.available = true, this.succeeds = true});

  /// Null when the device could not tell.
  bool? available;
  bool succeeds;
  final reasons = <String>[];

  /// Runs while the prompt is up, as the app goes inactive under it.
  void Function()? onAuthenticate;

  /// When set, the prompt stays up until this completes.
  Future<bool>? answer;

  /// Whether the prompt reports that the device cannot confirm anyone.
  bool unavailable = false;

  @override
  Future<bool?> isAvailable() async => available;

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    reasons.add(reason);
    onAuthenticate?.call();
    if (unavailable) return DeviceAuthResult.unavailable;
    return await (answer ?? Future.value(succeeds))
        ? DeviceAuthResult.confirmed
        : DeviceAuthResult.failed;
  }
}
