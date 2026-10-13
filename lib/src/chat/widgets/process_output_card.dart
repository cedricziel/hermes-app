import 'package:flutter/material.dart';

import '../../widgets/disclosure_tile.dart';
import '../process_output_state.dart';

class ProcessOutputCard extends StatelessWidget {
  const ProcessOutputCard({
    super.key,
    required this.output,
    this.omittedCards = false,
    this.initiallyOpen = false,
    this.onDetails,
  });
  final ProcessOutput? output;
  final bool omittedCards, initiallyOpen;
  final VoidCallback? onDetails;
  @override
  Widget build(BuildContext context) {
    final process = output;
    if (process == null) return const Text('Process output unavailable');
    return DisclosureTile(
      initiallyExpanded: initiallyOpen,
      dense: true,
      title: Text(
        'Process ${process.processId} · ${process.closed ? 'Closed' : 'Output received'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onExpansionChanged: (expanded) {
        if (expanded) onDetails?.call();
      },
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (process.text.isEmpty)
                const Text('No output received.')
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: SelectableText(process.text),
                  ),
                ),
              if (process.omitted) const Text('Earlier output omitted.'),
              if (omittedCards) const Text('Earlier process cards omitted.'),
            ],
          ),
        ),
      ],
    );
  }
}
