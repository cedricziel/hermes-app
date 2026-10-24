import 'package:flutter/material.dart';

/// The wide Waiting for you layout: the list in a column, the selected
/// proposal's detail beside it.
class MemoryProposalsSplit extends StatelessWidget {
  const MemoryProposalsSplit({
    super.key,
    required this.list,
    required this.detail,
    required this.detailKey,
  });

  static const listWidth = 380.0;

  final Widget list, detail;

  /// Tells one proposal's detail from the next, so scrolling starts over.
  final Object detailKey;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(width: listWidth, child: list),
      const VerticalDivider(width: 1),
      Expanded(
        child: SingleChildScrollView(
          key: ValueKey(detailKey),
          padding: const EdgeInsets.all(24),
          child: detail,
        ),
      ),
    ],
  );
}
