import 'package:flutter/material.dart';

import '../../widgets/disclosure_tile.dart';
import '../billing_verification_controller.dart';

class BillingVerificationCard extends StatelessWidget {
  const BillingVerificationCard({
    super.key,
    required this.controller,
    this.initiallyOpen = false,
  });

  final BillingVerificationController controller;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.supported) return const SizedBox.shrink();
      final details = controller.verification;
      final generation = controller.generation;
      final summary = switch (controller.status) {
        BillingVerificationStatus.idle => 'Billing access',
        BillingVerificationStatus.pending => 'Awaiting billing verification',
        BillingVerificationStatus.granted => 'Billing access granted',
        BillingVerificationStatus.refused => 'Billing access refused',
        BillingVerificationStatus.unavailable =>
          'Billing verification unavailable',
        BillingVerificationStatus.failed => 'Billing verification failed',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DisclosureTile(
            dense: true,
            initiallyExpanded: initiallyOpen,
            title: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
            onExpansionChanged: (open) {
              if (open) controller.detailsOpened();
            },
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: BillingVerificationBody(
                  details: details,
                  locked: controller.locked,
                  message: controller.message,
                  retryPending:
                      controller.retryAt != null && !controller.canStart,
                  onCopy: controller.canCopyCode && details != null
                      ? () => controller.copyVerificationCode(
                          expectedDetails: details,
                          expectedGeneration: generation,
                        )
                      : null,
                  onOpen: controller.canOpenVerification && details != null
                      ? () => controller.openVerification(
                          expectedDetails: details,
                          expectedGeneration: generation,
                        )
                      : null,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: controller.canStart
                    ? () => controller.start(expectedGeneration: generation)
                    : null,
                child: const Text('Verify billing access'),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// The details inside [BillingVerificationCard]: what verification grants,
/// the code and destination, Copy code and Open verification. A plain-model
/// widget; the card binds it to its controller.
class BillingVerificationBody extends StatelessWidget {
  const BillingVerificationBody({
    super.key,
    required this.details,
    this.locked = false,
    this.message,
    this.retryPending = false,
    this.onCopy,
    this.onOpen,
  });

  final BillingVerificationDetails? details;
  final bool locked;
  final String? message;

  /// Whether to say that retrying waits for the server's delay.
  final bool retryPending;

  /// Null disables Copy code.
  final VoidCallback? onCopy;

  /// Null disables Open verification.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final details = this.details;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Verification grants billing access. It does not make a charge.',
        ),
        if (locked)
          const Text('Unlock the app to receive fresh verification details.')
        else if (details == null)
          const Text('No verification details received.')
        else ...[
          SelectableText(details.userCode),
          if (details.browserUri case final uri?) ...[
            Text('Browser destination: ${uri.host}'),
            SelectableText(details.verificationUrl),
          ] else
            const Text('Browser opening unavailable.'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(onPressed: onCopy, child: const Text('Copy code')),
              TextButton(
                onPressed: onOpen,
                child: const Text('Open verification'),
              ),
            ],
          ),
        ],
        if (message case final text?) Text(text),
        if (retryPending)
          const Text('Retry is available after the server delay.'),
      ],
    );
  }
}
