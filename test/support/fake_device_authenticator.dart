import 'package:hermes_app/src/app_lock/device_authenticator.dart';

class FakeDeviceAuthenticator implements DeviceAuthenticator {
  FakeDeviceAuthenticator({this.available = true, this.succeeds = true});

  bool available;
  bool succeeds;
  final reasons = <String>[];

  /// Runs while the prompt is up, as the app goes inactive under it.
  void Function()? onAuthenticate;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    reasons.add(reason);
    onAuthenticate?.call();
    return succeeds;
  }
}
