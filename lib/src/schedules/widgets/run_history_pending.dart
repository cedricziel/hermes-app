import 'package:flutter/material.dart';

/// The run history while its runs load, or with a retry when they failed to.
class RunHistoryPending extends StatelessWidget {
  const RunHistoryPending({
    super.key,
    required this.failed,
    required this.onRetry,
  });

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => failed
      ? Row(
          children: [
            const Expanded(child: Text('Could not load the runs')),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        )
      : const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator.adaptive()),
        );
}
