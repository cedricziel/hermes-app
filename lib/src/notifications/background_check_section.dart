import 'package:flutter/material.dart';

import '../background/background_check_status.dart';
import '../widgets/grouped_list.dart';

class BackgroundCheckSection extends StatelessWidget {
  const BackgroundCheckSection({
    super.key,
    required this.platform,
    this.permission,
    this.capability,
    this.status,
  });
  final TargetPlatform platform;
  final bool? permission;
  final String? capability;
  final BackgroundCheckStatus? status;
  String _time(DateTime time) => time.toLocal().toString().split('.').first;
  @override
  Widget build(BuildContext context) {
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final capabilityLabel = switch (capability) {
      'available' => 'Available',
      'denied' => 'Denied',
      'restricted' => 'Restricted',
      'registered' => 'Registered',
      'notRegistered' => 'Not registered',
      _ => 'Unknown',
    };
    final outcome = switch (status?.outcome) {
      BackgroundCheckOutcome.completed => 'Completed',
      BackgroundCheckOutcome.partial => 'Partial',
      BackgroundCheckOutcome.locked => 'Secure storage locked',
      BackgroundCheckOutcome.unreachable => 'Unreachable',
      BackgroundCheckOutcome.signedOut => 'Signed out',
      _ => 'Interrupted or incomplete',
    };
    return GroupedSection(
      footer: 'Background checks can run late or never. A completed check does not prove an alert reached you. Opening the app refreshes current agent state.',
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications: ${permission == null
                    ? 'Unknown'
                    : permission!
                    ? 'Allowed'
                    : 'Denied'}',
              ),
              Text(
                '${platform == TargetPlatform.iOS ? 'Background App Refresh' : 'Periodic work'}: $capabilityLabel',
              ),
              if (status case final check?) ...[
                Text('Latest check: $outcome'),
                Text('Last attempted: ${_time(check.attemptedAt)}'),
                Text(
                  'Last completed: ${check.completedAt == null ? 'None recorded' : _time(check.completedAt!)}',
                ),
              ] else
                const Text('No background check recorded.'),
            ],
          ),
        ),
      ],
    );
  }
}
