import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/billing_verification_controller.dart';
import 'package:hermes_app/src/chat/widgets/billing_verification_card.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode billingVerificationNode() => WidgetbookComponent(
  name: 'Billing verification',
  useCases: [
    ...onEachPlatform('Optional action', (_) => const _Example()),
    ...onEachPlatform('Compact details', (_) => const _Example(details: true)),
    ...onEachPlatform(
      'Expanded details',
      (_) => const _Example(details: true, expanded: true),
    ),
    ...onEachPlatform(
      'Unsafe destination',
      (_) => const _Example(details: true, expanded: true, unsafe: true),
    ),
    ...onEachPlatform(
      'Unavailable',
      (_) => const _Example(
        expanded: true,
        status: BillingVerificationStatus.unavailable,
      ),
    ),
    ...onEachPlatform(
      'App Lock',
      (_) => const _Example(details: true, expanded: true, locked: true),
    ),
  ],
);

class _Example extends StatefulWidget {
  const _Example({
    this.details = false,
    this.expanded = false,
    this.unsafe = false,
    this.locked = false,
    this.status = BillingVerificationStatus.idle,
  });
  final bool details, expanded, unsafe, locked;
  final BillingVerificationStatus status;
  @override
  State<_Example> createState() => _ExampleState();
}

class _ExampleState extends State<_Example> {
  late final BillingVerificationController controller;
  @override
  void initState() {
    super.initState();
    controller = BillingVerificationController(
      openBrowser: (_) async => true,
      copyCode: (_) async {},
    );
    final attachment = Object();
    controller.bind(
      BillingVerificationScope(
        connection: Object(),
        attachment: attachment,
        sessionId: 'sample',
        profile: 'sample',
      ),
      request: widget.status == BillingVerificationStatus.unavailable
          ? null
          : (_) async => {'ok': false, 'granted': false},
    );
    if (widget.details) {
      controller.acceptVerification({
        'user_code': 'EXAMPLE-CODE',
        'verification_url': widget.unsafe
            ? 'http://billing.invalid/verify'
            : 'https://billing.invalid/verify',
      }, attachment: attachment);
    }
    controller.status = widget.status;
    controller.setLocked(widget.locked);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => frame(
    BillingVerificationCard(
      controller: controller,
      initiallyOpen: widget.expanded,
    ),
  );
}
