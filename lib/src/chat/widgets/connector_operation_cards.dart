import 'dart:async';

import 'package:flutter/widgets.dart';

import '../activity/activity_tier.dart';
import '../connector_operation_controller.dart';
import 'connector_operation_card.dart';

/// A card for each of [controller]'s operations in [tier], with its actions
/// bound to the controller. Connection-wide operations are never actionable.
List<Widget> connectorOperationCards(
  ConnectorOperationController controller, {
  required ActivityTier tier,
  bool connectionWide = false,
}) {
  final attachment = controller.attachment;
  return [
    for (final operation in controller.operations)
      if (connectorTier(
            operation,
            controller,
            connectionWide: connectionWide,
          ) ==
          tier)
        ConnectorOperationCard(
          key: ValueKey(operation.key),
          operation: operation,
          readOnly: !controller.authorityFor(operation),
          pending: controller.pendingFor(operation.key),
          awaitingFinalStatus: controller.awaitingFinalStatus(operation.key),
          error: controller.errorFor(operation.key),
          onDetails: controller.detailsOpened,
          canOpen: (name) => controller.canOpen(operation.key, name),
          canSkip: (name) => controller.canSkip(operation.key, name),
          onOpen: attachment == null
              ? null
              : (name) => unawaited(
                  controller.openTarget(
                    operation,
                    name,
                    attachment: attachment,
                  ),
                ),
          onSkip: attachment == null
              ? null
              : (name) => unawaited(
                  controller.skip(operation, name, attachment: attachment),
                ),
          onContinue:
              attachment == null || !controller.canRespond(operation.key)
              ? null
              : () => unawaited(
                  controller.continueOperation(
                    operation,
                    attachment: attachment,
                  ),
                ),
        ),
  ];
}
