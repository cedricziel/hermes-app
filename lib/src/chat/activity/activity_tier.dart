import '../billing_verification_controller.dart';
import '../chat_session_state.dart';
import '../connector_operation_controller.dart';
import '../connector_operation_state.dart';

/// What a piece of chat activity asks of the user.
enum ActivityTier {
  /// Waits on the user before the agent can go on.
  needsYou,

  /// Live work of the session.
  working,

  /// Worth knowing, never urgent.
  reference,
}

/// Activity whose tier never changes with its state.
enum ActivityKind {
  status(ActivityTier.working),
  control(ActivityTier.working),
  plan(ActivityTier.working),
  process(ActivityTier.working),
  moa(ActivityTier.working),
  resume(ActivityTier.working),
  screen(ActivityTier.working),
  usage(ActivityTier.reference),
  sideResult(ActivityTier.reference),
  notice(ActivityTier.reference),
  acknowledgement(ActivityTier.reference);

  const ActivityKind(this.tier);
  final ActivityTier tier;
}

ActivityTier connectorTier(
  ConnectorOperationSnapshot operation,
  ConnectorOperationController controller, {
  bool connectionWide = false,
}) {
  if (connectionWide || operation.settled) return ActivityTier.reference;
  final key = operation.key;
  final actionable =
      controller.canRespond(key) ||
      operation.targets.any(
        (target) =>
            controller.canOpen(key, target.name) ||
            controller.canSkip(key, target.name),
      );
  return actionable ? ActivityTier.needsYou : ActivityTier.reference;
}

ActivityTier billingTier(BillingVerificationController controller) =>
    controller.verification != null
    ? ActivityTier.needsYou
    : ActivityTier.reference;

ActivityTier sessionStateTier(ChatSessionState state) {
  if (state.reclaimedReason != null || state.resume?.status == 'failed') {
    return ActivityTier.needsYou;
  }
  if (state.control?.isEmpty == false ||
      state.resume != null ||
      state.waits.keys.any((kind) => kind != 'status' && kind != 'lifecycle')) {
    return ActivityTier.working;
  }
  return ActivityTier.reference;
}
