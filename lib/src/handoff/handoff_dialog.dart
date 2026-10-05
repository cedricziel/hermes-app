import 'package:flutter/material.dart';

import '../widgets/adaptive_dialog.dart';

class HandoffDialog extends StatelessWidget {
  const HandoffDialog({
    super.key,
    this.serverUrl,
    this.error,
    required this.onCancel,
    this.onContinue,
  });
  final String? serverUrl;
  final String? error;
  final VoidCallback onCancel;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => AppAlertDialog(
    title: Text(
      error == null ? 'Continue in Hermes' : 'Could not continue this chat',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (serverUrl case final url?) ...[
          const Text(
            'Connect to this dashboard? Changing dashboards clears the current session and local queued messages.',
          ),
          const SizedBox(height: 8),
          Text(url),
        ],
        if (error case final message?) Text(message),
      ],
    ),
    actions: [
      AppDialogAction(
        onPressed: onCancel,
        child: Text(error == null ? 'Cancel' : 'Dismiss'),
      ),
      if (onContinue != null)
        AppDialogAction(
          onPressed: onContinue,
          isDefault: true,
          child: Text(error == null ? 'Connect' : 'Retry'),
        ),
    ],
  );
}
