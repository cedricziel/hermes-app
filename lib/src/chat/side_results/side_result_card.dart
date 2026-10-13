import 'package:flutter/material.dart';

import '../../widgets/disclosure_tile.dart';
import 'side_result_state.dart';

class SideResultCard extends StatelessWidget {
  const SideResultCard({
    super.key,
    required this.result,
    this.initiallyOpen = false,
    this.onDetails,
  });
  final SideResult? result;
  final bool initiallyOpen;
  final VoidCallback? onDetails;
  @override
  Widget build(BuildContext context) {
    final value = result;
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Side result unavailable'),
      );
    }
    return DisclosureTile(
      dense: true,
      initiallyExpanded: initiallyOpen,
      onExpansionChanged: (open) {
        if (open) onDetails?.call();
      },
      title: Text(
        value.kind == SideResultKind.background
            ? 'Background result'
            : 'Side question answer',
      ),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (value.question != null)
                    Text('Question: ${value.question}'),
                  SelectableText(
                    value.text.isEmpty ? 'No result text reported' : value.text,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
