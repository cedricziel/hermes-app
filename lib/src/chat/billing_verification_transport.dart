import 'owned_session_transport.dart';

abstract interface class BillingVerificationTransport {
  bool billingVerificationSupported(OwnedSessionBinding binding);
  Future<Map<String, Object?>> stepUpBilling(
    OwnedSessionBinding binding, {
    required bool Function() authorize,
  });
}
