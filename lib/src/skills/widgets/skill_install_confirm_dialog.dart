import 'package:flutter/material.dart';

import '../../widgets/adaptive_dialog.dart';
import '../hub_scan.dart';
import 'skill_security_scan.dart';

/// The confirmation before a hub skill whose scan policy is `ask` installs:
/// the scan's reason and every finding. Pops `true` for "Install anyway" and
/// `false` for Cancel from its own route.
class SkillInstallConfirmDialog extends StatelessWidget {
  const SkillInstallConfirmDialog({
    super.key,
    required this.skillName,
    required this.scan,
  });

  final String skillName;
  final HubScan scan;

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: Text('Install $skillName?'),
      // Findings are data: start-aligned on every platform, not centred as
      // an Apple alert would centre its message.
      content: DefaultTextStyle.merge(
        textAlign: TextAlign.start,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                scan.policyReason.isNotEmpty
                    ? scan.policyReason
                    : 'The security scan asks for your confirmation.',
              ),
              const SizedBox(height: 12),
              for (final f in scan.findings) SkillScanFinding(f),
            ],
          ),
        ),
      ),
      actions: [
        AppDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        AppDialogAction(
          isDefault: true,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Install anyway'),
        ),
      ],
    );
  }
}
